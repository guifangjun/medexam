from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime


class ConversationMessage(BaseModel):
    content: str
    session_id: Optional[str] = None
    exam_category: Optional[str] = None
    related_question_id: Optional[int] = None


class ConversationResponse(BaseModel):
    id: int
    session_id: str
    message_type: str
    content: str
    exam_category: Optional[str] = None
    related_question_id: Optional[int]
    is_collected: bool
    created_at: datetime

    class Config:
        from_attributes = True


class AIAnswerResponse(BaseModel):
    answer: str
    session_id: str
    user_message_id: Optional[int] = None
    assistant_message_id: Optional[int] = None
    related_knowledge_points: List[str] = Field(default_factory=list)
    suggested_questions: List[str] = Field(default_factory=list)


class AIStudyAdviceRequest(BaseModel):
    exam_category: str = "执业资格"
    today_stats: Dict[str, Any] = Field(default_factory=dict)
    weak_areas: List[Dict[str, Any]] = Field(default_factory=list)
    wrong_summary: Dict[str, Any] = Field(default_factory=dict)


class AIWrongExplainRequest(BaseModel):
    exam_category: Optional[str] = None
    question_content: str
    question_options: Dict[str, str] = Field(default_factory=dict)
    correct_answer: Optional[str] = None
    selected_answer: Optional[str] = None
    explanation: Optional[str] = None
    tags: List[str] = Field(default_factory=list)


class AIExamReportRequest(BaseModel):
    attempt_id: Optional[int] = None
    exam_category: str = "执业资格"
    total_questions: int
    correct_count: int
    wrong_count: int
    unanswered_count: int = 0
    accuracy_rate: float = 0.0
    time_spent: int = 0
    weak_tags: Dict[str, int] = Field(default_factory=dict)


class AILearningPathRequest(BaseModel):
    exam_category: str = "执业资格"
    today_stats: Dict[str, Any] = Field(default_factory=dict)
    prescription: Dict[str, Any] = Field(default_factory=dict)
    wrong_review: Dict[str, Any] = Field(default_factory=dict)


class AITextResponse(BaseModel):
    title: str
    content: str
    actions: List[str] = Field(default_factory=list)
    is_demo: bool = False
    session_id: Optional[str] = None
    user_message_id: Optional[int] = None
    assistant_message_id: Optional[int] = None


class AILearningPathStep(BaseModel):
    day: str
    title: str
    focus: str
    action: str
    mode: str = "random"
    chapter_id: Optional[int] = None
    tag: Optional[str] = None


class AILearningPathResponse(BaseModel):
    title: str
    summary: str
    today_challenge: str
    reward_title: str = "今日坚持勋章"
    micro_tasks: List[str] = Field(default_factory=list)
    estimated_minutes: int = 20
    steps: List[AILearningPathStep] = Field(default_factory=list)
    actions: List[str] = Field(default_factory=list)
    is_demo: bool = False
    session_id: Optional[str] = None
    user_message_id: Optional[int] = None
    assistant_message_id: Optional[int] = None


class ConversationSession(BaseModel):
    session_id: str
    messages: List[ConversationResponse]
    created_at: datetime
