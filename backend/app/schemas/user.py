from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime


class UserBase(BaseModel):
    username: str
    email: EmailStr
    full_name: Optional[str] = None
    target_exam: str = "执业医师"
    target_date: Optional[datetime] = None
    daily_goal: int = 20


class UserCreate(UserBase):
    password: str


class UserLogin(BaseModel):
    username: str
    password: str


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
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
