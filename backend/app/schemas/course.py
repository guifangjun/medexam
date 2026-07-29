from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator

from app.core.exam_categories import try_normalize_exam_category


class CourseBase(BaseModel):
    title: str = Field(min_length=1)
    course_type: str = Field(default="recorded", pattern="^(live|recorded)$")
    exam_category: str = "执业资格"
    chapter_id: Optional[int] = None
    teacher: str = Field(min_length=1)
    schedule: str = Field(min_length=1)
    lesson_count: int = Field(default=1, ge=1, le=999)
    description: Optional[str] = None
    is_published: bool = True

    @field_validator("exam_category")
    @classmethod
    def validate_exam_category(cls, value: str) -> str:
        category = try_normalize_exam_category(value)
        if category is None:
            raise ValueError("考试分类不正确")
        return category


class CourseCreate(CourseBase):
    pass


class CourseUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1)
    course_type: Optional[str] = Field(default=None, pattern="^(live|recorded)$")
    exam_category: Optional[str] = None
    chapter_id: Optional[int] = None
    teacher: Optional[str] = Field(default=None, min_length=1)
    schedule: Optional[str] = Field(default=None, min_length=1)
    lesson_count: Optional[int] = Field(default=None, ge=1, le=999)
    description: Optional[str] = None
    is_published: Optional[bool] = None

    @field_validator("exam_category")
    @classmethod
    def validate_exam_category(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return value
        category = try_normalize_exam_category(value)
        if category is None:
            raise ValueError("考试分类不正确")
        return category


class CourseResponse(CourseBase):
    id: int
    created_at: datetime
    chapter_name: Optional[str] = None
    chapter_question_count: int = 0

    class Config:
        from_attributes = True
