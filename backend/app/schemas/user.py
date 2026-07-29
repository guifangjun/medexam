from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
from datetime import datetime

from app.core.exam_categories import try_normalize_exam_category


class UserBase(BaseModel):
    username: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    full_name: Optional[str] = None
    target_exam: str = "执业资格"
    target_date: Optional[datetime] = None
    daily_goal: int = 20

    @field_validator("target_exam")
    @classmethod
    def validate_target_exam(cls, value: str) -> str:
        category = try_normalize_exam_category(value)
        if category is None:
            raise ValueError("考试分类不正确")
        return category


class UserCreate(UserBase):
    password: str
    sms_code: str

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        if len(value) < 6:
            raise ValueError("密码至少 6 位")
        return value

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return value
        normalized = value.strip()
        if len(normalized) != 11 or not normalized.isdigit():
            raise ValueError("手机号格式不正确")
        return normalized


class UserLogin(BaseModel):
    username: str
    password: str


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    target_exam: Optional[str] = None
    target_date: Optional[datetime] = None
    daily_goal: Optional[int] = None

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return value
        normalized = value.strip()
        if len(normalized) != 11 or not normalized.isdigit():
            raise ValueError("手机号格式不正确")
        return normalized

    @field_validator("target_exam")
    @classmethod
    def validate_target_exam(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return value
        category = try_normalize_exam_category(value)
        if category is None:
            raise ValueError("考试分类不正确")
        return category


class UserResponse(UserBase):
    id: int
    is_premium: bool
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    user_id: int
    username: str
