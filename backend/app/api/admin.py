from typing import List, Optional
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, Header, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from pydantic import BaseModel
from sqlalchemy import and_, case, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import create_access_token, get_password_hash, verify_password
from app.core.config import settings
from app.core.database import get_db
from app.core.exam_categories import set_active_exam_categories, try_normalize_exam_category
from app.models.admin_user import AdminUser
from app.models.conversation import AIConversation, AIKnowledgeCard
from app.models.course import Course
from app.models.question import Chapter, ExamCategory, Question, QuestionRecord
from app.models.question import ExamAttempt
from app.models.study import DailyTask, StudyPlan, StudyStats, WrongQuestion
from app.models.user import User
from app.schemas.admin_user import AdminUserResponse
from app.schemas.course import CourseCreate, CourseResponse, CourseUpdate
from app.schemas.question import QuestionCreate, QuestionResponse, QuestionUpdate
from app.schemas.user import Token, UserResponse

router = APIRouter(prefix="/api/admin", tags=["管理后台"])
admin_oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/admin/auth/login")


class AdminManagedUserCreate(BaseModel):
    phone: str
    password: str
    full_name: Optional[str] = None
    target_exam: str = "执业资格"
    is_active: bool = True


class AdminManagedUserUpdate(BaseModel):
    phone: Optional[str] = None
    password: Optional[str] = None
    full_name: Optional[str] = None
    target_exam: Optional[str] = None
    is_active: Optional[bool] = None


class ExamCategoryPayload(BaseModel):
    name: str
    parent_id: Optional[int] = None
    level: int = 1
    description: Optional[str] = None
    sort_order: int = 0
    is_active: bool = True


class ExamCategoryUpdatePayload(BaseModel):
    name: Optional[str] = None
    parent_id: Optional[int] = None
    level: Optional[int] = None
    description: Optional[str] = None
    sort_order: Optional[int] = None
    is_active: Optional[bool] = None


async def get_current_admin(
    token: str = Depends(admin_oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> AdminUser:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="无效的后台认证凭据",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        admin_id: int = payload.get("admin_id")
        scope: str = payload.get("scope")
        if admin_id is None or scope != "admin":
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    result = await db.execute(select(AdminUser).where(AdminUser.id == admin_id))
    admin = result.scalar_one_or_none()
    if admin is None or not admin.is_active:
        raise credentials_exception
    return admin


async def get_optional_admin(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
) -> Optional[AdminUser]:
    if not authorization:
        return None
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        return None
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        admin_id: int = payload.get("admin_id")
        scope: str = payload.get("scope")
        if admin_id is None or scope != "admin":
            return None
    except JWTError:
        return None
    result = await db.execute(select(AdminUser).where(AdminUser.id == admin_id))
    admin = result.scalar_one_or_none()
    return admin if admin and admin.is_active else None


async def _sync_runtime_exam_categories(db: AsyncSession) -> None:
    active_items = (
        await db.execute(
            select(ExamCategory)
            .where(ExamCategory.is_active == True)
            .order_by(ExamCategory.sort_order, ExamCategory.id)
        )
    ).scalars().all()
    parent_ids = {item.parent_id for item in active_items if item.parent_id is not None}
    leaf_items = [item for item in active_items if item.id not in parent_ids]
    set_active_exam_categories([item.name for item in leaf_items])


def _exam_category_dict(item: ExamCategory) -> dict:
    return {
        "id": item.id,
        "name": item.name,
        "parent_id": item.parent_id,
        "level": item.level or 1,
        "description": item.description or "",
        "sort_order": item.sort_order or 0,
        "is_active": item.is_active,
        "created_at": item.created_at,
    }


@router.post("/auth/login", response_model=Token)
async def admin_login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AdminUser).where(AdminUser.username == form_data.username)
    )
    admin = result.scalar_one_or_none()
    if not admin or not verify_password(form_data.password, admin.hashed_password):
        raise HTTPException(status_code=401, detail="后台账号或密码错误")
    if not admin.is_active:
        raise HTTPException(status_code=403, detail="后台账号已停用")

    access_token = create_access_token(
        data={"admin_id": admin.id, "username": admin.username, "scope": "admin"}
    )
    return {"access_token": access_token, "token_type": "bearer"}


@router.get("/auth/me", response_model=AdminUserResponse)
async def admin_me(current_admin: AdminUser = Depends(get_current_admin)):
    return current_admin


@router.get("/dashboard")
async def dashboard(
    exam_category: Optional[str] = None,
    date: Optional[str] = None,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    today = date or datetime.now().strftime("%Y-%m-%d")
    category = try_normalize_exam_category(exam_category) if exam_category else None
    if exam_category and category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")

    user_query = select(func.count()).select_from(User)
    question_query = select(func.count()).select_from(Question)
    course_query = select(func.count()).select_from(Course)
    if category:
        user_query = user_query.where(User.target_exam == category)
        question_query = question_query.join(Chapter).where(Chapter.exam_category == category)
        course_query = course_query.where(Course.exam_category == category)
    user_count = await db.scalar(user_query) or 0
    question_count = await db.scalar(question_query) or 0
    course_count = await db.scalar(course_query) or 0
    stats_query = select(
        func.count(StudyStats.user_id.distinct()).label("active_users"),
        func.sum(StudyStats.total_questions).label("questions"),
        func.sum(StudyStats.correct_count).label("correct"),
    ).where(StudyStats.date == today)
    if category:
        stats_query = stats_query.join(User, StudyStats.user_id == User.id).where(
            User.target_exam == category
        )
    today_stats = await db.execute(
        stats_query
    )
    stats = today_stats.one()
    today_questions = stats.questions or 0
    today_correct = stats.correct or 0
    wrong_reviews = await db.scalar(
        select(func.sum(WrongQuestion.review_count)).select_from(WrongQuestion)
    ) or 0
    today_ai_questions = await db.scalar(
        select(func.count(AIConversation.id)).where(
            AIConversation.message_type == "user",
            func.date(AIConversation.created_at) == today,
        )
    ) or 0
    ai_session_count = await db.scalar(
        select(func.count(func.distinct(AIConversation.session_id))).select_from(
            AIConversation
        )
    ) or 0
    ai_collection_count = await db.scalar(
        select(func.count(AIConversation.id)).where(
            AIConversation.message_type == "assistant",
            AIConversation.is_collected == True,
        )
    ) or 0

    category_query = select(User.target_exam, func.count(User.id)).group_by(User.target_exam)
    if category:
        category_query = category_query.where(User.target_exam == category)
    categories = await db.execute(category_query.order_by(func.count(User.id).desc()))
    chapter_query = (
        select(
            Chapter.id,
            Chapter.name,
            Chapter.exam_category,
            func.count(func.distinct(Question.id)).label("question_count"),
            func.count(func.distinct(QuestionRecord.id)).label("practice_count"),
        )
        .outerjoin(Question, Question.chapter_id == Chapter.id)
        .outerjoin(
            QuestionRecord,
            and_(
                QuestionRecord.question_id == Question.id,
                QuestionRecord.selected_answer.is_not(None),
            ),
        )
    )
    if category:
        chapter_query = chapter_query.where(Chapter.exam_category == category)
    chapter_rows = await db.execute(
        chapter_query.group_by(Chapter.id)
        .order_by(func.count(QuestionRecord.id).desc(), Chapter.order)
        .limit(20)
    )
    return {
        "user_count": user_count,
        "question_count": question_count,
        "today_active_users": stats.active_users or 0,
        "today_questions": today_questions,
        "today_accuracy": today_correct / today_questions if today_questions else 0.0,
        "wrong_review_count": wrong_reviews,
        "course_count": course_count,
        "today_ai_questions": today_ai_questions,
        "ai_session_count": ai_session_count,
        "ai_collection_count": ai_collection_count,
        "user_categories": [
            {"name": name or "未设置", "count": count} for name, count in categories.all()
        ],
        "chapter_activity": [
            {
                "chapter_id": row.id,
                "name": row.name,
                "exam_category": row.exam_category,
                "question_count": row.question_count,
                "practice_count": row.practice_count,
            }
            for row in chapter_rows.all()
        ],
    }


@router.get("/exam-categories")
async def list_exam_categories(
    include_inactive: bool = True,
    current_admin: Optional[AdminUser] = Depends(get_optional_admin),
    db: AsyncSession = Depends(get_db),
):
    query = select(ExamCategory).order_by(
        ExamCategory.level, ExamCategory.sort_order, ExamCategory.id
    )
    if current_admin is None or not include_inactive:
        query = query.where(ExamCategory.is_active == True)
    result = await db.execute(query)
    return [_exam_category_dict(item) for item in result.scalars().all()]


@router.post("/exam-categories")
async def create_exam_category(
    payload: ExamCategoryPayload,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    name = payload.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="考试类别名称不能为空")
    if payload.level not in (1, 2, 3):
        raise HTTPException(status_code=400, detail="考试类别层级必须是 1、2 或 3")
    if payload.level > 1 and payload.parent_id is None:
        raise HTTPException(status_code=400, detail="二级/三级考试类别必须选择上级类别")
    exists = await db.scalar(select(ExamCategory).where(ExamCategory.name == name))
    if exists:
        raise HTTPException(status_code=400, detail="考试类别已存在")
    item = ExamCategory(
        name=name,
        parent_id=payload.parent_id,
        level=payload.level,
        description=payload.description,
        sort_order=payload.sort_order,
        is_active=payload.is_active,
    )
    db.add(item)
    await db.flush()
    chapter_exists = None
    if payload.level == 3:
        chapter_exists = await db.scalar(
            select(Chapter).where(Chapter.exam_category == name).limit(1)
        )
    if payload.level == 3 and chapter_exists is None:
        db.add(
            Chapter(
                name="默认章节",
                exam_category=name,
                order=1,
                subjects=["默认科目"],
            )
        )
    await db.commit()
    await db.refresh(item)
    await _sync_runtime_exam_categories(db)
    return _exam_category_dict(item)


@router.put("/exam-categories/{category_id}")
async def update_exam_category(
    category_id: int,
    payload: ExamCategoryUpdatePayload,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    item = await db.get(ExamCategory, category_id)
    if item is None:
        raise HTTPException(status_code=404, detail="考试类别不存在")
    old_name = item.name
    if payload.name is not None:
        name = payload.name.strip()
        if not name:
            raise HTTPException(status_code=400, detail="考试类别名称不能为空")
        exists = await db.scalar(
            select(ExamCategory).where(
                ExamCategory.name == name,
                ExamCategory.id != category_id,
            )
        )
        if exists:
            raise HTTPException(status_code=400, detail="考试类别已存在")
        item.name = name
        if name != old_name:
            for model, field in (
                (Chapter, Chapter.exam_category),
                (Course, Course.exam_category),
                (User, User.target_exam),
                (ExamAttempt, ExamAttempt.exam_category),
                (DailyTask, DailyTask.exam_category),
                (StudyPlan, StudyPlan.exam_category),
                (AIConversation, AIConversation.exam_category),
            ):
                await db.execute(
                    model.__table__.update().where(field == old_name).values(
                        {field.key: name}
                    )
                )
    if payload.description is not None:
        item.description = payload.description
    if payload.parent_id is not None:
        item.parent_id = payload.parent_id
    if payload.level is not None:
        if payload.level not in (1, 2, 3):
            raise HTTPException(status_code=400, detail="考试类别层级必须是 1、2 或 3")
        item.level = payload.level
    if payload.sort_order is not None:
        item.sort_order = payload.sort_order
    if payload.is_active is not None:
        if old_name == "执业资格" and payload.is_active is False:
            raise HTTPException(status_code=400, detail="默认考试类别不能停用")
        item.is_active = payload.is_active
    await db.commit()
    await db.refresh(item)
    await _sync_runtime_exam_categories(db)
    return _exam_category_dict(item)


@router.delete("/exam-categories/{category_id}")
async def delete_exam_category(
    category_id: int,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    item = await db.get(ExamCategory, category_id)
    if item is None:
        raise HTTPException(status_code=404, detail="考试类别不存在")
    if item.name == "执业资格":
        raise HTTPException(status_code=400, detail="默认考试类别不能删除")
    child_count = (
        await db.scalar(
            select(func.count()).select_from(ExamCategory).where(ExamCategory.parent_id == item.id)
        )
        or 0
    )
    if child_count > 0:
        raise HTTPException(status_code=400, detail="该考试类别包含下级分类，请先删除下级分类")
    question_usage = (
        await db.scalar(
            select(func.count())
            .select_from(Question)
            .join(Chapter, Question.chapter_id == Chapter.id)
            .where(Chapter.exam_category == item.name)
        )
        or 0
    )
    business_usage = question_usage
    for model, field in (
        (Course, Course.exam_category),
        (User, User.target_exam),
        (ExamAttempt, ExamAttempt.exam_category),
        (DailyTask, DailyTask.exam_category),
        (StudyPlan, StudyPlan.exam_category),
        (AIConversation, AIConversation.exam_category),
    ):
        business_usage += (
            await db.scalar(select(func.count()).select_from(model).where(field == item.name))
            or 0
        )
    if business_usage > 0:
        raise HTTPException(status_code=400, detail="该考试类别已有业务数据，请先停用或迁移数据")
    await db.execute(delete(Chapter).where(Chapter.exam_category == item.name))
    await db.delete(item)
    await db.commit()
    await _sync_runtime_exam_categories(db)
    return {"message": "删除成功"}


@router.get("/users", response_model=List[UserResponse])
async def list_users(
    keyword: Optional[str] = None,
    exam_category: Optional[str] = None,
    is_active: Optional[bool] = None,
    limit: int = 200,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    query = select(User).order_by(User.created_at.desc()).limit(limit)
    if keyword:
        like = f"%{keyword.strip()}%"
        query = query.where(
            or_(
                User.username.like(like),
                User.phone.like(like),
                User.full_name.like(like),
            )
        )
    if exam_category:
        category = try_normalize_exam_category(exam_category)
        if category is None:
            return []
        query = query.where(User.target_exam == category)
    if is_active is not None:
        query = query.where(User.is_active == is_active)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/users/{user_id}/learning-analysis")
async def get_user_learning_analysis(
    user_id: int,
    exam_category: Optional[str] = None,
    days: int = 30,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    if days not in (7, 30, 90):
        raise HTTPException(status_code=400, detail="统计周期仅支持 7、30、90 天")

    user = await db.scalar(select(User).where(User.id == user_id))
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    category = try_normalize_exam_category(exam_category) if exam_category else user.target_exam
    if category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")

    now = datetime.now()
    today = now.strftime("%Y-%m-%d")
    start_date = (now - timedelta(days=days - 1)).strftime("%Y-%m-%d")

    stats_rows = (
        await db.execute(
            select(StudyStats)
            .where(
                StudyStats.user_id == user_id,
                StudyStats.date >= start_date,
                StudyStats.date <= today,
            )
            .order_by(StudyStats.date.asc())
        )
    ).scalars().all()
    trend = [
        {
            "date": row.date,
            "total_questions": row.total_questions or 0,
            "correct_count": row.correct_count or 0,
            "wrong_count": row.wrong_count or 0,
            "accuracy_rate": row.accuracy_rate or 0.0,
            "time_spent": row.time_spent or 0,
            "ai_questions": row.ai_questions or 0,
        }
        for row in stats_rows
    ]
    total_questions = sum(item["total_questions"] for item in trend)
    correct_count = sum(item["correct_count"] for item in trend)
    wrong_count = sum(item["wrong_count"] for item in trend)
    total_time = sum(item["time_spent"] for item in trend)
    active_days = sum(1 for item in trend if item["total_questions"] > 0 or item["time_spent"] > 0)
    last_study_date = next(
        (
            item["date"]
            for item in reversed(trend)
            if item["total_questions"] > 0 or item["time_spent"] > 0
        ),
        None,
    )
    today_row = next((item for item in trend if item["date"] == today), None)

    record_totals = await db.execute(
        select(
            func.count(QuestionRecord.id).label("total"),
            func.sum(
                case((QuestionRecord.is_correct == True, 1), else_=0)
            ).label("correct"),
            func.sum(QuestionRecord.time_spent).label("time_spent"),
        )
        .join(Question, QuestionRecord.question_id == Question.id)
        .join(Chapter, Question.chapter_id == Chapter.id)
        .where(
            QuestionRecord.user_id == user_id,
            Chapter.exam_category == category,
        )
    )
    record_summary = record_totals.one()
    lifetime_questions = record_summary.total or 0
    lifetime_correct = record_summary.correct or 0
    lifetime_time = record_summary.time_spent or 0

    wrong_stats = await db.execute(
        select(
            func.count(WrongQuestion.id).label("total"),
            func.sum(case((WrongQuestion.is_mastered == False, 1), else_=0)).label("pending"),
            func.sum(case((WrongQuestion.is_mastered == True, 1), else_=0)).label("mastered"),
            func.sum(WrongQuestion.review_count).label("reviews"),
        )
        .join(Question, WrongQuestion.question_id == Question.id)
        .join(Chapter, Question.chapter_id == Chapter.id)
        .where(WrongQuestion.user_id == user_id, Chapter.exam_category == category)
    )
    wrong = wrong_stats.one()

    exam_stats = await db.execute(
        select(
            func.count(ExamAttempt.id).label("count"),
            func.avg(ExamAttempt.accuracy_rate).label("avg_accuracy"),
            func.max(ExamAttempt.score).label("best_score"),
        ).where(
            ExamAttempt.user_id == user_id,
            ExamAttempt.exam_category == category,
        )
    )
    exam = exam_stats.one()
    recent_exam = (
        await db.execute(
            select(ExamAttempt)
            .where(ExamAttempt.user_id == user_id, ExamAttempt.exam_category == category)
            .order_by(ExamAttempt.created_at.desc())
            .limit(5)
        )
    ).scalars().all()

    ai_stats = await db.execute(
        select(
            func.count(AIConversation.id).label("messages"),
            func.count(func.distinct(AIConversation.session_id)).label("sessions"),
            func.sum(
                case((AIConversation.message_type == "user", 1), else_=0)
            ).label("questions"),
            func.sum(
                case((AIConversation.is_collected == True, 1), else_=0)
            ).label("collections"),
        ).where(
            AIConversation.user_id == user_id,
            or_(AIConversation.exam_category == category, AIConversation.exam_category.is_(None)),
        )
    )
    ai = ai_stats.one()
    knowledge_card_count = await db.scalar(
        select(func.count(AIKnowledgeCard.id)).where(
            AIKnowledgeCard.user_id == user_id,
            AIKnowledgeCard.exam_category == category,
        )
    ) or 0

    weak_rows = await db.execute(
        select(
            Chapter.id.label("chapter_id"),
            Chapter.name.label("chapter_name"),
            func.count(QuestionRecord.id).label("total"),
            func.sum(case((QuestionRecord.is_correct == False, 1), else_=0)).label("wrong"),
            func.sum(case((QuestionRecord.is_correct == True, 1), else_=0)).label("correct"),
        )
        .join(Question, Question.chapter_id == Chapter.id)
        .join(QuestionRecord, QuestionRecord.question_id == Question.id)
        .where(
            QuestionRecord.user_id == user_id,
            Chapter.exam_category == category,
        )
        .group_by(Chapter.id, Chapter.name)
        .having(func.count(QuestionRecord.id) > 0)
        .order_by(
            (func.sum(case((QuestionRecord.is_correct == True, 1), else_=0)) * 1.0
             / func.count(QuestionRecord.id)).asc(),
            func.count(QuestionRecord.id).desc(),
        )
        .limit(8)
    )
    weak_chapters = []
    for row in weak_rows.all():
        total = row.total or 0
        correct = row.correct or 0
        weak_chapters.append(
            {
                "chapter_id": row.chapter_id,
                "chapter_name": row.chapter_name,
                "total_questions": total,
                "wrong_count": row.wrong or 0,
                "correct_count": correct,
                "accuracy_rate": correct / total if total else 0.0,
            }
        )

    recent_active = [
        item for item in trend[-7:] if item["total_questions"] > 0 or item["time_spent"] > 0
    ]
    advice = []
    overall_accuracy = (lifetime_correct / lifetime_questions) if lifetime_questions else 0.0
    pending_wrong = wrong.pending or 0
    if not recent_active:
        advice.append("近 7 天无学习记录，建议运营提醒回访。")
    if lifetime_questions > 0 and overall_accuracy < 0.6:
        advice.append("综合正确率低于 60%，建议先回到基础章节巩固。")
    if pending_wrong >= 10:
        advice.append("待复习错题较多，建议优先安排错题复习。")
    if (exam.count or 0) > 0 and (exam.avg_accuracy or 0) < 0.6 and weak_chapters:
        advice.append("模考表现偏弱且错题集中，建议按薄弱章节做专项练习。")
    if (ai.questions or 0) < 3:
        advice.append("AI 使用较少，可引导学员使用 AI 解析、错因雷达和学习路径。")
    if not advice:
        advice.append("学习节奏正常，可继续跟进今日任务、错题复习和阶段模考。")

    return {
        "user": {
            "id": user.id,
            "phone": user.phone or user.username,
            "username": user.username,
            "full_name": user.full_name,
            "target_exam": user.target_exam,
            "is_active": user.is_active,
            "is_premium": user.is_premium,
            "created_at": user.created_at.isoformat() if user.created_at else None,
        },
        "exam_category": category,
        "days": days,
        "overview": {
            "total_questions": lifetime_questions,
            "correct_count": lifetime_correct,
            "wrong_count": max(lifetime_questions - lifetime_correct, 0),
            "accuracy_rate": overall_accuracy,
            "study_time": lifetime_time,
            "period_questions": total_questions,
            "period_correct": correct_count,
            "period_wrong": wrong_count,
            "period_accuracy": correct_count / total_questions if total_questions else 0.0,
            "period_study_time": total_time,
            "active_days": active_days,
            "last_study_date": last_study_date,
        },
        "today": today_row
        or {
            "date": today,
            "total_questions": 0,
            "correct_count": 0,
            "wrong_count": 0,
            "accuracy_rate": 0.0,
            "time_spent": 0,
            "ai_questions": 0,
        },
        "wrong": {
            "total": wrong.total or 0,
            "pending": pending_wrong,
            "mastered": wrong.mastered or 0,
            "review_count": wrong.reviews or 0,
        },
        "exam": {
            "count": exam.count or 0,
            "avg_accuracy": exam.avg_accuracy or 0.0,
            "best_score": exam.best_score or 0,
            "recent": [
                {
                    "id": item.id,
                    "score": item.score or 0,
                    "accuracy_rate": item.accuracy_rate or 0.0,
                    "total_questions": item.total_questions or 0,
                    "correct_count": item.correct_count or 0,
                    "wrong_count": item.wrong_count or 0,
                    "time_spent": item.time_spent or 0,
                    "created_at": item.created_at.isoformat()
                    if item.created_at
                    else None,
                }
                for item in recent_exam
            ],
        },
        "ai": {
            "message_count": ai.messages or 0,
            "session_count": ai.sessions or 0,
            "question_count": ai.questions or 0,
            "collection_count": ai.collections or 0,
            "knowledge_card_count": knowledge_card_count,
        },
        "weak_chapters": weak_chapters,
        "trend": trend,
        "advice": advice,
    }


@router.post("/users", response_model=UserResponse)
async def create_user(
    user: AdminManagedUserCreate,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    phone = user.phone.strip()
    if len(phone) != 11 or not phone.isdigit():
        raise HTTPException(status_code=400, detail="手机号格式不正确")
    if len(user.password) < 6:
        raise HTTPException(status_code=400, detail="密码至少 6 位")
    target_exam = try_normalize_exam_category(user.target_exam)
    if target_exam is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")

    result = await db.execute(
        select(User).where(or_(User.username == phone, User.phone == phone))
    )
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="手机号已存在")

    db_user = User(
        username=phone,
        phone=phone,
        email=f"{phone}@phone.medexam.cn",
        hashed_password=get_password_hash(user.password),
        full_name=user.full_name,
        target_exam=target_exam,
        is_active=user.is_active,
    )
    db.add(db_user)
    await db.commit()
    await db.refresh(db_user)
    return db_user


@router.put("/users/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: int,
    user_update: AdminManagedUserUpdate,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    db_user = result.scalar_one_or_none()
    if not db_user:
        raise HTTPException(status_code=404, detail="用户不存在")

    update_data = user_update.model_dump(exclude_unset=True)
    if "phone" in update_data:
        phone = (update_data.pop("phone") or "").strip()
        if len(phone) != 11 or not phone.isdigit():
            raise HTTPException(status_code=400, detail="手机号格式不正确")
        result = await db.execute(
            select(User).where(
                or_(User.username == phone, User.phone == phone),
                User.id != user_id,
            )
        )
        if result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="手机号已存在")
        db_user.username = phone
        db_user.phone = phone
        db_user.email = f"{phone}@phone.medexam.cn"
    if "password" in update_data:
        password = update_data.pop("password")
        if password:
            if len(password) < 6:
                raise HTTPException(status_code=400, detail="密码至少 6 位")
            db_user.hashed_password = get_password_hash(password)
    for key, value in update_data.items():
        if key == "target_exam":
            category = try_normalize_exam_category(value)
            if category is None:
                raise HTTPException(status_code=400, detail="考试分类不正确")
            value = category
        setattr(db_user, key, value)
    await db.commit()
    await db.refresh(db_user)
    return db_user


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: int,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    db_user = result.scalar_one_or_none()
    if not db_user:
        raise HTTPException(status_code=404, detail="用户不存在")
    for model in (
        AIConversation,
        AIKnowledgeCard,
        WrongQuestion,
        QuestionRecord,
        ExamAttempt,
        DailyTask,
        StudyStats,
        StudyPlan,
    ):
        await db.execute(delete(model).where(model.user_id == user_id))
    await db.delete(db_user)
    await db.commit()
    return {"message": "删除成功"}


@router.get("/questions", response_model=List[QuestionResponse])
async def list_questions(
    chapter_id: Optional[int] = None,
    exam_category: Optional[str] = None,
    keyword: Optional[str] = None,
    limit: int = 100,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    query = select(Question).order_by(Question.created_at.desc()).limit(limit)
    if chapter_id:
        if exam_category:
            category = try_normalize_exam_category(exam_category)
            if category is None:
                return []
            query = query.join(Chapter).where(
                Question.chapter_id == chapter_id,
                Chapter.exam_category == category,
            )
        else:
            query = query.where(Question.chapter_id == chapter_id)
    elif exam_category:
        category = try_normalize_exam_category(exam_category)
        if category is None:
            return []
        query = query.join(Chapter).where(Chapter.exam_category == category)
    if keyword:
        query = query.where(Question.content.contains(keyword))
    result = await db.execute(query)
    return result.scalars().all()

@router.post("/questions", response_model=QuestionResponse)
async def create_question(
    question: QuestionCreate,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    data = _question_data_for_db(question.model_dump())
    await _validate_question_chapter(db, data["chapter_id"])
    _validate_question_answer(data["answer"], data["options"])
    db_question = Question(**data)
    db.add(db_question)
    await db.commit()
    await db.refresh(db_question)
    return db_question


@router.put("/questions/{question_id}", response_model=QuestionResponse)
async def update_question(
    question_id: int,
    question: QuestionUpdate,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Question).where(Question.id == question_id))
    db_question = result.scalar_one_or_none()
    if not db_question:
        raise HTTPException(status_code=404, detail="题目不存在")

    update_data = _question_data_for_db(question.model_dump(exclude_unset=True))
    if "chapter_id" in update_data:
        await _validate_question_chapter(db, update_data["chapter_id"])
    next_answer = update_data.get("answer", db_question.answer)
    next_options = update_data.get("options", db_question.options or {})
    _validate_question_answer(next_answer, next_options)

    for key, value in update_data.items():
        setattr(db_question, key, value)
    await db.commit()
    await db.refresh(db_question)
    return db_question


@router.delete("/questions/{question_id}")
async def delete_question(
    question_id: int,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Question).where(Question.id == question_id))
    db_question = result.scalar_one_or_none()
    if not db_question:
        raise HTTPException(status_code=404, detail="题目不存在")
    await db.execute(
        delete(WrongQuestion).where(WrongQuestion.question_id == question_id)
    )
    await db.execute(
        delete(QuestionRecord).where(QuestionRecord.question_id == question_id)
    )
    await db.delete(db_question)
    await db.commit()
    return {"message": "删除成功"}


@router.get("/courses", response_model=List[CourseResponse])
async def list_courses(
    course_type: Optional[str] = None,
    exam_category: Optional[str] = None,
    unlinked_only: Optional[bool] = None,
    current_admin: Optional[AdminUser] = Depends(get_optional_admin),
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(
            Course,
            Chapter.name.label("chapter_name"),
            func.count(Question.id).label("chapter_question_count"),
        )
        .outerjoin(Chapter, Course.chapter_id == Chapter.id)
        .outerjoin(Question, Question.chapter_id == Course.chapter_id)
        .group_by(Course.id)
        .order_by(Course.created_at.desc())
    )
    if current_admin is None:
        query = query.where(Course.is_published == True)
    if course_type:
        query = query.where(Course.course_type == course_type)
    if exam_category:
        category = try_normalize_exam_category(exam_category)
        if category is None:
            return []
        query = query.where(Course.exam_category == category)
    if unlinked_only:
        query = query.where(Course.chapter_id.is_(None))
    result = await db.execute(query)
    courses = []
    for course, chapter_name, chapter_question_count in result.all():
        courses.append(
            _course_response(
                course,
                chapter_name=chapter_name,
                chapter_question_count=chapter_question_count,
            )
        )
    return courses


@router.post("/courses", response_model=CourseResponse)
async def create_course(
    course: CourseCreate,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    data = course.model_dump()
    await _validate_course_chapter(
        db, data.get("chapter_id"), data["exam_category"]
    )
    db_course = Course(**data)
    db.add(db_course)
    await db.commit()
    await db.refresh(db_course)
    return await _course_response_with_chapter(db, db_course)


@router.put("/courses/{course_id}", response_model=CourseResponse)
async def update_course(
    course_id: int,
    course: CourseUpdate,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Course).where(Course.id == course_id))
    db_course = result.scalar_one_or_none()
    if not db_course:
        raise HTTPException(status_code=404, detail="课程不存在")

    update_data = course.model_dump(exclude_unset=True)
    next_exam_category = update_data.get(
        "exam_category", db_course.exam_category
    )
    next_chapter_id = update_data.get("chapter_id", db_course.chapter_id)
    await _validate_course_chapter(db, next_chapter_id, next_exam_category)

    for key, value in update_data.items():
        setattr(db_course, key, value)
    await db.commit()
    await db.refresh(db_course)
    return await _course_response_with_chapter(db, db_course)


@router.delete("/courses/{course_id}")
async def delete_course(
    course_id: int,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Course).where(Course.id == course_id))
    db_course = result.scalar_one_or_none()
    if not db_course:
        raise HTTPException(status_code=404, detail="课程不存在")
    await db.delete(db_course)
    await db.commit()
    return {"message": "删除成功"}


async def _validate_course_chapter(
    db: AsyncSession, chapter_id: Optional[int], exam_category: str
) -> None:
    if chapter_id is None:
        return
    result = await db.execute(select(Chapter).where(Chapter.id == chapter_id))
    chapter = result.scalar_one_or_none()
    if not chapter:
        raise HTTPException(status_code=400, detail="关联章节不存在")
    if chapter.exam_category != exam_category:
        raise HTTPException(
            status_code=400,
            detail="关联章节必须属于课程考试类型",
        )


def _course_response(
    course: Course,
    chapter_name: Optional[str] = None,
    chapter_question_count: Optional[int] = 0,
) -> dict:
    item = CourseResponse.model_validate(course).model_dump()
    item["chapter_name"] = chapter_name
    item["chapter_question_count"] = chapter_question_count or 0
    return item


async def _course_response_with_chapter(db: AsyncSession, course: Course) -> dict:
    if course.chapter_id is None:
        return _course_response(course)
    row = await db.execute(
        select(
            Chapter.name.label("chapter_name"),
            func.count(Question.id).label("chapter_question_count"),
        )
        .outerjoin(Question, Question.chapter_id == Chapter.id)
        .where(Chapter.id == course.chapter_id)
        .group_by(Chapter.id)
    )
    chapter_name, chapter_question_count = row.one_or_none() or (None, 0)
    return _course_response(
        course,
        chapter_name=chapter_name,
        chapter_question_count=chapter_question_count,
    )


async def _validate_question_chapter(db: AsyncSession, chapter_id: int) -> None:
    result = await db.execute(select(Chapter.id).where(Chapter.id == chapter_id))
    if result.scalar_one_or_none() is None:
        raise HTTPException(status_code=400, detail="章节不存在")


def _question_data_for_db(data: dict) -> dict:
    if "tags" in data:
        data["知识点"] = data.pop("tags") or []
    return data


def _validate_question_answer(answer: str, options: dict) -> None:
    option_keys = {str(key).strip().upper() for key in (options or {}).keys()}
    answers = [item.strip().upper() for item in str(answer).split(",") if item.strip()]
    if not answers or any(item not in option_keys for item in answers):
        raise HTTPException(status_code=400, detail="答案必须匹配选项")
