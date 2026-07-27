from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List, Optional
from datetime import datetime, timedelta

from app.core.database import get_db
from app.models.user import User
from app.models.study import StudyPlan, DailyTask, StudyStats, WrongQuestion
from app.models.question import Question, QuestionRecord, Chapter
from app.schemas.study import (
    StudyPlanCreate, StudyPlanResponse,
    DailyTaskResponse, WrongQuestionResponse,
    StudyStatsResponse, StatsOverview, WrongReasonUpdate,
    StudyPrescriptionResponse, WeakAreaResponse,
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
    if plan.end_date < plan.start_date:
        raise HTTPException(status_code=400, detail="结束日期不能早于开始日期")

    # 产品语义上同一用户只能有一个当前计划。
    active_result = await db.execute(
        select(StudyPlan).where(
            StudyPlan.user_id == current_user.id,
            StudyPlan.is_active == True,
        )
    )
    for active_plan in active_result.scalars().all():
        active_plan.is_active = False

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

    today = datetime.now().strftime("%Y-%m-%d")
    task_result = await db.execute(
        select(DailyTask).where(
            DailyTask.user_id == current_user.id,
            DailyTask.date == today
        )
    )
    task = task_result.scalar_one_or_none()
    if task:
        task.plan_id = db_plan.id
        task.target_questions = db_plan.daily_questions
        task.target_chapters = db_plan.target_chapters
        task.is_completed = task.completed_questions >= db_plan.daily_questions
    else:
        task = DailyTask(
            user_id=current_user.id,
            plan_id=db_plan.id,
            date=today,
            target_questions=db_plan.daily_questions,
            completed_questions=0,
            target_chapters=db_plan.target_chapters
        )
        db.add(task)
    await db.commit()

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
    plan_result = await db.execute(
        select(StudyPlan).where(
            StudyPlan.user_id == current_user.id,
            StudyPlan.is_active == True
        ).order_by(StudyPlan.created_at.desc()).limit(1)
    )
    plan = plan_result.scalar_one_or_none()

    if not task:
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
    elif plan and task.plan_id != plan.id:
        task.plan_id = plan.id
        task.target_questions = plan.daily_questions
        task.target_chapters = plan.target_chapters
        task.is_completed = task.completed_questions >= plan.daily_questions
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
        select(WrongQuestion, Question)
        .join(Question, WrongQuestion.question_id == Question.id)
        .where(WrongQuestion.user_id == current_user.id)
        .order_by(WrongQuestion.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    wrong_questions = []
    for wrong_q, question in result.all():
        wrong_questions.append(
            {
                "id": wrong_q.id,
                "question_id": wrong_q.question_id,
                "question_content": question.content,
                "question_options": question.options or {},
                "question_answer": question.answer,
                "question_explanation": question.explanation,
                "question_difficulty": question.difficulty,
                "question_tags": question.知识点 or [],
                "wrong_reason": wrong_q.wrong_reason,
                "review_count": wrong_q.review_count,
                "is_mastered": wrong_q.is_mastered,
                "next_review_at": wrong_q.next_review_at,
                "created_at": wrong_q.created_at,
            }
        )
    return wrong_questions


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
        idx = min(wrong_q.review_count - 1, len(intervals) - 1)
        wrong_q.next_review_at = datetime.now() + timedelta(days=intervals[idx])
        if wrong_q.review_count >= 3:
            wrong_q.is_mastered = True
    else:
        # 答错则重置间隔
        wrong_q.is_mastered = False
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


@router.get("/prescription", response_model=StudyPrescriptionResponse)
async def get_study_prescription(
    exam_category: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """根据今日数据、错题和章节表现生成首页学习建议"""
    today = datetime.now().strftime("%Y-%m-%d")
    category = exam_category or current_user.target_exam or "执业资格"

    task_result = await db.execute(
        select(DailyTask).where(
            DailyTask.user_id == current_user.id,
            DailyTask.date == today
        )
    )
    task = task_result.scalar_one_or_none()

    stats_result = await db.execute(
        select(StudyStats).where(
            StudyStats.user_id == current_user.id,
            StudyStats.date == today
        )
    )
    stats = stats_result.scalar_one_or_none()

    target_questions = (
        task.target_questions
        if task
        else current_user.daily_goal or 20
    )
    completed_questions = stats.total_questions if stats else (task.completed_questions if task else 0)
    accuracy_rate = stats.accuracy_rate if stats else 0.0
    time_spent = stats.time_spent if stats else 0

    chapter_result = await db.execute(
        select(Chapter)
        .where(Chapter.exam_category == category)
        .order_by(Chapter.order)
    )
    chapters = chapter_result.scalars().all()
    chapter_by_id = {chapter.id: chapter for chapter in chapters}

    record_result = await db.execute(
        select(QuestionRecord, Question)
        .join(Question, QuestionRecord.question_id == Question.id)
        .join(Chapter, Question.chapter_id == Chapter.id)
        .where(
            QuestionRecord.user_id == current_user.id,
            Chapter.exam_category == category,
        )
    )
    chapter_stats = {}
    for record, question in record_result.all():
        item = chapter_stats.setdefault(
            question.chapter_id,
            {"practice_count": 0, "correct_count": 0, "wrong_count": 0},
        )
        item["practice_count"] += 1
        if record.is_correct:
            item["correct_count"] += 1
        else:
            item["wrong_count"] += 1

    weak_areas = []
    for chapter_id, item in chapter_stats.items():
        chapter = chapter_by_id.get(chapter_id)
        if not chapter:
            continue
        practice_count = item["practice_count"]
        accuracy = item["correct_count"] / practice_count if practice_count else 0.0
        if accuracy < 0.7:
            status = "薄弱"
        elif accuracy < 0.85:
            status = "一般"
        else:
            status = "稳固"
        weak_areas.append(
            WeakAreaResponse(
                chapter_id=chapter.id,
                chapter_name=chapter.name,
                exam_category=chapter.exam_category,
                practice_count=practice_count,
                wrong_count=item["wrong_count"],
                accuracy_rate=accuracy,
                status=status,
            )
        )

    weak_areas.sort(
        key=lambda item: (
            item.accuracy_rate,
            -item.wrong_count,
            -item.practice_count,
        )
    )
    weak_areas = weak_areas[:5]

    if not weak_areas and chapters:
        question_count_result = await db.execute(
            select(Question.chapter_id, func.count(Question.id))
            .join(Chapter, Question.chapter_id == Chapter.id)
            .where(Chapter.exam_category == category)
            .group_by(Question.chapter_id)
        )
        counts = {chapter_id: count for chapter_id, count in question_count_result.all()}
        for chapter in chapters[:5]:
            if counts.get(chapter.id, 0) <= 0:
                continue
            weak_areas.append(
                WeakAreaResponse(
                    chapter_id=chapter.id,
                    chapter_name=chapter.name,
                    exam_category=chapter.exam_category,
                    practice_count=0,
                    wrong_count=0,
                    accuracy_rate=0.0,
                    status="待开始",
                )
            )

    pending_wrong_result = await db.execute(
        select(func.count(WrongQuestion.id)).where(
            WrongQuestion.user_id == current_user.id,
            WrongQuestion.is_mastered == False,
        )
    )
    pending_wrong_count = pending_wrong_result.scalar() or 0

    recommended_chapter_id = None
    recommended_tag = None
    if completed_questions == 0:
        recommendation_title = "先完成一组随机练习"
        recommendation_reason = f"今天还没有做题，先用 {category} 随机题快速进入状态。"
        recommended_mode = "random"
    elif pending_wrong_count > 0 and accuracy_rate < 0.75:
        recommendation_title = "优先复习错题"
        recommendation_reason = f"当前还有 {pending_wrong_count} 道错题待巩固，先把失分点补回来。"
        recommended_mode = "wrong"
    elif weak_areas:
        top = weak_areas[0]
        recommendation_title = f"补强「{top.chapter_name}」"
        recommendation_reason = f"该章节正确率 {round(top.accuracy_rate * 100)}%，建议做 20 题专项练习。"
        recommended_mode = "chapter"
        recommended_chapter_id = top.chapter_id
    elif completed_questions < target_questions:
        recommendation_title = "继续今日任务"
        recommendation_reason = "距离今日目标还差一点，优先完成未做题。"
        recommended_mode = "unanswered"
    else:
        recommendation_title = "今日达标，随机保持手感"
        recommendation_reason = "今天的题量已达标，可以用少量随机题保持熟练度。"
        recommended_mode = "random"

    return StudyPrescriptionResponse(
        date=today,
        target_questions=target_questions,
        completed_questions=completed_questions,
        accuracy_rate=accuracy_rate,
        time_spent=time_spent,
        recommendation_title=recommendation_title,
        recommendation_reason=recommendation_reason,
        recommended_mode=recommended_mode,
        recommended_chapter_id=recommended_chapter_id,
        recommended_tag=recommended_tag,
        weak_areas=weak_areas,
    )


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
