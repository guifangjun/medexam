from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
from datetime import datetime


class UserBase(BaseModel):
    username: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    full_name: Optional[str] = None
    target_exam: str = "执业医师"
    target_date: Optional[datetime] = None
    daily_goal: int = 20


class UserCreate(UserBase):
    password: str
    sms_code: str

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
