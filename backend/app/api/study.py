from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import case, select, func
from typing import List, Optional
from datetime import datetime, timedelta

from app.core.database import get_db
from app.core.exam_categories import normalize_exam_category, try_normalize_exam_category
from app.models.user import User
from app.models.study import StudyPlan, DailyTask, StudyStats, WrongQuestion
from app.models.question import Question, QuestionRecord, Chapter
from app.models.conversation import AIConversation
from app.schemas.study import (
    StudyPlanCreate, StudyPlanResponse,
    DailyTaskResponse, WrongQuestionResponse,
    StudyStatsResponse, StatsOverview, WrongReasonUpdate,
    StudyPrescriptionResponse, WeakAreaResponse,
    WrongReviewCalendarDay, WrongReviewCalendarResponse,
    WrongReviewFocusItem, WrongReviewPlanResponse,
)
from app.api.deps import get_current_user

router = APIRouter(prefix="/api/study", tags=["学习"])


async def _chapter_ids_for_category(db: AsyncSession, category: str) -> set[int]:
    result = await db.execute(select(Chapter.id).where(Chapter.exam_category == category))
    return {row[0] for row in result.all()}


def _plan_matches_chapter_ids(
    plan: StudyPlan,
    chapter_ids: set[int],
    category: Optional[str] = None,
    include_uncategorized: bool = False,
) -> bool:
    if category and getattr(plan, "exam_category", None):
        return plan.exam_category == category
    target_ids = set(plan.target_chapters or [])
    if not target_ids:
        return include_uncategorized
    return bool(target_ids & chapter_ids)


async def _completed_questions_for_today_category(
    db: AsyncSession,
    user_id: int,
    category: str,
    today: str,
) -> int:
    result = await db.execute(
        select(func.count(QuestionRecord.id))
        .join(Question, QuestionRecord.question_id == Question.id)
        .join(Chapter, Question.chapter_id == Chapter.id)
        .where(
            QuestionRecord.user_id == user_id,
            QuestionRecord.selected_answer.is_not(None),
            Chapter.exam_category == category,
            func.date(QuestionRecord.created_at) == today,
        )
    )
    return result.scalar() or 0


def _task_response(
    task: DailyTask,
    *,
    exam_category: Optional[str] = None,
    plan_id: Optional[int] = None,
    target_questions: Optional[int] = None,
    completed_questions: Optional[int] = None,
    target_chapters: Optional[List[int]] = None,
    is_completed: Optional[bool] = None,
) -> dict:
    return {
        "id": task.id,
        "plan_id": task.plan_id if plan_id is None else plan_id,
        "exam_category": exam_category or task.exam_category,
        "date": task.date,
        "target_questions": (
            task.target_questions if target_questions is None else target_questions
        ),
        "completed_questions": (
            task.completed_questions
            if completed_questions is None
            else completed_questions
        ),
        "target_chapters": (
            task.target_chapters if target_chapters is None else target_chapters
        ),
        "is_completed": task.is_completed if is_completed is None else is_completed,
    }


@router.post("/plan", response_model=StudyPlanResponse)
async def create_study_plan(
    plan: StudyPlanCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """创建学习计划"""
    if plan.end_date < plan.start_date:
        raise HTTPException(status_code=400, detail="结束日期不能早于开始日期")

    target_chapter_ids = set(plan.target_chapters or [])
    target_category: Optional[str] = None

    # 产品语义上同一考试分类只能有一个当前计划，避免切分类后计划互相覆盖。
    active_result = await db.execute(
        select(StudyPlan).where(
            StudyPlan.user_id == current_user.id,
            StudyPlan.is_active == True,
        )
    )
    target_category_chapter_ids: set[int] = set()
    requested_category = (
        try_normalize_exam_category(plan.exam_category)
        if plan.exam_category
        else None
    )
    if plan.exam_category and requested_category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")

    if target_chapter_ids:
        category_result = await db.execute(
            select(Chapter.exam_category)
            .where(Chapter.id.in_(target_chapter_ids))
            .group_by(Chapter.exam_category)
        )
        categories = [row[0] for row in category_result.all()]
        if len(categories) > 1:
            raise HTTPException(status_code=400, detail="学习计划不能混合不同考试分类的章节")
        if categories:
            target_category = categories[0]
            if requested_category and requested_category != target_category:
                raise HTTPException(status_code=400, detail="学习计划章节必须属于所选考试分类")
            target_category_chapter_ids = await _chapter_ids_for_category(db, target_category)
    else:
        target_category = requested_category or normalize_exam_category(current_user.target_exam)

    for active_plan in active_result.scalars().all():
        include_uncategorized = (
            target_category == normalize_exam_category(current_user.target_exam)
        )
        should_deactivate = (
            _plan_matches_chapter_ids(
                active_plan,
                target_category_chapter_ids,
                category=target_category,
                include_uncategorized=include_uncategorized,
            )
        )
        if should_deactivate:
            active_plan.is_active = False

    db_plan = StudyPlan(
        user_id=current_user.id,
        title=plan.title,
        plan_type=plan.plan_type,
        exam_category=target_category,
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
            DailyTask.date == today,
            DailyTask.exam_category == target_category,
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
            exam_category=target_category,
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
    exam_category: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取学习计划列表"""
    result = await db.execute(
        select(StudyPlan)
        .where(StudyPlan.user_id == current_user.id)
        .order_by(StudyPlan.created_at.desc())
    )
    plans = result.scalars().all()
    if not exam_category:
        return plans
    category = try_normalize_exam_category(exam_category)
    if category is None:
        return []
    chapter_ids = await _chapter_ids_for_category(db, category)
    include_uncategorized = category == normalize_exam_category(current_user.target_exam)
    return [
        plan
        for plan in plans
        if _plan_matches_chapter_ids(
            plan,
            chapter_ids,
            category=category,
            include_uncategorized=include_uncategorized,
        )
    ]


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
    exam_category: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取今日任务"""
    today = datetime.now().strftime("%Y-%m-%d")
    category = (
        try_normalize_exam_category(exam_category)
        if exam_category
        else normalize_exam_category(current_user.target_exam)
    )
    if category is None:
        return {
            "id": 0,
            "plan_id": None,
            "exam_category": exam_category or "",
            "date": today,
            "target_questions": current_user.daily_goal or 20,
            "completed_questions": 0,
            "target_chapters": [],
            "is_completed": False,
        }
    category_chapter_ids = await _chapter_ids_for_category(db, category)
    result = await db.execute(
        select(DailyTask).where(
            DailyTask.user_id == current_user.id,
            DailyTask.date == today,
            DailyTask.exam_category == category,
        )
    )
    task = result.scalar_one_or_none()
    plan_result = await db.execute(
        select(StudyPlan).where(
            StudyPlan.user_id == current_user.id,
            StudyPlan.is_active == True
        ).order_by(StudyPlan.created_at.desc())
    )
    active_plans = plan_result.scalars().all()
    include_uncategorized = category == normalize_exam_category(current_user.target_exam)
    plan = next(
        (
            item
            for item in active_plans
            if _plan_matches_chapter_ids(
                item,
                category_chapter_ids,
                category=category,
                include_uncategorized=include_uncategorized,
            )
        ),
        None,
    )
    completed_questions = await _completed_questions_for_today_category(
        db, current_user.id, category, today
    )

    if not task:
        task = DailyTask(
            user_id=current_user.id,
            plan_id=plan.id if plan else None,
            exam_category=category,
            date=today,
            target_questions=plan.daily_questions if plan else current_user.daily_goal,
            completed_questions=completed_questions,
            target_chapters=plan.target_chapters if plan else [],
        )
        db.add(task)
        await db.commit()
        await db.refresh(task)
    elif plan and task.plan_id != plan.id:
        task.plan_id = plan.id
        task.target_questions = plan.daily_questions
        task.target_chapters = plan.target_chapters
        task.completed_questions = completed_questions
        task.is_completed = completed_questions >= plan.daily_questions
        await db.commit()
        await db.refresh(task)
    elif exam_category:
        target_questions = plan.daily_questions if plan else current_user.daily_goal or 20
        return _task_response(
            task,
            exam_category=category,
            plan_id=plan.id if plan else None,
            target_questions=target_questions,
            completed_questions=completed_questions,
            target_chapters=plan.target_chapters if plan else [],
            is_completed=completed_questions >= target_questions,
        )
    return task


@router.get("/wrong", response_model=List[WrongQuestionResponse])
async def get_wrong_questions(
    skip: int = 0,
    limit: int = 20,
    exam_category: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取错题本"""
    category = (
        try_normalize_exam_category(exam_category)
        if exam_category
        else normalize_exam_category(current_user.target_exam)
    )
    if category is None:
        return []
    result = await db.execute(
        select(WrongQuestion, Question, Chapter)
        .join(Question, WrongQuestion.question_id == Question.id)
        .join(Chapter, Question.chapter_id == Chapter.id)
        .where(
            WrongQuestion.user_id == current_user.id,
            Chapter.exam_category == category,
        )
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


@router.get("/wrong/calendar", response_model=WrongReviewCalendarResponse)
async def get_wrong_review_calendar(
    days: int = 14,
    exam_category: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """错题复习日历：按 next_review_at 统计待复习安排"""
    days = max(1, min(days, 60))
    category = (
        try_normalize_exam_category(exam_category)
        if exam_category
        else normalize_exam_category(current_user.target_exam)
    )
    now = datetime.now()
    today = now.date()
    if category is None:
        return WrongReviewCalendarResponse(
            today=today.isoformat(),
            total_wrong=0,
            due_today=0,
            overdue=0,
            mastered=0,
            upcoming=[
                WrongReviewCalendarDay(
                    date=(today + timedelta(days=offset)).isoformat(),
                    due_count=0,
                    overdue_count=0,
                    mastered_count=0,
                )
                for offset in range(days)
            ],
        )
    result = await db.execute(
        select(WrongQuestion)
        .join(Question, WrongQuestion.question_id == Question.id)
        .join(Chapter, Question.chapter_id == Chapter.id)
        .where(
            WrongQuestion.user_id == current_user.id,
            Chapter.exam_category == category,
        )
    )
    wrongs = result.scalars().all()

    total_wrong = len(wrongs)
    mastered = sum(1 for item in wrongs if item.is_mastered)
    due_today = 0
    overdue = 0
    day_counts = {
        (today + timedelta(days=offset)).isoformat(): {
            "due_count": 0,
            "overdue_count": 0,
            "mastered_count": 0,
        }
        for offset in range(days)
    }

    for item in wrongs:
        if item.is_mastered:
            continue
        next_at = item.next_review_at or item.created_at or now
        review_date = next_at.date()
        if review_date < today:
            overdue += 1
            day_counts[today.isoformat()]["overdue_count"] += 1
        elif review_date == today:
            due_today += 1
            day_counts[today.isoformat()]["due_count"] += 1
        elif review_date < today + timedelta(days=days):
            day_counts[review_date.isoformat()]["due_count"] += 1

    day_counts[today.isoformat()]["mastered_count"] = mastered
    upcoming = [
        WrongReviewCalendarDay(
            date=date,
            due_count=value["due_count"],
            overdue_count=value["overdue_count"],
            mastered_count=value["mastered_count"],
        )
        for date, value in day_counts.items()
    ]

    return WrongReviewCalendarResponse(
        today=today.isoformat(),
        total_wrong=total_wrong,
        due_today=due_today,
        overdue=overdue,
        mastered=mastered,
        upcoming=upcoming,
    )


@router.get("/wrong/review-plan", response_model=WrongReviewPlanResponse)
async def get_wrong_review_plan(
    exam_category: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """智能复盘：根据到期错题、错因和知识点给出今日复习建议"""
    category = (
        try_normalize_exam_category(exam_category)
        if exam_category
        else normalize_exam_category(current_user.target_exam)
    )
    now = datetime.now()
    if category is None:
        return WrongReviewPlanResponse(
            title="暂无匹配的考试分类",
            summary="请先切换到有效考试分类，再查看错题复盘计划。",
            due_today=0,
            overdue=0,
            mastered=0,
            suggested_count=0,
            focus_tags=[],
            focus_reasons=[],
            actions=["切换考试分类", "完成一组有效分类下的练习"],
        )
    result = await db.execute(
        select(WrongQuestion, Question, Chapter)
        .join(Question, WrongQuestion.question_id == Question.id)
        .join(Chapter, Question.chapter_id == Chapter.id)
        .where(
            WrongQuestion.user_id == current_user.id,
            Chapter.exam_category == category,
        )
    )
    rows = result.all()

    active_rows = [
        (wrong, question, chapter)
        for wrong, question, chapter in rows
        if not wrong.is_mastered
    ]
    due_rows = [
        (wrong, question, chapter)
        for wrong, question, chapter in active_rows
        if (wrong.next_review_at or wrong.created_at or now) <= now
    ]
    due_today = sum(
        1
        for wrong, _, _ in active_rows
        if (wrong.next_review_at or wrong.created_at or now).date() == now.date()
    )
    overdue = sum(
        1
        for wrong, _, _ in active_rows
        if (wrong.next_review_at or wrong.created_at or now).date() < now.date()
    )
    mastered = len(rows) - len(active_rows)

    tag_counts = {}
    reason_counts = {}
    generic_tags = {
        "执业资格",
        "执业医师",
        "助理医师",
        "初级职称",
        "中级职称",
        "高级职称",
        category,
    }
    for wrong, question, chapter in due_rows or active_rows:
        focused_tags = [
            tag
            for tag in (question.知识点 or [])
            if tag and tag not in generic_tags
        ]
        if not focused_tags and chapter.name:
            focused_tags = [chapter.name]
        for tag in focused_tags:
            tag_counts[tag] = tag_counts.get(tag, 0) + 1
        reason = wrong.wrong_reason or "未标注错因"
        reason_counts[reason] = reason_counts.get(reason, 0) + 1

    def top_items(counts, advice_prefix):
        items = sorted(counts.items(), key=lambda item: item[1], reverse=True)[:3]
        return [
            WrongReviewFocusItem(
                label=label,
                count=count,
                advice=f"{advice_prefix}{label}，先看解析再二次作答。",
            )
            for label, count in items
        ]

    suggested_count = min(max(due_today + overdue, 5 if active_rows else 0), 20)
    if not rows:
        title = "暂无错题，继续保持"
        summary = "完成练习或模考后，答错的题会自动进入这里生成复习计划。"
        actions = ["先完成一组章节练习", "模考后回来查看错题复盘"]
    elif due_today + overdue == 0:
        title = "今天没有到期错题"
        summary = f"当前还有 {len(active_rows)} 道未掌握错题，建议用 5 道轻量复盘保持记忆。"
        actions = ["轻量复盘 5 道错题", "整理最近一次模考错题知识点"]
    else:
        title = "今日错题复盘"
        summary = f"今天到期 {due_today} 道，逾期未复习 {overdue} 道，建议先处理最容易遗忘的题。"
        actions = [
            f"先完成 {suggested_count} 道错题复习",
            "答错题立刻查看解析并标注错因",
            "答对 3 次的题会自动标记为已掌握",
        ]

    return WrongReviewPlanResponse(
        title=title,
        summary=summary,
        due_today=due_today,
        overdue=overdue,
        mastered=mastered,
        suggested_count=suggested_count,
        focus_tags=top_items(tag_counts, "重点复习知识点："),
        focus_reasons=top_items(reason_counts, "优先处理错因："),
        actions=actions,
    )


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
    exam_category: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取今日统计"""
    today = datetime.now().strftime("%Y-%m-%d")
    if exam_category:
        category = try_normalize_exam_category(exam_category)
        if category is None:
            return StudyStatsResponse(
                date=today, total_questions=0, correct_count=0,
                wrong_count=0, accuracy_rate=0.0, time_spent=0, ai_questions=0
            )
        result = await db.execute(
            select(
                func.count(QuestionRecord.id).label("total"),
                func.sum(case((QuestionRecord.is_correct == True, 1), else_=0)).label("correct"),
                func.sum(case((QuestionRecord.is_correct == False, 1), else_=0)).label("wrong"),
                func.sum(QuestionRecord.time_spent).label("time"),
            )
            .join(Question, QuestionRecord.question_id == Question.id)
            .join(Chapter, Question.chapter_id == Chapter.id)
            .where(
                QuestionRecord.user_id == current_user.id,
                QuestionRecord.selected_answer.is_not(None),
                Chapter.exam_category == category,
                func.date(QuestionRecord.created_at) == today,
            )
        )
        row = result.one()
        total = row.total or 0
        correct = row.correct or 0
        wrong = row.wrong or 0
        ai_questions = await db.scalar(
            select(func.count(AIConversation.id)).where(
                AIConversation.user_id == current_user.id,
                AIConversation.message_type == "user",
                AIConversation.exam_category == category,
                func.date(AIConversation.created_at) == today,
            )
        ) or 0
        return StudyStatsResponse(
            date=today,
            total_questions=total,
            correct_count=correct,
            wrong_count=wrong,
            accuracy_rate=correct / total if total else 0.0,
            time_spent=row.time or 0,
            ai_questions=ai_questions,
        )
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
    category = (
        try_normalize_exam_category(exam_category)
        if exam_category
        else normalize_exam_category(current_user.target_exam)
    )
    if category is None:
        return StudyPrescriptionResponse(
            date=today,
            target_questions=current_user.daily_goal or 20,
            completed_questions=0,
            accuracy_rate=0.0,
            time_spent=0,
            recommendation_title="暂无匹配的考试分类",
            recommendation_reason="请先切换到有效考试分类，再开始今日学习任务。",
            recommended_mode="random",
            weak_areas=[],
        )

    task_result = await db.execute(
        select(DailyTask).where(
            DailyTask.user_id == current_user.id,
            DailyTask.date == today,
            DailyTask.exam_category == category,
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
    today_record_result = await db.execute(
        select(
            func.count(QuestionRecord.id).label("total"),
            func.sum(case((QuestionRecord.is_correct == True, 1), else_=0)).label("correct"),
            func.sum(QuestionRecord.time_spent).label("time"),
        )
        .join(Question, QuestionRecord.question_id == Question.id)
        .join(Chapter, Question.chapter_id == Chapter.id)
        .where(
            QuestionRecord.user_id == current_user.id,
            QuestionRecord.selected_answer.is_not(None),
            Chapter.exam_category == category,
            func.date(QuestionRecord.created_at) == today,
        )
    )
    today_record_stats = today_record_result.one()
    category_completed_questions = today_record_stats.total or 0
    category_correct_count = today_record_stats.correct or 0
    category_time_spent = today_record_stats.time or 0

    if exam_category:
        completed_questions = category_completed_questions
        accuracy_rate = (
            category_correct_count / category_completed_questions
            if category_completed_questions
            else 0.0
        )
        time_spent = category_time_spent
    else:
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
        select(func.count(WrongQuestion.id))
        .join(Question, WrongQuestion.question_id == Question.id)
        .join(Chapter, Question.chapter_id == Chapter.id)
        .where(
            WrongQuestion.user_id == current_user.id,
            WrongQuestion.is_mastered == False,
            Chapter.exam_category == category,
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
    exam_category: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取学习概况"""
    category = try_normalize_exam_category(exam_category) if exam_category else None
    if exam_category and category is None:
        return StatsOverview(
            total_questions=0,
            total_correct=0,
            overall_accuracy=0.0,
            total_study_time=0,
            current_streak=0,
            subject_stats={},
            accuracy_trend=[],
        )

    record_filters = [
        QuestionRecord.user_id == current_user.id,
        QuestionRecord.selected_answer.is_not(None),
    ]
    if category:
        record_filters.append(Chapter.exam_category == category)

    # 总体统计：按真实做题记录 + 当前考试分类计算，避免切换分类后混入其他考试目标。
    stats_result = await db.execute(
        select(
            func.count(QuestionRecord.id).label("total"),
            func.sum(case((QuestionRecord.is_correct == True, 1), else_=0)).label("correct"),
            func.sum(QuestionRecord.time_spent).label("time"),
        )
        .join(Question, QuestionRecord.question_id == Question.id)
        .join(Chapter, Question.chapter_id == Chapter.id)
        .where(*record_filters)
    )
    stats = stats_result.one()

    # 计算正确率
    total = stats.total or 0
    correct = stats.correct or 0
    accuracy = correct / total if total > 0 else 0.0

    # 计算连续学习天数（简单版：最近都有记录）
    streak_result = await db.execute(
        select(func.date(QuestionRecord.created_at).label("date"))
        .join(Question, QuestionRecord.question_id == Question.id)
        .join(Chapter, Question.chapter_id == Chapter.id)
        .where(*record_filters)
        .group_by(func.date(QuestionRecord.created_at))
        .order_by(func.date(QuestionRecord.created_at).desc())
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

    # 最近 7 天正确率趋势
    trend_result = await db.execute(
        select(
            func.date(QuestionRecord.created_at).label("date"),
            func.count(QuestionRecord.id).label("total_questions"),
            func.sum(case((QuestionRecord.is_correct == True, 1), else_=0)).label("correct_count"),
        )
        .join(Question, QuestionRecord.question_id == Question.id)
        .join(Chapter, Question.chapter_id == Chapter.id)
        .where(*record_filters)
        .group_by(func.date(QuestionRecord.created_at))
        .order_by(func.date(QuestionRecord.created_at).desc())
        .limit(7)
    )
    trend_rows = list(reversed(trend_result.all()))
    accuracy_trend = [
        {
            "date": date,
            "total_questions": total_questions or 0,
            "correct_count": correct_count or 0,
            "accuracy_rate": (correct_count or 0) / total_questions if total_questions else 0.0,
        }
        for date, total_questions, correct_count in trend_rows
    ]

    # 各章节/科目统计（通过做题记录关联章节）
    subject_result = await db.execute(
        select(
            Chapter.name,
            Chapter.exam_category,
            func.count(QuestionRecord.id).label("total"),
            func.sum(
                case((QuestionRecord.is_correct == True, 1), else_=0)
            ).label("correct"),
        )
        .join(Question, QuestionRecord.question_id == Question.id)
        .join(Chapter, Question.chapter_id == Chapter.id)
        .where(*record_filters)
        .group_by(Chapter.id)
        .order_by(func.count(QuestionRecord.id).desc())
    )
    subject_stats = {}
    for name, exam_category, total_count, correct_count in subject_result.all():
        total_count = total_count or 0
        correct_count = correct_count or 0
        key = name
        if key in subject_stats:
            key = f"{exam_category} · {name}"
        subject_stats[key] = {
            "name": name,
            "exam_category": exam_category,
            "total_questions": total_count,
            "correct_count": correct_count,
            "wrong_count": total_count - correct_count,
            "accuracy_rate": correct_count / total_count if total_count else 0.0,
        }

    return StatsOverview(
        total_questions=total,
        total_correct=correct,
        overall_accuracy=accuracy,
        total_study_time=stats.time or 0,
        current_streak=streak,
        subject_stats=subject_stats,
        accuracy_trend=accuracy_trend,
    )
