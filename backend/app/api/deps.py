from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import or_, select
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta
from typing import Optional
import random

from app.core.database import get_db
from app.core.config import settings
from app.core.exam_categories import try_normalize_exam_category
from app.models.user import User
from app.schemas.user import UserCreate, UserResponse, UserLogin, Token, UserUpdate

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="无效的认证凭据",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: int = payload.get("user_id")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        raise credentials_exception
    return user


router = APIRouter(prefix="/api/auth", tags=["认证"])
_sms_codes: dict[str, dict] = {}
SMS_CODE_TTL_MINUTES = 5


def _get_valid_sms_record(phone: str, purpose: str) -> Optional[dict]:
    record = _sms_codes.get(phone)
    if not record or record.get("purpose") != purpose:
        return None
    expires_at = record.get("expires_at")
    if expires_at and datetime.utcnow() > expires_at:
        _sms_codes.pop(phone, None)
        return None
    return record


@router.post("/sms-code")
async def send_sms_code(payload: dict, db: AsyncSession = Depends(get_db)):
    phone = str(payload.get("phone", "")).strip()
    purpose = str(payload.get("purpose", "login")).strip()
    if len(phone) != 11 or not phone.isdigit():
        raise HTTPException(status_code=400, detail="手机号格式不正确")
    if purpose not in {"login", "register"}:
        raise HTTPException(status_code=400, detail="验证码用途不正确")

    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()
    if purpose == "login":
        if not user or not user.is_active:
            raise HTTPException(status_code=400, detail="手机号未注册或账号已停用")
    elif user:
        raise HTTPException(status_code=400, detail="手机号已注册，请直接登录")

    code = f"{random.randint(0, 999999):06d}"
    _sms_codes[phone] = {
        "code": code,
        "purpose": purpose,
        "expires_at": datetime.utcnow() + timedelta(minutes=SMS_CODE_TTL_MINUTES),
    }
    # 本地演示环境没有真实短信网关，直接返回验证码，前端用于提示用户。
    return {"message": "验证码已发送", "code": code}


@router.post("/register", response_model=UserResponse)
async def register(user: UserCreate, db: AsyncSession = Depends(get_db)):
    if not user.phone:
        raise HTTPException(status_code=400, detail="请输入手机号")
    sms_record = _get_valid_sms_record(user.phone, "register")
    if (
        not sms_record
        or user.sms_code != sms_record.get("code")
    ):
        raise HTTPException(status_code=400, detail="手机验证码错误")

    username = user.phone
    # 检查用户名是否存在
    result = await db.execute(select(User).where(User.username == username))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="手机号已注册")

    result = await db.execute(select(User).where(User.phone == user.phone))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="手机号已注册")

    email = user.email or f"{user.phone}@phone.medexam.cn"

    db_user = User(
        username=username,
        email=email,
        phone=user.phone,
        hashed_password=get_password_hash(user.password),
        full_name=user.full_name,
        target_exam=user.target_exam,
        target_date=user.target_date,
        daily_goal=user.daily_goal,
    )
    db.add(db_user)
    await db.commit()
    await db.refresh(db_user)
    _sms_codes.pop(user.phone, None)
    return db_user


@router.post("/login", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: AsyncSession = Depends(get_db)):
    phone = form_data.username.strip()
    if len(phone) != 11 or not phone.isdigit():
        raise HTTPException(status_code=401, detail="登录账号必须是手机号")
    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()
    if (
        not user
        or not user.is_active
        or not verify_password(form_data.password, user.hashed_password)
    ):
        raise HTTPException(
            status_code=401,
            detail="手机号未注册、密码错误或账号已停用",
        )

    access_token = create_access_token(data={"user_id": user.id, "username": user.username})
    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/login/sms", response_model=Token)
async def login_with_sms(payload: dict, db: AsyncSession = Depends(get_db)):
    phone = str(payload.get("phone", "")).strip()
    sms_code = str(payload.get("sms_code", "")).strip()
    if len(phone) != 11 or not phone.isdigit():
        raise HTTPException(status_code=401, detail="登录账号必须是手机号")
    sms_record = _get_valid_sms_record(phone, "login")
    if (
        not sms_record
        or sms_code != sms_record.get("code")
    ):
        raise HTTPException(status_code=401, detail="手机验证码错误")

    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="手机号未注册")

    _sms_codes.pop(phone, None)
    access_token = create_access_token(data={"user_id": user.id, "username": user.username})
    return {"access_token": access_token, "token_type": "bearer"}


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.put("/me", response_model=UserResponse)
async def update_me(
    user_update: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    update_data = user_update.model_dump(exclude_unset=True)
    if "phone" in update_data:
        phone = (update_data.pop("phone") or "").strip()
        if len(phone) != 11 or not phone.isdigit():
            raise HTTPException(status_code=400, detail="手机号格式不正确")
        result = await db.execute(
            select(User).where(
                or_(User.username == phone, User.phone == phone),
                User.id != current_user.id,
            )
        )
        if result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="手机号已注册")
        current_user.username = phone
        current_user.phone = phone
        current_user.email = f"{phone}@phone.medexam.cn"
    for key, value in update_data.items():
        setattr(current_user, key, value)
    await db.commit()
    await db.refresh(current_user)
    return current_user
