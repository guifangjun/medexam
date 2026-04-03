from sqlalchemy import Column, Integer, String, Boolean, DateTime, Float
from sqlalchemy.sql import func
from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(100))
    is_active = Column(Boolean, default=True)
    is_premium = Column(Boolean, default=False)  # 订阅会员
    target_exam = Column(String(50), default="执业医师")  # 执业医师/助理医师
    target_date = Column(DateTime, nullable=True)  # 目标考试日期
    daily_goal = Column(Integer, default=20)  # 每日目标做题数
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
