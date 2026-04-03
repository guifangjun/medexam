from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List
from datetime import datetime, timedelta

from app.core.database import get_db
from app.models.user import User
from app.models.study import StudyPlan, DailyTask, StudyStats, WrongQuestion
from app.models.question import Question, QuestionRecord
from app.schemas.study import (
    StudyPlanCreate, StudyPlanResponse,
    DailyTaskResponse, WrongQuestionResponse,
    StudyStatsResponse, StatsOverview, WrongReasonUpdate
)
from app.api.deps import get_current_user

router = APIRouter(prefix="/api/study", tags=["学习"])


@router.post("/plan", response_model=StudyPlanResponse)
async def create_study_plan(
    plan: StudyPlanCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """创建学习计划"""
    db_plan = StudyPlan(
        user_id=current_user.id,
        title=plan.title,
        plan_type=plan.plan_type,
        target_chapters=plan.target_chapters,
        daily_questions=plan.daily_questions,
        start_date=plan.start_date,
        end_date=plan.end_date
    )
    db.add(db_plan)
    await db.commit()
    await db.refresh(db_plan)
    return db_plan


@router.get("/plan", response_model=List[StudyPlanResponse])
async def get_study_plans(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取学习计划列表"""
    result = await db.execute(
        select(StudyPlan)
        .where(StudyPlan.user_id == current_user.id)
        .order_by(StudyPlan.created_at.desc())
    )
    return result.scalars().all()


@router.get("/plan/{plan_id}/tasks", response_model=List[DailyTaskResponse])
async def get_plan_tasks(
    plan_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取计划的所有每日任务"""
    result = await db.execute(
        select(DailyTask)
        .where(DailyTask.user_id == current_user.id, DailyTask.plan_id == plan_id)
        .order_by(DailyTask.date.desc())
    )
    return result.scalars().all()


@router.get("/today", response_model=DailyTaskResponse)
async def get_today_task(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取今日任务"""
    today = datetime.now().strftime("%Y-%m-%d")
    result = await db.execute(
        select(DailyTask).where(
            DailyTask.user_id == current_user.id,
            DailyTask.date == today
        )
    )
    task = result.scalar_one_or_none()
    if not task:
        # 创建今日任务
        plan_result = await db.execute(
            select(StudyPlan).where(
                StudyPlan.user_id == current_user.id,
                StudyPlan.is_active == True
            ).order_by(StudyPlan.created_at.desc()).limit(1)
        )
        plan = plan_result.scalar_one_or_none()

        task = DailyTask(
            user_id=current_user.id,
            plan_id=plan.id if plan else None,
            date=today,
            target_questions=plan.daily_questions if plan else current_user.daily_goal,
            completed_questions=0
        )
        db.add(task)
        await db.commit()
        await db.refresh(task)
    return task


@router.get("/wrong", response_model=List[WrongQuestionResponse])
async def get_wrong_questions(
    skip: int = 0,
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取错题本"""
    result = await db.execute(
        select(WrongQuestion)
        .where(WrongQuestion.user_id == current_user.id)
        .order_by(WrongQuestion.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    return result.scalars().all()


@router.put("/wrong/{wrong_id}/reason")
async def update_wrong_reason(
    wrong_id: int,
    reason_update: WrongReasonUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """更新错因分类"""
    result = await db.execute(
        select(WrongQuestion).where(
            WrongQuestion.id == wrong_id,
            WrongQuestion.user_id == current_user.id
        )
    )
    wrong_q = result.scalar_one_or_none()
    if not wrong_q:
        raise HTTPException(status_code=404, detail="错题不存在")

    wrong_q.wrong_reason = reason_update.wrong_reason
    await db.commit()
    return {"message": "更新成功"}


@router.post("/wrong/{wrong_id}/review")
async def review_wrong_question(
    wrong_id: int,
    is_correct: bool,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """复习错题后标记"""
    result = await db.execute(
        select(WrongQuestion).where(
            WrongQuestion.id == wrong_id,
            WrongQuestion.user_id == current_user.id
        )
    )
    wrong_q = result.scalar_one_or_none()
    if not wrong_q:
        raise HTTPException(status_code=404, detail="错题不存在")

    wrong_q.review_count += 1
    wrong_q.last_reviewed_at = datetime.now()

    if is_correct:
        # 艾宾浩斯：答对后延长复习间隔
        intervals = [1, 3, 7, 14, 30]  # 天数
        idx = min(wrong_q.review_count, len(intervals) - 1)
        wrong_q.next_review_at = datetime.now() + timedelta(days=intervals[idx])
        if wrong_q.review_count >= 3:
            wrong_q.is_mastered = True
    else:
        # 答错则重置间隔
        wrong_q.next_review_at = datetime.now() + timedelta(days=1)

    await db.commit()
    return {"message": "复习记录已保存"}


@router.get("/stats/today", response_model=StudyStatsResponse)
async def get_today_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取今日统计"""
    today = datetime.now().strftime("%Y-%m-%d")
    result = await db.execute(
        select(StudyStats).where(
            StudyStats.user_id == current_user.id,
            StudyStats.date == today
        )
    )
    stats = result.scalar_one_or_none()
    if not stats:
        return StudyStatsResponse(
            date=today, total_questions=0, correct_count=0,
            wrong_count=0, accuracy_rate=0.0, time_spent=0, ai_questions=0
        )
    return stats


@router.get("/stats/overview", response_model=StatsOverview)
async def get_stats_overview(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取学习概况"""
    # 总体统计
    stats_result = await db.execute(
        select(
            func.sum(StudyStats.total_questions).label("total"),
            func.sum(StudyStats.correct_count).label("correct"),
            func.sum(StudyStats.time_spent).label("time"),
            func.count(StudyStats.id).label("days")
        ).where(StudyStats.user_id == current_user.id)
    )
    stats = stats_result.one()

    # 计算正确率
    total = stats.total or 0
    correct = stats.correct or 0
    accuracy = correct / total if total > 0 else 0.0

    # 计算连续学习天数（简单版：最近都有记录）
    streak_result = await db.execute(
        select(StudyStats.date)
        .where(StudyStats.user_id == current_user.id)
        .order_by(StudyStats.date.desc())
        .limit(30)
    )
    dates = [r[0] for r in streak_result.all()]
    streak = 0
    for i, d in enumerate(dates):
        expected = (datetime.now() - timedelta(days=i)).strftime("%Y-%m-%d")
        if d == expected:
            streak += 1
        else:
            break

    # 各科目统计（通过关联章节）
    subject_stats = {}

    return StatsOverview(
        total_questions=total,
        total_correct=correct,
        overall_accuracy=accuracy,
        total_study_time=stats.time or 0,
        current_streak=streak,
        subject_stats=subject_stats
    )
