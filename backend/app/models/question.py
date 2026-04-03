from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey, JSON
from sqlalchemy.sql import func
from app.core.database import Base


class Chapter(Base):
    """考试大纲章节"""
    __tablename__ = "chapters"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)  # 章节名称
    parent_id = Column(Integer, ForeignKey("chapters.id"), nullable=True)  # 父章节
    order = Column(Integer, default=0)  # 排序
    subjects = Column(JSON, default=list)  # 包含的科目，如 ["内科学", "外科学"]


class Question(Base):
    """题目"""
    __tablename__ = "questions"

    id = Column(Integer, primary_key=True, index=True)
    chapter_id = Column(Integer, ForeignKey("chapters.id"), nullable=False)
    question_type = Column(String(20), default="single")  # single/multi/case
    content = Column(Text, nullable=False)  # 题干
    options = Column(JSON, default=dict)  # 选项 {"A": "...", "B": "...", ...}
    answer = Column(String(10), nullable=False)  # 答案 A/B/C/D
    explanation = Column(Text)  # 解析
    difficulty = Column(Integer, default=3)  # 1-5 难度
    is_real_exam = Column(Boolean, default=False)  # 是否真题
    exam_year = Column(Integer, nullable=True)  # 真题年份
    知识点 = Column(JSON, default=list)  # 相关知识点标签
    created_at = Column(DateTime, server_default=func.now())


class QuestionRecord(Base):
    """用户做题记录"""
    __tablename__ = "question_records"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    question_id = Column(Integer, ForeignKey("questions.id"), nullable=False)
    selected_answer = Column(String(10))  # 用户选择的答案
    is_correct = Column(Boolean, nullable=False)
    is_wrong = Column(Boolean, default=False)  # 是否进入错题本
    wrong_reason = Column(String(50), nullable=True)  # 粗心/概念不清/记忆模糊
    time_spent = Column(Integer, default=0)  # 花费秒数
    created_at = Column(DateTime, server_default=func.now())
