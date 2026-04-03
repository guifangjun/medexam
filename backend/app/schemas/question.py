from pydantic import BaseModel
from typing import Optional, List, Dict
from datetime import datetime


class ChapterBase(BaseModel):
    name: str
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


class QuestionResponse(QuestionBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


class QuestionSubmit(BaseModel):
    question_id: int
    selected_answer: str
    time_spent: int = 0


class QuestionSubmitResponse(BaseModel):
    is_correct: bool
    correct_answer: str
    explanation: Optional[str]
    wrong_reason: Optional[str] = None


class ExamSession(BaseModel):
    chapter_ids: Optional[List[int]] = None
    question_count: int = 50
    time_limit: int = 3600  # 秒


class ExamSubmit(BaseModel):
    answers: List[QuestionSubmit]
    session_id: str
