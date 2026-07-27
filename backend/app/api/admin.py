from typing import List, Optional
from datetime import datetime

from fastapi import APIRouter, Depends, Header, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from pydantic import BaseModel
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import create_access_token, get_password_hash, verify_password
from app.core.config import settings
from app.core.database import get_db
from app.models.admin_user import AdminUser
from app.models.course import Course
from app.models.question import Chapter, Question, QuestionRecord
from app.models.study import StudyStats, WrongQuestion
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
    is_active: Optional[bool] = None
    target_exam: Optional[str] = None


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
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    today = datetime.now().strftime("%Y-%m-%d")
    user_count = await db.scalar(select(func.count()).select_from(User)) or 0
    course_count = await db.scalar(select(func.count()).select_from(Course)) or 0
    today_stats = await db.execute(
        select(
            func.count(StudyStats.user_id.distinct()).label("active_users"),
            func.sum(StudyStats.total_questions).label("questions"),
            func.sum(StudyStats.correct_count).label("correct"),
        ).where(StudyStats.date == today)
    )
    stats = today_stats.one()
    today_questions = stats.questions or 0
    today_correct = stats.correct or 0
    wrong_reviews = await db.scalar(
        select(func.sum(WrongQuestion.review_count)).select_from(WrongQuestion)
    ) or 0

    categories = await db.execute(
        select(User.target_exam, func.count(User.id))
        .group_by(User.target_exam)
        .order_by(func.count(User.id).desc())
    )
    chapter_rows = await db.execute(
        select(
            Chapter.id,
            Chapter.name,
            Chapter.exam_category,
            func.count(Question.id).label("question_count"),
            func.count(QuestionRecord.id).label("practice_count"),
        )
        .outerjoin(Question, Question.chapter_id == Chapter.id)
        .outerjoin(QuestionRecord, QuestionRecord.question_id == Question.id)
        .group_by(Chapter.id)
        .order_by(func.count(QuestionRecord.id).desc(), Chapter.order)
        .limit(20)
    )
    return {
        "user_count": user_count,
        "today_active_users": stats.active_users or 0,
        "today_questions": today_questions,
        "today_accuracy": today_correct / today_questions if today_questions else 0.0,
        "wrong_review_count": wrong_reviews,
        "course_count": course_count,
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
        query = query.where(User.target_exam == exam_category)
    if is_active is not None:
        query = query.where(User.is_active == is_active)
    result = await db.execute(query)
    return result.scalars().all()


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
        target_exam=user.target_exam,
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
        query = query.where(Question.chapter_id == chapter_id)
    elif exam_category:
        query = query.join(Chapter).where(Chapter.exam_category == exam_category)
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
    db_question = Question(**question.model_dump())
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

    for key, value in question.model_dump(exclude_unset=True).items():
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
    await db.delete(db_question)
    await db.commit()
    return {"message": "删除成功"}


@router.get("/courses", response_model=List[CourseResponse])
async def list_courses(
    course_type: Optional[str] = None,
    exam_category: Optional[str] = None,
    current_admin: Optional[AdminUser] = Depends(get_optional_admin),
    db: AsyncSession = Depends(get_db),
):
    query = select(Course).order_by(Course.created_at.desc())
    if current_admin is None:
        query = query.where(Course.is_published == True)
    if course_type:
        query = query.where(Course.course_type == course_type)
    if exam_category:
        query = query.where(Course.exam_category == exam_category)
    result = await db.execute(query)
    return result.scalars().all()


@router.post("/courses", response_model=CourseResponse)
async def create_course(
    course: CourseCreate,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    db_course = Course(**course.model_dump())
    db.add(db_course)
    await db.commit()
    await db.refresh(db_course)
    return db_course


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

    for key, value in course.model_dump(exclude_unset=True).items():
        setattr(db_course, key, value)
    await db.commit()
    await db.refresh(db_course)
    return db_course


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
