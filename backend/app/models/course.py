from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime
from sqlalchemy.sql import func
from app.core.database import Base


class Course(Base):
    """视频课程"""
    __tablename__ = "courses"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(160), nullable=False)
    course_type = Column(String(20), nullable=False, default="recorded")
    exam_category = Column(String(50), nullable=False, default="执业资格")
    teacher = Column(String(100), nullable=False)
    schedule = Column(String(100), nullable=False)
    lesson_count = Column(Integer, default=1)
    description = Column(Text, nullable=True)
    is_published = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())
