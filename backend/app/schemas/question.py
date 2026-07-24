from pydantic import BaseModel, Field, field_validator
from typing import Optional, List, Dict
from datetime import datetime


class ChapterBase(BaseModel):
    name: str
    exam_category: str = "执业资格"
    parent_id: Optional[int] = None
    order: int = 0
    subjects: List[str] = []


class ChapterResponse(ChapterBase):
    id: int

    class Config:
        from_attributes = True


class QuestionBase(BaseModel):
    chapter_id: int
    question_type: str = "single"
    content: str
    options: Dict[str, str]
    answer: str
    explanation: Optional[str] = None
    difficulty: int = 3
    is_real_exam: bool = False
    exam_year: Optional[int] = None
    知识点: List[str] = []


class QuestionCreate(QuestionBase):
    pass


class QuestionUpdate(BaseModel):
    chapter_id: Optional[int] = None
    question_type: Optional[str] = None
    content: Optional[str] = None
    options: Optional[Dict[str, str]] = None
    answer: Optional[str] = None
    explanation: Optional[str] = None
    difficulty: Optional[int] = None
    is_real_exam: Optional[bool] = None
    exam_year: Optional[int] = None
    知识点: Optional[List[str]] = None


class QuestionResponse(QuestionBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


class QuestionSubmit(BaseModel):
    question_id: int
    selected_answer: str = Field(min_length=1, max_length=10)
    time_spent: int = Field(default=0, ge=0, le=86400)

    @field_validator("selected_answer")
    @classmethod
    def normalize_answer(cls, value: str) -> str:
        return value.strip().upper()


class QuestionSubmitResponse(BaseModel):
    is_correct: bool
    correct_answer: str
    explanation: Optional[str]
    wrong_reason: Optional[str] = None


class ExamSession(BaseModel):
    chapter_ids: Optional[List[int]] = None
    question_count: int = 50
    time_limit: int = 3600  # 秒


class ExamAnswer(BaseModel):
    question_id: int
    selected_answer: Optional[str] = None

    @field_validator("selected_answer")
    @classmethod
    def normalize_optional_answer(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        value = value.strip().upper()
        return value or None


class ExamSubmit(BaseModel):
    answers: List[ExamAnswer]
    time_spent: int = Field(default=0, ge=0, le=86400)


class ExamQuestionResult(BaseModel):
    question_id: int
    selected_answer: Optional[str] = None
    correct_answer: str
    is_correct: bool
    explanation: Optional[str] = None
    content: str
    options: Dict[str, str]
    知识点: List[str] = []


class ExamSubmitResponse(BaseModel):
    total_questions: int
    answered_count: int
    unanswered_count: int
    correct_count: int
    wrong_count: int
    score: float
    accuracy_rate: float
    time_spent: int
    wrong_questions: List[ExamQuestionResult]
    results: List[ExamQuestionResult]
