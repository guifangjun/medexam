from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey, JSON, Float
from sqlalchemy.sql import func
from app.core.database import Base


class WrongQuestion(Base):
    """错题本"""
    __tablename__ = "wrong_questions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    question_id = Column(Integer, ForeignKey("questions.id"), nullable=False)
    wrong_reason = Column(String(50))  # 粗心/概念不清/记忆模糊
    review_count = Column(Integer, default=0)  # 复习次数
    last_reviewed_at = Column(DateTime, nullable=True)
    next_review_at = Column(DateTime, nullable=True)  # 艾宾浩斯下次复习时间
    is_mastered = Column(Boolean, default=False)  # 是否已掌握
    created_at = Column(DateTime, server_default=func.now())


class StudyPlan(Base):
    """学习计划"""
    __tablename__ = "study_plans"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String(100), nullable=False)
    plan_type = Column(String(20), default="daily")  # daily/weekly/custom
    target_chapters = Column(JSON, default=list)  # 目标章节列表
    daily_questions = Column(Integer, default=20)
    start_date = Column(DateTime, nullable=False)
    end_date = Column(DateTime, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())


class DailyTask(Base):
    """每日任务"""
    __tablename__ = "daily_tasks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    plan_id = Column(Integer, ForeignKey("study_plans.id"), nullable=True)
    date = Column(String(10), nullable=False)  # YYYY-MM-DD
    target_questions = Column(Integer, default=20)
    completed_questions = Column(Integer, default=0)
    target_chapters = Column(JSON, default=list)
    is_completed = Column(Boolean, default=False)
    created_at = Column(DateTime, server_default=func.now())


class StudyStats(Base):
    """学习统计"""
    __tablename__ = "study_stats"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    date = Column(String(10), nullable=False)  # YYYY-MM-DD
    total_questions = Column(Integer, default=0)
    correct_count = Column(Integer, default=0)
    wrong_count = Column(Integer, default=0)
    accuracy_rate = Column(Float, default=0.0)  # 正确率
    time_spent = Column(Integer, default=0)  # 学习时长(秒)
    ai_questions = Column(Integer, default=0)  # 向 AI 提问次数
    created_at = Column(DateTime, server_default=func.now())
