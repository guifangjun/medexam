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
    question_id: Optional[int] = None
    exam_category: Optional[str] = None
    question_content: str
    question_options: Dict[str, str] = Field(default_factory=dict)
    correct_answer: Optional[str] = None
    selected_answer: Optional[str] = None
    explanation: Optional[str] = None
    tags: List[str] = Field(default_factory=list)


class AICourseCoachRequest(BaseModel):
    exam_category: str
    course_id: Optional[int] = None
    course_title: str
    chapter_name: Optional[str] = None
    description: Optional[str] = None
    lesson_count: int = 1
    completed_lessons: int = 0
    stage: str = "preview"


class AIPracticeReviewRequest(BaseModel):
    exam_category: str
    practice_title: str = "专项练习"
    total_questions: int = 0
    answered_count: int = 0
    correct_count: int = 0
    wrong_count: int = 0
    time_spent: int = 0
    wrong_tags: Dict[str, int] = Field(default_factory=dict)


class AIReasoningEvaluateRequest(BaseModel):
    question_id: Optional[int] = None
    exam_category: str = "执业资格"
    question_content: str
    correct_answer: Optional[str] = None
    selected_answer: Optional[str] = None
    reference_explanation: Optional[str] = None
    learner_reasoning: str = Field(min_length=2, max_length=2000)
    is_correct: bool = False
    tags: List[str] = Field(default_factory=list)


class AIReasoningEvaluationResponse(BaseModel):
    title: str = "AI 费曼复述评测"
    score: int = Field(ge=0, le=100)
    verdict: str
    strengths: List[str] = Field(default_factory=list)
    gaps: List[str] = Field(default_factory=list)
    coaching_questions: List[str] = Field(default_factory=list)
    model_reasoning: str
    next_action: str
    is_demo: bool = False
    session_id: Optional[str] = None
    user_message_id: Optional[int] = None
    assistant_message_id: Optional[int] = None


class AICaseSimulationRequest(BaseModel):
    exam_category: str = "执业资格"
    topic: Optional[str] = Field(default=None, max_length=100)
    difficulty: int = Field(default=2, ge=1, le=3)
    chapter_id: Optional[int] = None


class AICaseSimulationStage(BaseModel):
    index: int
    title: str
    scenario: str
    prompt: str
    options: Dict[str, str] = Field(default_factory=dict)
    best_answer: str
    explanation: str
    hint: str
    knowledge_point: str
    source_question_id: Optional[int] = None


class AICaseSimulationResponse(BaseModel):
    case_id: str
    title: str
    exam_category: str
    topic: str
    difficulty: int
    patient_profile: str
    chief_complaint: str
    learning_objectives: List[str] = Field(default_factory=list)
    stages: List[AICaseSimulationStage] = Field(default_factory=list)
    is_demo: bool = False


class AICaseAnswerItem(BaseModel):
    stage_index: int
    stage_title: str
    selected_answer: str
    best_answer: str
    knowledge_point: str


class AICaseReviewRequest(BaseModel):
    case_id: str
    exam_category: str = "执业资格"
    case_title: str
    topic: str
    answers: List[AICaseAnswerItem] = Field(min_length=1)


class AICaseReviewResponse(BaseModel):
    title: str = "AI 病例推演复盘"
    score: int = Field(ge=0, le=100)
    correct_count: int
    total_stages: int
    summary: str
    wrong_points: List[str] = Field(default_factory=list)
    actions: List[str] = Field(default_factory=list)
    is_demo: bool = False
    session_id: Optional[str] = None
    user_message_id: Optional[int] = None
    assistant_message_id: Optional[int] = None


class AIAdaptivePracticeRequest(BaseModel):
    exam_category: str = "执业资格"
    limit: int = Field(default=10, ge=5, le=30)
    chapter_id: Optional[int] = None
    exclude_question_ids: List[int] = Field(default_factory=list)


class AIAdaptivePracticeResponse(BaseModel):
    title: str = "AI 自适应练习"
    strategy: str
    focus_chapter_id: Optional[int] = None
    focus_chapter_name: str
    target_difficulty: int = Field(ge=1, le=5)
    target_accuracy: int = Field(ge=0, le=100)
    estimated_minutes: int
    question_count: int
    selection_breakdown: Dict[str, int] = Field(default_factory=dict)
    reasons: List[str] = Field(default_factory=list)
    next_adjustment_hint: str
    questions: List[Dict[str, Any]] = Field(default_factory=list)
    is_demo: bool = False
    session_id: Optional[str] = None
    user_message_id: Optional[int] = None
    assistant_message_id: Optional[int] = None


class AIKnowledgeCardGenerateRequest(BaseModel):
    source_message_id: int
    exam_category: Optional[str] = None
    title_hint: Optional[str] = None


class AIKnowledgeCardReviewRequest(BaseModel):
    rating: str = "good"


class AIKnowledgeCardResponse(BaseModel):
    id: int
    exam_category: str
    source_message_id: Optional[int] = None
    related_question_id: Optional[int] = None
    title: str
    front: str
    back: str
    mnemonic: Optional[str] = None
    tags: List[str] = Field(default_factory=list)
    mastery_level: int = 0
    review_count: int = 0
    last_reviewed_at: Optional[datetime] = None
    next_review_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class AIWeaknessInsightsRequest(BaseModel):
    exam_category: str
    period_days: int = Field(default=30, ge=7, le=90)


class AIWeaknessInsightItem(BaseModel):
    chapter_id: int
    chapter_name: str
    recent_questions: int
    previous_questions: int
    recent_accuracy: float
    previous_accuracy: Optional[float] = None
    trend_delta: Optional[float] = None
    trend: str
    wrong_count: int
    status: str
    recommendation: str


class AIWeaknessInsightsResponse(BaseModel):
    title: str
    summary: str
    period_days: int
    total_records: int
    items: List[AIWeaknessInsightItem] = Field(default_factory=list)
    actions: List[str] = Field(default_factory=list)
    is_demo: bool = False
    session_id: Optional[str] = None
    user_message_id: Optional[int] = None
    assistant_message_id: Optional[int] = None


class AIErrorPatternRequest(BaseModel):
    exam_category: str
    period_days: int = Field(default=60, ge=7, le=180)


class AIErrorPatternItem(BaseModel):
    key: str
    name: str
    count: int
    percentage: float
    severity: str
    diagnosis: str
    evidence: List[str] = Field(default_factory=list)
    correction: str
    chapter_id: Optional[int] = None
    chapter_name: Optional[str] = None
    tag: Optional[str] = None
    mode: str = "wrong"
    question_ids: List[int] = Field(default_factory=list)


class AIErrorPatternResponse(BaseModel):
    title: str = "AI 错因雷达"
    summary: str
    exam_category: str
    period_days: int
    total_wrong: int
    analyzed_records: int
    top_pattern: Optional[str] = None
    patterns: List[AIErrorPatternItem] = Field(default_factory=list)
    training_sequence: List[str] = Field(default_factory=list)
    actions: List[str] = Field(default_factory=list)
    is_demo: bool = False
    session_id: Optional[str] = None
    user_message_id: Optional[int] = None
    assistant_message_id: Optional[int] = None


class AISprintPlanRequest(BaseModel):
    exam_category: str = "执业资格"
    exam_date: Optional[datetime] = None
    daily_minutes: int = Field(default=60, ge=20, le=240)
    intensity: str = Field(default="steady", pattern="^(steady|accelerated|sprint)$")


class AISprintPriorityChapter(BaseModel):
    chapter_id: int
    chapter_name: str
    accuracy_rate: Optional[float] = None
    practiced_questions: int = 0
    reason: str


class AISprintPhase(BaseModel):
    name: str
    start_day: int
    end_day: int
    days: int
    focus: str
    daily_actions: List[str] = Field(default_factory=list)
    milestone: str


class AISprintPlanResponse(BaseModel):
    title: str
    summary: str
    exam_category: str
    exam_date: datetime
    days_remaining: int
    daily_minutes: int
    daily_questions: int
    weekly_mock_exams: int
    intensity: str
    priority_chapters: List[AISprintPriorityChapter] = Field(default_factory=list)
    phases: List[AISprintPhase] = Field(default_factory=list)
    daily_schedule: List[str] = Field(default_factory=list)
    today_actions: List[str] = Field(default_factory=list)
    risk_alerts: List[str] = Field(default_factory=list)
    is_demo: bool = False
    session_id: Optional[str] = None
    user_message_id: Optional[int] = None
    assistant_message_id: Optional[int] = None


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
