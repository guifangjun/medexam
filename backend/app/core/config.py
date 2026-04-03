from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    APP_NAME: str = "MedExam AI"
    DEBUG: bool = True

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/medexam"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # JWT
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # AI Model (国产大模型)
    AI_API_KEY: Optional[str] = None
    AI_BASE_URL: Optional[str] = None
    AI_MODEL: str = "glm-4"  # 智谱 GLM-4

    class Config:
        env_file = ".env"


settings = Settings()
