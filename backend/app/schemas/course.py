from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class CourseBase(BaseModel):
    title: str
    course_type: str = "recorded"
    exam_category: str = "执业资格"
    teacher: str
    schedule: str
    lesson_count: int = 1
    description: Optional[str] = None
    is_published: bool = True


class CourseCreate(CourseBase):
    pass


class CourseUpdate(BaseModel):
    title: Optional[str] = None
    course_type: Optional[str] = None
    exam_category: Optional[str] = None
    teacher: Optional[str] = None
    schedule: Optional[str] = None
    lesson_count: Optional[int] = None
    description: Optional[str] = None
    is_published: Optional[bool] = None


class CourseResponse(CourseBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True
