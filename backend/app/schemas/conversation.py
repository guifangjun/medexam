from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class ConversationMessage(BaseModel):
    content: str
    related_question_id: Optional[int] = None


class ConversationResponse(BaseModel):
    id: int
    session_id: str
    message_type: str
    content: str
    related_question_id: Optional[int]
    is_collected: bool
    created_at: datetime

    class Config:
        from_attributes = True


class AIAnswerResponse(BaseModel):
    answer: str
    session_id: str
    related_knowledge_points: List[str] = []
    suggested_questions: List[str] = []


class ConversationSession(BaseModel):
    session_id: str
    messages: List[ConversationResponse]
    created_at: datetime
