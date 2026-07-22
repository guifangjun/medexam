from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List, Optional
from datetime import datetime

from app.core.database import get_db
from app.models.user import User
from app.models.question import Question, QuestionRecord, Chapter
from app.models.study import DailyTask, StudyStats, WrongQuestion
from app.schemas.question import (
    QuestionResponse, QuestionSubmit, QuestionSubmitResponse,
    ChapterResponse, ExamSession
)
from app.api.deps import get_current_user

router = APIRouter(prefix="/api/questions", tags=["题库"])


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
    limit: int = 20,
    db: AsyncSession = Depends(get_db)
):
    query = select(Question)
    if chapter_id:
        query = query.where(Question.chapter_id == chapter_id)
    elif exam_category:
        query = query.join(Chapter).where(Chapter.exam_category == exam_category)
    if difficulty:
        query = query.where(Question.difficulty == difficulty)
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

    # 记录做题
    record = QuestionRecord(
        user_id=current_user.id,
        question_id=submit.question_id,
        selected_answer=submit.selected_answer,
        is_correct=is_correct,
        is_wrong=not is_correct,
        time_spent=submit.time_spent
    )
    db.add(record)

    # 如果答错，加入错题本。同一道题只保留一条，避免重复答错污染统计。
    if not is_correct:
        wrong_result = await db.execute(
            select(WrongQuestion).where(
                WrongQuestion.user_id == current_user.id,
                WrongQuestion.question_id == submit.question_id,
            )
        )
        wrong_q = wrong_result.scalar_one_or_none()
        if wrong_q:
            wrong_q.is_mastered = False
            wrong_q.next_review_at = datetime.now()
        else:
            db.add(
                WrongQuestion(
                    user_id=current_user.id,
                    question_id=submit.question_id,
                    next_review_at=datetime.now(),
                )
            )

    # 更新每日任务
    today = datetime.now().strftime("%Y-%m-%d")
    task_result = await db.execute(
        select(DailyTask).where(
            DailyTask.user_id == current_user.id,
            DailyTask.date == today
        )
    )
    task = task_result.scalar_one_or_none()
    if task:
        task.completed_questions += 1
        if task.completed_questions >= task.target_questions:
            task.is_completed = True

    # 更新学习统计
    stats_result = await db.execute(
        select(StudyStats).where(
            StudyStats.user_id == current_user.id,
            StudyStats.date == today
        )
    )
    stats = stats_result.scalar_one_or_none()
    if stats:
        stats.total_questions += 1
        if is_correct:
            stats.correct_count += 1
        else:
            stats.wrong_count += 1
        stats.time_spent += submit.time_spent
        stats.accuracy_rate = stats.correct_count / stats.total_questions
    else:
        stats = StudyStats(
            user_id=current_user.id,
            date=today,
            total_questions=1,
            correct_count=1 if is_correct else 0,
            wrong_count=0 if is_correct else 1,
            accuracy_rate=1.0 if is_correct else 0.0,
            time_spent=submit.time_spent,
        )
        db.add(stats)

    await db.commit()

    return QuestionSubmitResponse(
        is_correct=is_correct,
        correct_answer=question.answer,
        explanation=question.explanation,
        wrong_reason=None if is_correct else "概念不清"
    )
