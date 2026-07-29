from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List, Optional
from datetime import datetime, timedelta
from jose import JWTError, jwt
import random

from app.core.config import settings
from app.core.database import get_db
from app.core.exam_categories import normalize_exam_category, try_normalize_exam_category
from app.models.user import User
from app.models.question import Question, QuestionRecord, Chapter, ExamAttempt
from app.models.study import DailyTask, StudyStats, WrongQuestion
from app.schemas.question import (
    QuestionResponse, QuestionSubmit, QuestionSubmitResponse,
    ChapterResponse, ExamSubmit, ExamSubmitResponse, ExamQuestionResult,
    ExamAttemptSummary,
)
from app.api.deps import get_current_user

router = APIRouter(prefix="/api/questions", tags=["题库"])


def _question_response(question: Question, exam_category: Optional[str] = None) -> dict:
    return {
        "id": question.id,
        "chapter_id": question.chapter_id,
        "exam_category": exam_category,
        "question_type": question.question_type,
        "content": question.content,
        "options": question.options or {},
        "answer": question.answer,
        "explanation": question.explanation,
        "difficulty": question.difficulty,
        "is_real_exam": question.is_real_exam,
        "exam_year": question.exam_year,
        "tags": question.知识点 or [],
        "created_at": question.created_at,
    }


def _split_answer(value: Optional[str]) -> List[str]:
    if value is None:
        return []
    return [item.strip().upper() for item in value.split(",") if item.strip()]


def _is_valid_selected_answer(question: Question, selected: Optional[str]) -> bool:
    if selected is None:
        return True
    valid_options = {key.strip().upper() for key in (question.options or {}).keys()}
    selected_options = _split_answer(selected)
    if not selected_options:
        return True
    if question.question_type == "single" and len(selected_options) != 1:
        return False
    return bool(valid_options) and all(item in valid_options for item in selected_options)


def _is_answer_correct(question: Question, selected: Optional[str]) -> bool:
    if selected is None:
        return False
    expected = set(_split_answer(question.answer))
    actual = set(_split_answer(selected))
    if question.question_type == "multi":
        return actual == expected
    return selected.upper() == question.answer.upper()


async def _with_exam_categories(
    db: AsyncSession,
    questions: List[Question],
) -> List[dict]:
    if not questions:
        return []
    chapter_ids = {question.chapter_id for question in questions}
    result = await db.execute(select(Chapter).where(Chapter.id.in_(chapter_ids)))
    category_by_chapter = {
        chapter.id: chapter.exam_category for chapter in result.scalars().all()
    }
    return [
        _question_response(
            question,
            exam_category=category_by_chapter.get(question.chapter_id),
        )
        for question in questions
    ]


async def get_optional_user(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
) -> Optional[User]:
    if not authorization:
        return None
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        return None
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: int = payload.get("user_id")
        if user_id is None:
            return None
    except JWTError:
        return None
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    return user if user and user.is_active else None


@router.get("/chapters", response_model=List[ChapterResponse])
async def get_chapters(
    exam_category: Optional[str] = None,
    only_with_questions: bool = False,
    db: AsyncSession = Depends(get_db),
):
    query = select(Chapter).order_by(Chapter.order)
    if exam_category:
        category = try_normalize_exam_category(exam_category)
        if category is None:
            return []
        query = query.where(Chapter.exam_category == category)
    if only_with_questions:
        query = query.join(Question).group_by(Chapter.id)
    result = await db.execute(query)
    chapters = result.scalars().all()
    return chapters


@router.get("/practice", response_model=List[QuestionResponse])
async def get_practice_questions(
    chapter_id: Optional[int] = None,
    question_ids: Optional[str] = None,
    exam_category: Optional[str] = None,
    difficulty: Optional[int] = None,
    mode: str = "chapter",
    tag: Optional[str] = None,
    limit: int = Query(default=20, ge=1, le=100),
    current_user: Optional[User] = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db)
):
    allowed_modes = {"chapter", "unanswered", "wrong", "tag", "random"}
    if mode not in allowed_modes:
        raise HTTPException(status_code=400, detail="练习模式不正确")

    query = select(Question)
    category = None
    if exam_category:
        category = try_normalize_exam_category(exam_category)
        if category is None:
            return []
    if question_ids:
        try:
            ids = [
                int(item.strip())
                for item in question_ids.split(",")
                if item.strip()
            ]
        except ValueError:
            raise HTTPException(status_code=400, detail="题目 ID 参数不正确")
        if not ids:
            return []
        query = query.where(Question.id.in_(ids))
    if chapter_id:
        if category:
            query = query.join(Chapter).where(
                Question.chapter_id == chapter_id,
                Chapter.exam_category == category,
            )
        else:
            query = query.where(Question.chapter_id == chapter_id)
    elif category:
        query = query.join(Chapter).where(
            Chapter.exam_category == category
        )
    if difficulty:
        query = query.where(Question.difficulty == difficulty)
    if tag:
        query = query.where(Question.知识点.like(f"%{tag}%"))
    if mode == "unanswered":
        if not current_user:
            query = query.where(Question.id == -1)
        else:
            answered = select(QuestionRecord.question_id).where(
                QuestionRecord.user_id == current_user.id,
                QuestionRecord.selected_answer.is_not(None),
            )
            query = query.where(Question.id.not_in(answered))
    elif mode == "wrong":
        if not current_user:
            query = query.where(Question.id == -1)
        else:
            wrong = select(WrongQuestion.question_id).where(
                WrongQuestion.user_id == current_user.id,
                WrongQuestion.is_mastered == False,
            )
            query = query.where(Question.id.in_(wrong))
    if mode == "tag" and not tag:
        candidates = (await db.execute(query)).scalars().all()
        tag_counts = {}
        for question in candidates:
            for item in question.知识点 or []:
                if item:
                    tag_counts[item] = tag_counts.get(item, 0) + 1
        if tag_counts:
            hot_tags = {
                item[0]
                for item in sorted(
                    tag_counts.items(), key=lambda item: item[1], reverse=True
                )[:3]
            }
            candidates = [
                question
                for question in candidates
                if any(item in hot_tags for item in question.知识点 or [])
            ]
        random.shuffle(candidates)
        return await _with_exam_categories(db, candidates[:limit])
    if mode in {"random", "tag"}:
        query = query.order_by(func.random())
    query = query.limit(limit)
    result = await db.execute(query)
    return await _with_exam_categories(db, result.scalars().all())


@router.get("/exam", response_model=List[QuestionResponse])
async def get_exam_questions(
    question_count: int = Query(default=50, ge=1, le=200),
    count: Optional[int] = Query(default=None, ge=1, le=200),
    exam_category: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    requested_count = count if count is not None else question_count
    category = try_normalize_exam_category(exam_category) if exam_category else None
    if exam_category and category is None:
        return []
    query = select(Question).where(Question.is_real_exam == True)
    if exam_category:
        query = query.join(Chapter).where(
            Chapter.exam_category == category
        )
    result = await db.execute(query.order_by(func.random()).limit(requested_count))
    questions = result.scalars().all()
    if questions:
        return await _with_exam_categories(db, questions)

    fallback_query = select(Question)
    if category:
        fallback_query = fallback_query.join(Chapter).where(
            Chapter.exam_category == category
        )
    fallback_result = await db.execute(
        fallback_query.order_by(func.random()).limit(requested_count)
    )
    return await _with_exam_categories(db, fallback_result.scalars().all())


@router.get("/exam/count")
async def get_exam_question_count(
    exam_category: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
):
    category = try_normalize_exam_category(exam_category) if exam_category else None
    if exam_category and category is None:
        return {"count": 0, "real_exam_count": 0, "fallback_count": 0}

    real_query = select(func.count(Question.id)).where(Question.is_real_exam == True)
    fallback_query = select(func.count(Question.id))
    if category:
        real_query = real_query.join(Chapter).where(Chapter.exam_category == category)
        fallback_query = fallback_query.join(Chapter).where(
            Chapter.exam_category == category
        )

    real_count = await db.scalar(real_query) or 0
    fallback_count = await db.scalar(fallback_query) or 0
    return {
        "count": real_count if real_count else fallback_count,
        "real_exam_count": real_count,
        "fallback_count": fallback_count,
    }


@router.post("/submit", response_model=QuestionSubmitResponse)
async def submit_question(
    submit: QuestionSubmit,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Question).where(Question.id == submit.question_id))
    question = result.scalar_one_or_none()
    if not question:
        raise HTTPException(status_code=404, detail="题目不存在")

    is_correct = submit.selected_answer.upper() == question.answer.upper()

    await _record_answer(
        db=db,
        user_id=current_user.id,
        question_id=submit.question_id,
        selected_answer=submit.selected_answer,
        is_correct=is_correct,
        time_spent=submit.time_spent,
    )
    await db.commit()

    return QuestionSubmitResponse(
        is_correct=is_correct,
        correct_answer=question.answer,
        explanation=question.explanation,
        wrong_reason=None if is_correct else "概念不清"
    )


@router.post("/exam/submit", response_model=ExamSubmitResponse)
async def submit_exam(
    submit: ExamSubmit,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if not submit.answers:
        raise HTTPException(status_code=400, detail="请先完成至少一道模考题")

    question_ids = [answer.question_id for answer in submit.answers]
    if len(question_ids) != len(set(question_ids)):
        raise HTTPException(status_code=400, detail="模考答案包含重复题目")

    result = await db.execute(
        select(Question, Chapter)
        .join(Chapter, Question.chapter_id == Chapter.id)
        .where(Question.id.in_(question_ids))
    )
    rows = result.all()
    questions = {question.id: question for question, _ in rows}
    chapters = {question.id: chapter for question, chapter in rows}
    if len(questions) != len(question_ids):
        raise HTTPException(status_code=404, detail="部分题目不存在")
    exam_categories = {
        chapter.exam_category for chapter in chapters.values() if chapter is not None
    }
    if len(exam_categories) > 1:
        raise HTTPException(status_code=400, detail="同一次模考不能混合不同考试分类的题目")

    per_question_time = submit.time_spent // len(question_ids) if question_ids else 0
    time_remainder = submit.time_spent % len(question_ids) if question_ids else 0
    results = []
    correct_count = 0
    answered_count = 0

    for index, answer in enumerate(submit.answers):
        question = questions[answer.question_id]
        chapter = chapters.get(question.id)
        selected = answer.selected_answer
        if not _is_valid_selected_answer(question, selected):
            raise HTTPException(status_code=400, detail="模考答案包含无效选项")
        is_correct = _is_answer_correct(question, selected)
        if selected is not None:
            answered_count += 1
        if is_correct:
            correct_count += 1

        await _record_answer(
            db=db,
            user_id=current_user.id,
            question_id=question.id,
            selected_answer=selected,
            is_correct=is_correct,
            time_spent=per_question_time + (1 if index < time_remainder else 0),
            add_to_wrong_book=selected is not None,
            count_for_progress=selected is not None,
        )
        results.append(
            ExamQuestionResult(
                question_id=question.id,
                selected_answer=selected,
                correct_answer=question.answer,
                is_correct=is_correct,
                explanation=question.explanation,
                content=question.content,
                options=question.options or {},
                chapter_name=chapter.name if chapter else None,
                tags=question.知识点 or [],
            )
        )

    await db.commit()

    total = len(results)
    wrong_items = [
        item
        for item in results
        if item.selected_answer is not None and not item.is_correct
    ]
    wrong_count = len(wrong_items)
    accuracy_rate = correct_count / total if total else 0
    first_chapter = chapters.get(question_ids[0])
    exam_category = first_chapter.exam_category if first_chapter else normalize_exam_category(current_user.target_exam)
    report = ExamSubmitResponse(
        total_questions=total,
        answered_count=answered_count,
        unanswered_count=total - answered_count,
        correct_count=correct_count,
        wrong_count=wrong_count,
        score=round(accuracy_rate * 100, 1),
        accuracy_rate=accuracy_rate,
        time_spent=submit.time_spent,
        wrong_questions=wrong_items,
        results=results,
    )
    attempt = ExamAttempt(
        user_id=current_user.id,
        exam_category=exam_category,
        total_questions=report.total_questions,
        answered_count=report.answered_count,
        unanswered_count=report.unanswered_count,
        correct_count=report.correct_count,
        wrong_count=report.wrong_count,
        score=report.score,
        accuracy_rate=report.accuracy_rate,
        time_spent=report.time_spent,
        report=report.model_dump(mode="json"),
    )
    db.add(attempt)
    await db.commit()
    await db.refresh(attempt)
    report.id = attempt.id
    report.attempt_id = attempt.id
    report.exam_category = attempt.exam_category
    report.created_at = attempt.created_at
    return report


@router.get("/exam/attempts", response_model=List[ExamAttemptSummary])
async def list_exam_attempts(
    skip: int = 0,
    limit: int = 20,
    exam_category: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    filters = [ExamAttempt.user_id == current_user.id]
    if exam_category:
        category = try_normalize_exam_category(exam_category)
        if category is None:
            return []
        filters.append(ExamAttempt.exam_category == category)
    result = await db.execute(
        select(ExamAttempt)
        .where(*filters)
        .order_by(ExamAttempt.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    return result.scalars().all()


@router.get("/exam/attempts/{attempt_id}", response_model=ExamSubmitResponse)
async def get_exam_attempt(
    attempt_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ExamAttempt).where(
            ExamAttempt.id == attempt_id,
            ExamAttempt.user_id == current_user.id,
        )
    )
    attempt = result.scalar_one_or_none()
    if not attempt:
        raise HTTPException(status_code=404, detail="模考记录不存在")
    report = ExamSubmitResponse(**(attempt.report or {}))
    report.id = attempt.id
    report.attempt_id = attempt.id
    report.exam_category = attempt.exam_category
    report.created_at = attempt.created_at
    return report


async def _record_answer(
    db: AsyncSession,
    user_id: int,
    question_id: int,
    selected_answer: Optional[str],
    is_correct: bool,
    time_spent: int,
    add_to_wrong_book: bool = True,
    count_for_progress: bool = True,
) -> None:
    db.add(
        QuestionRecord(
            user_id=user_id,
            question_id=question_id,
            selected_answer=selected_answer,
            is_correct=is_correct,
            is_wrong=not is_correct and add_to_wrong_book,
            time_spent=time_spent,
        )
    )

    if not is_correct and add_to_wrong_book:
        wrong_result = await db.execute(
            select(WrongQuestion).where(
                WrongQuestion.user_id == user_id,
                WrongQuestion.question_id == question_id,
            )
        )
        wrong_q = wrong_result.scalar_one_or_none()
        if wrong_q:
            _apply_wrong_review_result(wrong_q, is_correct=False)
        else:
            db.add(
                WrongQuestion(
                    user_id=user_id,
                    question_id=question_id,
                    next_review_at=datetime.now(),
                )
            )
    elif is_correct and add_to_wrong_book:
        wrong_result = await db.execute(
            select(WrongQuestion).where(
                WrongQuestion.user_id == user_id,
                WrongQuestion.question_id == question_id,
                WrongQuestion.is_mastered == False,
            )
        )
        wrong_q = wrong_result.scalar_one_or_none()
        if wrong_q:
            _apply_wrong_review_result(wrong_q, is_correct=True)

    if not count_for_progress:
        return

    today = datetime.now().strftime("%Y-%m-%d")
    category = await db.scalar(
        select(Chapter.exam_category)
        .join(Question, Question.chapter_id == Chapter.id)
        .where(Question.id == question_id)
    )
    category = category or normalize_exam_category("执业资格")
    task_result = await db.execute(
        select(DailyTask).where(
            DailyTask.user_id == user_id,
            DailyTask.date == today,
            DailyTask.exam_category == category,
        )
    )
    task = task_result.scalar_one_or_none()
    if task:
        task.completed_questions += 1
        if task.completed_questions >= task.target_questions:
            task.is_completed = True
    else:
        task = DailyTask(
            user_id=user_id,
            exam_category=category,
            date=today,
            target_questions=20,
            completed_questions=1,
            target_chapters=[],
            is_completed=False,
        )
        db.add(task)

    stats_result = await db.execute(
        select(StudyStats).where(StudyStats.user_id == user_id, StudyStats.date == today)
    )
    stats = stats_result.scalar_one_or_none()
    if stats:
        stats.total_questions += 1
        if is_correct:
            stats.correct_count += 1
        else:
            stats.wrong_count += 1
        stats.time_spent += time_spent
        stats.accuracy_rate = stats.correct_count / stats.total_questions
    else:
        db.add(
            StudyStats(
                user_id=user_id,
                date=today,
                total_questions=1,
                correct_count=1 if is_correct else 0,
                wrong_count=0 if is_correct else 1,
                accuracy_rate=1.0 if is_correct else 0.0,
                time_spent=time_spent,
            )
        )


def _apply_wrong_review_result(wrong_q: WrongQuestion, is_correct: bool) -> None:
    now = datetime.now()
    wrong_q.review_count += 1
    wrong_q.last_reviewed_at = now
    if is_correct:
        intervals = [1, 3, 7, 14, 30]
        idx = min(wrong_q.review_count - 1, len(intervals) - 1)
        wrong_q.next_review_at = now + timedelta(days=intervals[idx])
        if wrong_q.review_count >= 3:
            wrong_q.is_mastered = True
    else:
        wrong_q.is_mastered = False
        wrong_q.next_review_at = now + timedelta(days=1)
