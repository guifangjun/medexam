from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class WrongQuestionResponse(BaseModel):
    id: int
    question_id: int
    wrong_reason: Optional[str]
    review_count: int
    is_mastered: bool
    next_review_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True


class WrongReasonUpdate(BaseModel):
    wrong_reason: str


class StudyPlanBase(BaseModel):
    title: str
    plan_type: str = "daily"
    target_chapters: List[int] = []
    daily_questions: int = 20
    start_date: datetime
    end_date: datetime


class StudyPlanCreate(StudyPlanBase):
    pass


class StudyPlanResponse(StudyPlanBase):
    id: int
    user_id: int
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class DailyTaskResponse(BaseModel):
    id: int
    date: str
    target_questions: int
    completed_questions: int
    target_chapters: List[int]
    is_completed: bool

    class Config:
        from_attributes = True


class StudyStatsResponse(BaseModel):
    date: str
    total_questions: int
    correct_count: int
    wrong_count: int
    accuracy_rate: float
    time_spent: int
    ai_questions: int


class StatsOverview(BaseModel):
    total_questions: int
    total_correct: int
    overall_accuracy: float
    total_study_time: int
    current_streak: int
    subject_stats: dict
