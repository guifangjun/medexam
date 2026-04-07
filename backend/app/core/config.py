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
    # SiliconFlow (硅基流动) - 免费额度: https://cloud.siliconflow.cn
    # 支持 Qwen (通义千问)、GLM (智谱)、DeepSeek 等模型
    AI_API_KEY: Optional[str] = None
    AI_BASE_URL: Optional[str] = None  # 默认使用 SiliconFlow
    AI_MODEL: str = "Qwen/Qwen2.5-7B-Instruct"  # SiliconFlow 免费模型

    # 可选配置:
    # SiliconFlow 免费模型:
    #   - Qwen/Qwen2.5-7B-Instruct
    #   - THUDM/GLM-4-9B-Chat
    #   - deepseek-ai/DeepSeek-V2.5
    # 智谱 (需要 API Key):
    #   - AI_BASE_URL: https://open.bigmodel.cn/api/paas/v4
    #   - AI_MODEL: glm-4
    # 通义 (需要 API Key):
    #   - AI_BASE_URL: https://dashscope.aliyuncs.com/api/v1
    #   - AI_MODEL: qwen-turbo

    class Config:
        env_file = ".env"


settings = Settings()
