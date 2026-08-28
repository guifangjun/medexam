from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Boolean, JSON
from sqlalchemy.sql import func
from datetime import datetime
from app.core.database import Base


class AIConversation(Base):
    """AI 对话"""
    __tablename__ = "ai_conversations"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    session_id = Column(String(100), nullable=False)  # 对话会话 ID
    message_type = Column(String(10), nullable=False)  # user/assistant
    content = Column(Text, nullable=False)
    exam_category = Column(String(50), nullable=True)  # 关联考试分类
    related_question_id = Column(Integer, ForeignKey("questions.id"), nullable=True)  # 关联题目
    is_collected = Column(Boolean, default=False)  # 是否收藏
    created_at = Column(DateTime, default=datetime.now, server_default=func.now())


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
    created_at = Column(DateTime, default=datetime.now, server_default=func.now())


class AIKnowledgeCard(Base):
    """用户从 AI 讲解中沉淀的个人记忆卡"""
    __tablename__ = "ai_knowledge_cards"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    exam_category = Column(String(50), nullable=False, index=True)
    source_message_id = Column(
        Integer, ForeignKey("ai_conversations.id"), nullable=True, index=True
    )
    related_question_id = Column(
        Integer, ForeignKey("questions.id"), nullable=True
    )
    title = Column(String(120), nullable=False)
    front = Column(Text, nullable=False)
    back = Column(Text, nullable=False)
    mnemonic = Column(Text, nullable=True)
    tags = Column(JSON, default=list)
    mastery_level = Column(Integer, default=0)
    review_count = Column(Integer, default=0)
    last_reviewed_at = Column(DateTime, nullable=True)
    next_review_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.now, server_default=func.now())
