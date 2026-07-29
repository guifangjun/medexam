from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import Integer, func, select
from typing import List, Optional
import asyncio
import uuid
import re
import httpx

from app.core.database import get_db
from app.core.config import settings
from app.core.exam_categories import try_normalize_exam_category
from app.models.user import User
from app.models.conversation import AIConversation, KnowledgePoint
from app.models.question import ExamAttempt, Question
from app.schemas.conversation import (
    ConversationMessage, AIAnswerResponse, ConversationResponse,
    AIStudyAdviceRequest, AIWrongExplainRequest, AIExamReportRequest,
    AILearningPathRequest, AITextResponse, AILearningPathResponse,
    AILearningPathStep,
)
from app.api.deps import get_current_user

router = APIRouter(prefix="/api/ai", tags=["AI 答疑"])
AI_FALLBACK_TIMEOUT_SECONDS = 8.0


async def _increment_ai_question_count(db: AsyncSession, user_id: int) -> None:
    from app.models.study import StudyStats
    from datetime import datetime

    today = datetime.now().strftime("%Y-%m-%d")
    stats_result = await db.execute(
        select(StudyStats).where(
            StudyStats.user_id == user_id,
            StudyStats.date == today,
        )
    )
    stats = stats_result.scalar_one_or_none()
    if stats:
        stats.ai_questions += 1
    else:
        db.add(StudyStats(user_id=user_id, date=today, ai_questions=1))


async def _record_ai_learning_event(
    db: AsyncSession,
    user_id: int,
    session_id: str,
    user_content: str,
    assistant_content: str,
    related_question_id: Optional[int] = None,
    exam_category: Optional[str] = None,
) -> tuple[int, int]:
    user_msg = AIConversation(
        user_id=user_id,
        session_id=session_id,
        message_type="user",
        content=user_content,
        exam_category=exam_category,
        related_question_id=related_question_id,
    )
    assistant_msg = AIConversation(
        user_id=user_id,
        session_id=session_id,
        message_type="assistant",
        content=assistant_content,
        exam_category=exam_category,
        related_question_id=related_question_id,
    )
    db.add(user_msg)
    db.add(assistant_msg)
    await db.flush()
    await _increment_ai_question_count(db, user_id)
    return user_msg.id, assistant_msg.id


def strip_thinking(response: str) -> str:
    """去除模型的 think 标签内容"""
    response = re.sub(r"<think>.*?</think>", "", response, flags=re.DOTALL)
    response = re.sub(r"<thinking>.*?</thinking>", "", response, flags=re.DOTALL)
    return response.strip()


def format_ai_answer_for_app(response: str) -> str:
    """把模型常见 Markdown 输出转成 App 内更易读的纯文本。"""
    response = strip_thinking(response)
    response = re.sub(r"```[\s\S]*?```", "", response)
    response = re.sub(r"`([^`]+)`", r"\1", response)
    response = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", response)
    response = re.sub(r"\*\*([^*]+)\*\*", r"\1", response)
    response = re.sub(r"__([^_]+)__", r"\1", response)
    response = response.replace("**", "").replace("__", "")
    response = re.sub(r"(?m)^\s{0,3}#{1,6}\s*", "", response)
    response = re.sub(r"(?m)^\s*[-*]\s+", "• ", response)
    response = re.sub(r"(?m)^\s*>\s?", "", response)
    response = re.sub(r"\n{3,}", "\n\n", response)
    return response.strip()


async def call_ai_model(messages: list) -> str:
    """调用国产大模型 API"""
    if not settings.AI_API_KEY or settings.AI_API_KEY.startswith("YOUR_"):
        # Demo 模式：返回模拟回答
        return format_ai_answer_for_app(
            build_demo_response(messages[-1]["content"] if messages else "")
        )

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
                return format_ai_answer_for_app(raw)
            # 备用格式
            elif "text" in resp_json:
                return format_ai_answer_for_app(resp_json["text"])
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


async def safe_ai_text(messages: list, fallback: str) -> tuple[str, bool]:
    """AI 专用能力统一兜底：真实模型失败时不阻断学习路径。"""
    try:
        if not settings.AI_API_KEY or settings.AI_API_KEY.startswith("YOUR_"):
            return fallback, True
        return await asyncio.wait_for(
            call_ai_model(messages),
            timeout=AI_FALLBACK_TIMEOUT_SECONDS,
        ), False
    except (Exception, asyncio.TimeoutError):
        return fallback, True


def _options_text(options: dict) -> str:
    return "\n".join([f"{key}. {value}" for key, value in options.items()])


@router.post("/study-advice", response_model=AITextResponse)
async def ai_study_advice(
    payload: AIStudyAdviceRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    category = try_normalize_exam_category(payload.exam_category)
    if category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")
    weak_names = [
        item.get("chapter_name") or item.get("label") or ""
        for item in payload.weak_areas[:3]
    ]
    weak_text = "、".join([name for name in weak_names if name]) or "暂无明显薄弱章节"
    total = payload.today_stats.get("total_questions", 0)
    accuracy = payload.today_stats.get("accuracy_rate", 0)
    fallback = (
        f"今天建议围绕「{category}」做一轮短平快训练：先完成 20 道题，"
        f"再复盘错题。当前已做 {total} 题，正确率约 {round(float(accuracy) * 100)}%。"
        f"优先关注：{weak_text}。"
    )
    content, is_demo = await safe_ai_text(
        [
            {"role": "system", "content": build_medical_system_prompt()},
            {
                "role": "user",
                "content": (
                    "请作为医考备考教练，基于以下学习数据生成今日学习建议。"
                    "要求：中文，120字以内，给出具体行动，不要编造医学事实。\n"
                    f"考试分类：{category}\n"
                    f"今日数据：{payload.today_stats}\n"
                    f"薄弱项：{payload.weak_areas}\n"
                    f"错题摘要：{payload.wrong_summary}"
                ),
            },
        ],
        fallback,
    )
    session_id = f"study-advice-{category}"
    user_message_id, assistant_message_id = await _record_ai_learning_event(
        db,
        current_user.id,
        session_id,
        f"生成{category}今日学习建议",
        content,
        exam_category=category,
    )
    await db.commit()
    return AITextResponse(
        title="AI 今日学习教练",
        content=content,
        actions=["按建议完成一组练习", "复盘今日错题", "完成后查看学习中心数据"],
        is_demo=is_demo,
        session_id=session_id,
        user_message_id=user_message_id,
        assistant_message_id=assistant_message_id,
    )


@router.post("/wrong-explain", response_model=AITextResponse)
async def ai_wrong_explain(
    payload: AIWrongExplainRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    category = try_normalize_exam_category(payload.exam_category)
    if payload.exam_category and category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")
    selected = payload.selected_answer or "未选择"
    correct = payload.correct_answer or "-"
    fallback = (
        f"这道题你的答案是 {selected}，正确答案是 {correct}。"
        f"先抓题干关键词，再对照选项排除干扰项。"
        f"相关知识点：{'、'.join(payload.tags) if payload.tags else '暂未标注'}。"
        f"{'原解析：' + payload.explanation if payload.explanation else ''}"
    )
    content, is_demo = await safe_ai_text(
        [
            {"role": "system", "content": build_medical_system_prompt()},
            {
                "role": "user",
                "content": (
                    "请讲解一道医考错题。要求：分成【错因】【考点】【易混点】【下次怎么做】四段，"
                    "语言通俗，不超过260字。\n"
                    f"题干：{payload.question_content}\n"
                    f"选项：\n{_options_text(payload.question_options)}\n"
                    f"用户答案：{selected}\n正确答案：{correct}\n"
                    f"原解析：{payload.explanation or ''}\n知识点：{payload.tags}"
                ),
            },
        ],
        fallback,
    )
    session_id = f"wrong-explain-{category}" if category else "wrong-explain"
    user_message_id, assistant_message_id = await _record_ai_learning_event(
        db,
        current_user.id,
        session_id,
        f"讲解错题：{payload.question_content[:80]}",
        content,
        exam_category=category,
    )
    await db.commit()
    return AITextResponse(
        title="AI 错题教练",
        content=content,
        actions=["重看题干关键词", "再做一遍同类题", "标注真实错因"],
        is_demo=is_demo,
        session_id=session_id,
        user_message_id=user_message_id,
        assistant_message_id=assistant_message_id,
    )


@router.post("/exam-report", response_model=AITextResponse)
async def ai_exam_report(
    payload: AIExamReportRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    category = try_normalize_exam_category(payload.exam_category)
    if category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")
    attempt = None
    if payload.attempt_id is not None:
        attempt = await db.scalar(
            select(ExamAttempt).where(
                ExamAttempt.id == payload.attempt_id,
                ExamAttempt.user_id == current_user.id,
            )
        )
        if attempt is None:
            raise HTTPException(status_code=404, detail="模考记录不存在")
    accuracy = round(payload.accuracy_rate * 100)
    weak = "、".join(list(payload.weak_tags.keys())[:3]) or "暂无明显集中失分点"
    fallback = (
        f"本次{category}模考正确率 {accuracy}%，错 {payload.wrong_count} 题，"
        f"未答 {payload.unanswered_count} 题。建议先复盘错题，再围绕 {weak} 做专项练习，"
        "下次模考前完成一轮限时训练。"
    )
    content, is_demo = await safe_ai_text(
        [
            {"role": "system", "content": build_medical_system_prompt()},
            {
                "role": "user",
                "content": (
                    "请生成医考模考报告建议。要求：中文，包含分数解读、主要失分原因、三步复习计划，"
                    "不超过300字。\n"
                    f"考试分类：{category}\n"
                    f"总题数：{payload.total_questions}，正确：{payload.correct_count}，"
                    f"错误：{payload.wrong_count}，未答：{payload.unanswered_count}，"
                    f"正确率：{payload.accuracy_rate}，用时：{payload.time_spent}秒\n"
                    f"薄弱知识点：{payload.weak_tags}"
                ),
            },
        ],
        fallback,
    )
    session_id = f"exam-report-{category}"
    user_message_id, assistant_message_id = await _record_ai_learning_event(
        db,
        current_user.id,
        session_id,
        f"生成{category}模考报告：正确{payload.correct_count}/{payload.total_questions}",
        content,
        exam_category=category,
    )
    cached_report = {
        "title": "AI 模考报告",
        "content": content,
        "actions": ["复盘全部错题", "做薄弱知识点专项练习", "安排下一次限时模考"],
        "is_demo": is_demo,
        "session_id": session_id,
        "user_message_id": user_message_id,
        "assistant_message_id": assistant_message_id,
    }
    if attempt is not None:
        report = dict(attempt.report or {})
        report["ai_report"] = cached_report
        attempt.report = report
    await db.commit()
    return AITextResponse(**cached_report)


@router.post("/learning-path", response_model=AILearningPathResponse)
async def ai_learning_path(
    payload: AILearningPathRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """AI 助学路径：把今日数据、薄弱项、错题安排翻译成 7 天行动卡。"""
    category = try_normalize_exam_category(payload.exam_category)
    if category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")
    stats = payload.today_stats or {}
    prescription = payload.prescription or {}
    wrong_review = payload.wrong_review or {}
    completed = int(stats.get("total_questions") or prescription.get("completed_questions") or 0)
    accuracy = float(stats.get("accuracy_rate") or prescription.get("accuracy_rate") or 0)
    target = int(prescription.get("target_questions") or 20)
    weak_areas = prescription.get("weak_areas") or []
    first_weak = weak_areas[0] if weak_areas else {}
    weak_name = first_weak.get("chapter_name") or "高频考点"
    weak_chapter_id = first_weak.get("chapter_id")
    due_wrong = int(wrong_review.get("due_today") or wrong_review.get("overdue") or 0)

    if due_wrong > 0:
        today_challenge = f"先复盘 {min(due_wrong, 10)} 道到期错题，再做 10 道同类题。"
        micro_tasks = ["先做错题二刷", "标注真实错因", "补 10 道同类题"]
        reward_title = "错题止血官"
        first_mode = "wrong"
        first_title = "错题止血"
        first_focus = "把最近失分点先补回来"
    elif completed < target:
        today_challenge = f"完成今日剩余 {max(target - completed, 10)} 道题，做完立刻看解析。"
        micro_tasks = ["开始未做题", "完成今日目标", "复盘新错题"]
        reward_title = "今日任务冲刺者"
        first_mode = prescription.get("recommended_mode") or "unanswered"
        first_title = "补齐今日任务"
        first_focus = "先把学习节奏拉起来"
    elif accuracy < 0.75:
        today_challenge = f"正确率约 {round(accuracy * 100)}%，建议围绕「{weak_name}」做一组专项。"
        micro_tasks = [f"练「{weak_name}」", "整理易混点", "收藏关键解析"]
        reward_title = "薄弱点爆破手"
        first_mode = "chapter" if weak_chapter_id else "random"
        first_title = "薄弱项补强"
        first_focus = weak_name
    else:
        today_challenge = "今天状态不错，做一组随机限时题保持手感。"
        micro_tasks = ["随机限时训练", "检查答题速度", "保持连续学习"]
        reward_title = "稳定输出选手"
        first_mode = "random"
        first_title = "保持手感"
        first_focus = "限时训练"

    steps = [
        AILearningPathStep(
            day="今天",
            title=first_title,
            focus=first_focus,
            action=today_challenge,
            mode=first_mode,
            chapter_id=weak_chapter_id if first_mode == "chapter" else None,
            tag=None,
        ),
        AILearningPathStep(
            day="明天",
            title="错题二刷",
            focus="昨天新增错题",
            action="先遮住答案复述考点，再进入错题复习。",
            mode="wrong",
        ),
        AILearningPathStep(
            day="第 3 天",
            title="章节补漏",
            focus=weak_name,
            action=f"围绕「{weak_name}」做 20 道章节题，错题全部标注错因。",
            mode="chapter" if weak_chapter_id else "random",
            chapter_id=weak_chapter_id,
            tag=None,
        ),
        AILearningPathStep(
            day="第 4 天",
            title="高频考点",
            focus="高频失分点",
            action="做一组高频考点训练，把反复错的知识点加入 AI 学习档案。",
            mode="tag",
            tag=None,
        ),
        AILearningPathStep(
            day="第 5 天",
            title="随机混练",
            focus="综合判断",
            action="随机练习 20 道，重点训练读题速度和排除法。",
            mode="random",
        ),
        AILearningPathStep(
            day="第 6 天",
            title="课程回看",
            focus="题课闭环",
            action="看一节关联课程，再做课后练习验证掌握情况。",
            mode="chapter" if weak_chapter_id else "random",
            chapter_id=weak_chapter_id,
        ),
        AILearningPathStep(
            day="第 7 天",
            title="小模考",
            focus="阶段检验",
            action="完成一次限时模考，查看 AI 模考报告并更新下周计划。",
            mode="random",
        ),
    ]

    fallback_summary = (
        f"我给你排了一个 7 天轻冲刺：先处理当前最影响分数的任务，再用章节、错题、"
        f"高频考点和小模考形成闭环。今日完成度 {completed}/{target}，"
        f"正确率约 {round(accuracy * 100)}%。"
    )
    content, is_demo = await safe_ai_text(
        [
            {"role": "system", "content": build_medical_system_prompt()},
            {
                "role": "user",
                "content": (
                    "请作为医考学习规划教练，基于数据生成一句 7 天学习路径摘要。"
                    "只输出中文摘要，80字以内，具体、鼓励但不要鸡汤。\n"
                    f"考试分类：{category}\n"
                    f"今日数据：{stats}\n学习处方：{prescription}\n错题复盘：{wrong_review}"
                ),
            },
        ],
        fallback_summary,
    )

    session_id = f"learning-path-{category}"
    user_message_id, assistant_message_id = await _record_ai_learning_event(
        db,
        current_user.id,
        session_id,
        f"生成{category}7天学习路径",
        content,
        exam_category=category,
    )
    await db.commit()

    return AILearningPathResponse(
        title="AI 7 天学习路径",
        summary=content,
        today_challenge=today_challenge,
        reward_title=reward_title,
        micro_tasks=micro_tasks,
        estimated_minutes=max(15, min(60, round((target - completed if completed < target else 20) * 0.7))),
        steps=steps,
        actions=["开始今日挑战", "复习错题", "查看课程闭环"],
        is_demo=is_demo,
        session_id=session_id,
        user_message_id=user_message_id,
        assistant_message_id=assistant_message_id,
    )


@router.post("/chat", response_model=AIAnswerResponse)
async def chat(
    message: ConversationMessage,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """AI 答疑：支持多轮对话"""
    category = try_normalize_exam_category(message.exam_category)
    if message.exam_category and category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")
    session_id = (
        message.session_id
        or (f"question-{message.related_question_id}" if message.related_question_id else None)
        or f"chat-{uuid.uuid4()}"
    )

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

    fallback = format_ai_answer_for_app(build_demo_response(message.content))
    answer, _ = await safe_ai_text(messages, fallback)

    user_message_id, assistant_message_id = await _record_ai_learning_event(
        db,
        current_user.id,
        str(session_id),
        message.content,
        answer,
        related_question_id=message.related_question_id,
        exam_category=category,
    )

    await db.commit()

    return AIAnswerResponse(
        answer=answer,
        session_id=str(session_id),
        user_message_id=user_message_id,
        assistant_message_id=assistant_message_id,
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
        .order_by(AIConversation.created_at.desc(), AIConversation.id.desc())
        .limit(limit)
    )
    messages = result.scalars().all()
    messages.reverse()
    return messages


@router.get("/sessions", response_model=List[dict])
async def get_conversation_sessions(
    exam_category: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取所有对话会话列表"""
    filters = [AIConversation.user_id == current_user.id]
    if exam_category:
        category = try_normalize_exam_category(exam_category)
        if category is None:
            return []
        filters.append(AIConversation.exam_category == category)
    result = await db.execute(
        select(
            AIConversation.session_id,
            func.count(AIConversation.id).label("count"),
            func.max(AIConversation.created_at).label("last_message_at"),
            func.max(AIConversation.exam_category).label("exam_category"),
            func.sum(func.cast(AIConversation.is_collected, Integer)).label("collected_count"),
        )
        .where(*filters)
        .group_by(AIConversation.session_id)
        .order_by(func.max(AIConversation.created_at).desc())
    )
    sessions = result.all()
    summaries = []
    for session_id, count, last_message_at, exam_category, collected_count in sessions:
        first_user = await db.execute(
            select(AIConversation.content)
            .where(
                AIConversation.user_id == current_user.id,
                AIConversation.session_id == session_id,
                AIConversation.message_type == "user",
            )
            .order_by(AIConversation.created_at.asc())
            .limit(1)
        )
        title = first_user.scalar_one_or_none() or "新对话"
        summaries.append(
            {
                "session_id": session_id,
                "message_count": count,
                "title": title[:40],
                "exam_category": exam_category,
                "last_message_at": last_message_at,
                "collected_count": collected_count or 0,
            }
        )
    return summaries


@router.get("/collections", response_model=List[ConversationResponse])
async def get_collected_conversations(
    limit: int = 50,
    exam_category: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """获取已收藏的 AI 回复"""
    filters = [
        AIConversation.user_id == current_user.id,
        AIConversation.is_collected == True,
    ]
    if exam_category:
        category = try_normalize_exam_category(exam_category)
        if category is None:
            return []
        filters.append(AIConversation.exam_category == category)
    result = await db.execute(
        select(AIConversation)
        .where(*filters)
        .order_by(AIConversation.created_at.desc())
        .limit(limit)
    )
    return result.scalars().all()


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
    if msg.message_type != "assistant":
        raise HTTPException(status_code=400, detail="只能收藏 AI 回复")

    msg.is_collected = not msg.is_collected
    await db.commit()
    return {"is_collected": msg.is_collected}
