from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List, Optional
from datetime import datetime
from jose import JWTError, jwt

from app.core.config import settings
from app.core.database import get_db
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
        query = query.where(Chapter.exam_category == exam_category)
    if only_with_questions:
        query = query.join(Question).group_by(Chapter.id)
    result = await db.execute(query)
    chapters = result.scalars().all()
    return chapters


@router.get("/practice", response_model=List[QuestionResponse])
async def get_practice_questions(
    chapter_id: Optional[int] = None,
    exam_category: Optional[str] = None,
    difficulty: Optional[int] = None,
    mode: str = "chapter",
    tag: Optional[str] = None,
    limit: int = 20,
    current_user: Optional[User] = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db)
):
    query = select(Question)
    if chapter_id:
        query = query.where(Question.chapter_id == chapter_id)
    elif exam_category:
        query = query.join(Chapter).where(Chapter.exam_category == exam_category)
    if difficulty:
        query = query.where(Question.difficulty == difficulty)
    if tag:
        query = query.where(Question.知识点.like(f"%{tag}%"))
    if mode == "unanswered":
        if not current_user:
            query = query.where(Question.id == -1)
        else:
            answered = select(QuestionRecord.question_id).where(
                QuestionRecord.user_id == current_user.id
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
    if mode in {"random", "tag"}:
        query = query.order_by(func.random())
    query = query.limit(limit)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/exam", response_model=List[QuestionResponse])
async def get_exam_questions(
    question_count: int = 50,
    exam_category: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    query = select(Question).where(Question.is_real_exam == True)
    if exam_category:
        query = query.join(Chapter).where(Chapter.exam_category == exam_category)
    result = await db.execute(query.order_by(func.random()).limit(question_count))
    return result.scalars().all()


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

    per_question_time = submit.time_spent // len(question_ids) if question_ids else 0
    time_remainder = submit.time_spent % len(question_ids) if question_ids else 0
    results = []
    correct_count = 0
    answered_count = 0

    for index, answer in enumerate(submit.answers):
        question = questions[answer.question_id]
        selected = answer.selected_answer
        is_correct = selected is not None and selected.upper() == question.answer.upper()
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
                知识点=question.知识点 or [],
            )
        )

    await db.commit()

    total = len(results)
    wrong_count = total - correct_count
    accuracy_rate = correct_count / total if total else 0
    first_chapter = chapters.get(question_ids[0])
    exam_category = first_chapter.exam_category if first_chapter else current_user.target_exam
    report = ExamSubmitResponse(
        total_questions=total,
        answered_count=answered_count,
        unanswered_count=total - answered_count,
        correct_count=correct_count,
        wrong_count=wrong_count,
        score=round(accuracy_rate * 100, 1),
        accuracy_rate=accuracy_rate,
        time_spent=submit.time_spent,
        wrong_questions=[item for item in results if not item.is_correct],
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
    report.exam_category = attempt.exam_category
    report.created_at = attempt.created_at
    return report


@router.get("/exam/attempts", response_model=List[ExamAttemptSummary])
async def list_exam_attempts(
    skip: int = 0,
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ExamAttempt)
        .where(ExamAttempt.user_id == current_user.id)
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
) -> None:
    db.add(
        QuestionRecord(
            user_id=user_id,
            question_id=question_id,
            selected_answer=selected_answer,
            is_correct=is_correct,
            is_wrong=not is_correct,
            time_spent=time_spent,
        )
    )

    if not is_correct:
        wrong_result = await db.execute(
            select(WrongQuestion).where(
                WrongQuestion.user_id == user_id,
                WrongQuestion.question_id == question_id,
            )
        )
        wrong_q = wrong_result.scalar_one_or_none()
        if wrong_q:
            wrong_q.is_mastered = False
            wrong_q.next_review_at = datetime.now()
        else:
            db.add(
                WrongQuestion(
                    user_id=user_id,
                    question_id=question_id,
                    next_review_at=datetime.now(),
                )
            )

    today = datetime.now().strftime("%Y-%m-%d")
    task_result = await db.execute(
        select(DailyTask).where(DailyTask.user_id == user_id, DailyTask.date == today)
    )
    task = task_result.scalar_one_or_none()
    if task:
        task.completed_questions += 1
        if task.completed_questions >= task.target_questions:
            task.is_completed = True

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
