from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional
import uuid
import re
import httpx

from app.core.database import get_db
from app.core.config import settings
from app.models.user import User
from app.models.conversation import AIConversation, KnowledgePoint
from app.models.question import Question
from app.schemas.conversation import (
    ConversationMessage, AIAnswerResponse, ConversationResponse
)
from app.api.deps import get_current_user

router = APIRouter(prefix="/api/ai", tags=["AI 答疑"])


def strip_thinking(response: str) -> str:
    """去除模型的 think 标签内容"""
    response = re.sub(r"<think>.*?</think>", "", response, flags=re.DOTALL)
    response = re.sub(r"<thinking>.*?</thinking>", "", response, flags=re.DOTALL)
    return response.strip()


async def call_ai_model(messages: list) -> str:
    """调用国产大模型 API"""
    if not settings.AI_API_KEY or settings.AI_API_KEY.startswith("YOUR_"):
        # Demo 模式：返回模拟回答
        return build_demo_response(messages[-1]["content"] if messages else "")

    headers = {
        "Authorization": f"Bearer {settings.AI_API_KEY}",
        "Content-Type": "application/json"
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        try:
            # 确定 API 端点
            if settings.AI_BASE_URL:
                base_url = settings.AI_BASE_URL.rstrip("/")
            elif "zhipu" in settings.AI_MODEL.lower() or "glm" in settings.AI_MODEL.lower():
                base_url = "https://open.bigmodel.cn/api/paas/v4"
            else:
                # 默认使用 SiliconFlow
                base_url = "https://api.siliconflow.cn/v1"

            # 构建请求
            payload = {
                "model": settings.AI_MODEL,
                "messages": messages,
                "stream": False,
                "chat_template_kwargs": {"enable_thinking": False},
            }

            response = await client.post(
                f"{base_url}/chat/completions",
                headers=headers,
                json=payload
            )
            response.raise_for_status()
            resp_json = response.json()
            # MiniMax 响应格式
            if "choices" in resp_json and len(resp_json["choices"]) > 0:
                raw = resp_json["choices"][0]["message"]["content"]
                return strip_thinking(raw)
            # 备用格式
            elif "text" in resp_json:
                return strip_thinking(resp_json["text"])
            else:
                return str(resp_json)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"AI 服务调用失败: {str(e)}")


def build_demo_response(user_question: str) -> str:
    """未配置 API Key 时的演示回复"""
    return f"""⚠️ **AI 未配置** — 当前是演示模式

请配置 AI API Key 后即可使用真实 AI 答疑。

**免费获取 API Key：**
1. 访问 [SiliconFlow 硅基流动](https://cloud.siliconflow.cn) 注册
2. 在账户页面获取免费 API Key
3. 在 `backend/.env` 中配置：
   ```
   AI_API_KEY=你的API_KEY
   AI_BASE_URL=https://api.siliconflow.cn/v1
   AI_MODEL=Qwen/Qwen2.5-7B-Instruct
   ```
4. 重启后端服务

**你发送的问题：** {user_question[:200]}

> 配置完成后，AI 将针对你的问题进行专业医学解答。"""


def build_medical_system_prompt() -> str:
    """构建医学知识系统提示词"""
    return """你是一位专业的医学教育助手，专门帮助医学生备考执业医师/助理医师考试。

你的职责：
1. 回答医学考试相关问题，用通俗易懂的语言解释复杂概念
2. 提供解题思路和知识点回顾
3. 适当拓展相关临床知识，帮助理解
4. 如果学生做错了题，分析错误原因并给出正确理解方式

请注意：
- 回答要准确、权威，参考临床指南和教材
- 适当使用图表或对比帮助理解
- 复杂问题拆解为小问题逐步讲解
- 如果问题超出医学考试范围，可以适当延伸但要说明
"""


@router.post("/chat", response_model=AIAnswerResponse)
async def chat(
    message: ConversationMessage,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """AI 答疑：支持多轮对话"""
    session_id = message.related_question_id or "general"

    # 获取历史对话上下文
    history_result = await db.execute(
        select(AIConversation)
        .where(
            AIConversation.user_id == current_user.id,
            AIConversation.session_id == str(session_id)
        )
        .order_by(AIConversation.created_at.desc())
        .limit(10)
    )
    history = history_result.scalars().all()
    history.reverse()

    # 构建消息列表
    messages = [{"role": "system", "content": build_medical_system_prompt()}]
    for msg in history:
        messages.append({"role": msg.message_type, "content": msg.content})
    messages.append({"role": "user", "content": message.content})

    # 调用 AI
    answer = await call_ai_model(messages)

    # 保存对话
    user_msg = AIConversation(
        user_id=current_user.id,
        session_id=str(session_id),
        message_type="user",
        content=message.content,
        related_question_id=message.related_question_id
    )
    assistant_msg = AIConversation(
        user_id=current_user.id,
        session_id=str(session_id),
        message_type="assistant",
        content=answer,
        related_question_id=message.related_question_id
    )
    db.add(user_msg)
    db.add(assistant_msg)

    # 更新 AI 提问统计
    from app.models.study import StudyStats
    from datetime import datetime
    today = datetime.now().strftime("%Y-%m-%d")
    stats_result = await db.execute(
        select(StudyStats).where(
            StudyStats.user_id == current_user.id,
            StudyStats.date == today
        )
    )
    stats = stats_result.scalar_one_or_none()
    if stats:
        stats.ai_questions += 1
    else:
        stats = StudyStats(
            user_id=current_user.id,
            date=today,
            ai_questions=1
        )
        db.add(stats)

    await db.commit()

    return AIAnswerResponse(
        answer=answer,
        session_id=str(session_id),
        related_knowledge_points=[],
        suggested_questions=[]
    )


@router.get("/history", response_model=List[ConversationResponse])
async def get_conversation_history(
    session_id: str,
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取对话历史"""
    result = await db.execute(
        select(AIConversation)
        .where(
            AIConversation.user_id == current_user.id,
            AIConversation.session_id == session_id
        )
        .order_by(AIConversation.created_at.desc())
        .limit(limit)
    )
    messages = result.scalars().all()
    messages.reverse()
    return messages


@router.get("/sessions", response_model=List[dict])
async def get_conversation_sessions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取所有对话会话列表"""
    result = await db.execute(
        select(AIConversation.session_id, func.count(AIConversation.id).label("count"))
        .where(AIConversation.user_id == current_user.id)
        .group_by(AIConversation.session_id)
        .order_by(func.max(AIConversation.created_at).desc())
    )
    sessions = result.all()
    return [{"session_id": s[0], "message_count": s[1]} for s in sessions]


@router.post("/{message_id}/collect")
async def collect_conversation(
    message_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """收藏对话"""
    result = await db.execute(
        select(AIConversation).where(
            AIConversation.id == message_id,
            AIConversation.user_id == current_user.id
        )
    )
    msg = result.scalar_one_or_none()
    if not msg:
        raise HTTPException(status_code=404, detail="对话不存在")

    msg.is_collected = not msg.is_collected
    await db.commit()
    return {"is_collected": msg.is_collected}


from sqlalchemy import func
