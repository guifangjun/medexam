from sqlalchemy import Column, Integer, String, Boolean, DateTime, Float
from sqlalchemy.sql import func
from datetime import datetime
from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    phone = Column(String(20), unique=True, index=True, nullable=True)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(100))
    is_active = Column(Boolean, default=True)
    is_premium = Column(Boolean, default=False)  # 订阅会员
    target_exam = Column(String(50), default="执业资格")  # 执业资格/职称类别
    target_date = Column(DateTime, nullable=True)  # 目标考试日期
    daily_goal = Column(Integer, default=20)  # 每日目标做题数
    created_at = Column(DateTime, default=datetime.now, server_default=func.now())
    updated_at = Column(
        DateTime,
        default=datetime.now,
        server_default=func.now(),
        onupdate=datetime.now,
    )
