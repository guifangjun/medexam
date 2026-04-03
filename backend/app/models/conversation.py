from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Boolean, JSON
from sqlalchemy.sql import func
from app.core.database import Base


class AIConversation(Base):
    """AI 对话"""
    __tablename__ = "ai_conversations"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    session_id = Column(String(100), nullable=False)  # 对话会话 ID
    message_type = Column(String(10), nullable=False)  # user/assistant
    content = Column(Text, nullable=False)
    related_question_id = Column(Integer, ForeignKey("questions.id"), nullable=True)  # 关联题目
    is_collected = Column(Boolean, default=False)  # 是否收藏
    created_at = Column(DateTime, server_default=func.now())


class KnowledgePoint(Base):
    """知识点"""
    __tablename__ = "knowledge_points"

    id = Column(Integer, primary_key=True, index=True)
    chapter_id = Column(Integer, ForeignKey("chapters.id"), nullable=False)
    name = Column(String(200), nullable=False)
    content = Column(Text)  # 知识点内容
    keywords = Column(JSON, default=list)  # 关键词
    related_points = Column(JSON, default=list)  # 相关知识点
    difficulty = Column(Integer, default=3)  # 1-5
    exam_frequency = Column(Integer, default=0)  # 考试频次
    created_at = Column(DateTime, server_default=func.now())
