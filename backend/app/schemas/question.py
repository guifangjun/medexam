from pydantic import AliasChoices, BaseModel, ConfigDict, Field, field_validator, model_validator
from typing import Optional, List, Dict, Any
from datetime import datetime


class ChapterBase(BaseModel):
    name: str = Field(min_length=1)
    exam_category: str = "执业资格"
    parent_id: Optional[int] = None
    order: int = 0
    subjects: List[str] = Field(default_factory=list)


class ChapterResponse(ChapterBase):
    id: int

    class Config:
        from_attributes = True


class QuestionBase(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    chapter_id: int
    question_type: str = Field(default="single", pattern="^(single|multi|case)$")
    content: str = Field(min_length=1)
    options: Dict[str, str] = Field(min_length=2)
    answer: str = Field(min_length=1, max_length=10)
    explanation: Optional[str] = None
    difficulty: int = Field(default=3, ge=1, le=5)
    is_real_exam: bool = False
    exam_year: Optional[int] = None
    tags: List[str] = Field(
        default_factory=list,
        validation_alias=AliasChoices("tags", "知识点"),
        serialization_alias="tags",
    )

    @field_validator("answer")
    @classmethod
    def normalize_answer(cls, value: str) -> str:
        return value.strip().upper()

    @field_validator("content")
    @classmethod
    def normalize_content(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("题干不能为空")
        return value

    @field_validator("options")
    @classmethod
    def normalize_options(cls, value: Dict[str, str]) -> Dict[str, str]:
        normalized = {
            key.strip().upper(): option.strip()
            for key, option in value.items()
            if key and option and option.strip()
        }
        if len(normalized) < 2:
            raise ValueError("至少需要 2 个有效选项")
        return normalized

    @model_validator(mode="after")
    def validate_answer_in_options(self):
        answers = [item.strip().upper() for item in self.answer.split(",")]
        invalid = [item for item in answers if item not in self.options]
        if invalid:
            raise ValueError("答案必须匹配选项")
        return self


class QuestionCreate(QuestionBase):
    pass


class QuestionUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    chapter_id: Optional[int] = None
    question_type: Optional[str] = Field(default=None, pattern="^(single|multi|case)$")
    content: Optional[str] = None
    options: Optional[Dict[str, str]] = None
    answer: Optional[str] = Field(default=None, min_length=1, max_length=10)
    explanation: Optional[str] = None
    difficulty: Optional[int] = Field(default=None, ge=1, le=5)
    is_real_exam: Optional[bool] = None
    exam_year: Optional[int] = None
    tags: Optional[List[str]] = Field(
        default=None,
        validation_alias=AliasChoices("tags", "知识点"),
        serialization_alias="tags",
    )

    @field_validator("answer")
    @classmethod
    def normalize_answer(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return value
        return value.strip().upper()

    @field_validator("content")
    @classmethod
    def normalize_content(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return value
        value = value.strip()
        if not value:
            raise ValueError("题干不能为空")
        return value

    @field_validator("options")
    @classmethod
    def normalize_options(cls, value: Optional[Dict[str, str]]) -> Optional[Dict[str, str]]:
        if value is None:
            return value
        normalized = {
            key.strip().upper(): option.strip()
            for key, option in value.items()
            if key and option and option.strip()
        }
        if len(normalized) < 2:
            raise ValueError("至少需要 2 个有效选项")
        return normalized


class QuestionResponse(QuestionBase):
    id: int
    exam_category: Optional[str] = None
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
    chapter_name: Optional[str] = None
    tags: List[str] = Field(
        default_factory=list,
        validation_alias=AliasChoices("tags", "知识点"),
        serialization_alias="tags",
    )


class ExamSubmitResponse(BaseModel):
    id: Optional[int] = None
    attempt_id: Optional[int] = None
    exam_category: Optional[str] = None
    created_at: Optional[datetime] = None
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
    ai_report: Optional[Dict[str, Any]] = None


class ExamAttemptSummary(BaseModel):
    id: int
    exam_category: str
    total_questions: int
    answered_count: int
    correct_count: int
    wrong_count: int
    score: float
    accuracy_rate: float
    time_spent: int
    created_at: datetime

    class Config:
        from_attributes = True
