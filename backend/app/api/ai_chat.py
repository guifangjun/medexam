from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import Integer, func, or_, select
from typing import List, Optional
import asyncio
import json
import uuid
import re
import httpx
from datetime import datetime, timedelta

from app.core.database import get_db
from app.core.config import settings
from app.core.exam_categories import try_normalize_exam_category
from app.models.user import User
from app.models.conversation import AIConversation, AIKnowledgeCard, KnowledgePoint
from app.models.question import Chapter, ExamAttempt, Question, QuestionRecord
from app.models.study import WrongQuestion
from app.schemas.conversation import (
    ConversationMessage, AIAnswerResponse, ConversationResponse,
    AIStudyAdviceRequest, AIWrongExplainRequest, AICourseCoachRequest,
    AIPracticeReviewRequest,
    AIReasoningEvaluateRequest, AIReasoningEvaluationResponse,
    AICaseSimulationRequest, AICaseSimulationStage,
    AICaseSimulationResponse, AICaseReviewRequest, AICaseReviewResponse,
    AIAdaptivePracticeRequest, AIAdaptivePracticeResponse,
    AIKnowledgeCardGenerateRequest, AIKnowledgeCardReviewRequest,
    AIKnowledgeCardResponse,
    AIWeaknessInsightsRequest, AIWeaknessInsightItem,
    AIWeaknessInsightsResponse,
    AIErrorPatternRequest, AIErrorPatternItem, AIErrorPatternResponse,
    AISprintPlanRequest, AISprintPriorityChapter, AISprintPhase,
    AISprintPlanResponse,
    AIExamReportRequest,
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
    response = re.sub(r"```(?:json|markdown|text)?\s*", "", response, flags=re.I)
    response = response.replace("```", "")
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
    is_correct = selected != "未选择" and selected.upper() == correct.upper()
    fallback = (
        f"这道题你的答案是 {selected}，正确答案是 {correct}。"
        f"{'答对后也要确认判断依据是否稳定。' if is_correct else '先抓题干关键词，再对照选项排除干扰项。'}"
        f"相关知识点：{'、'.join(payload.tags) if payload.tags else '暂未标注'}。"
        f"{'原解析：' + payload.explanation if payload.explanation else ''}"
    )
    content, is_demo = await safe_ai_text(
        [
            {"role": "system", "content": build_medical_system_prompt()},
            {
                "role": "user",
                "content": (
                    "请讲解一道医考题。要求：分成【判断依据】【核心考点】【易混点】【下次怎么做】四段，"
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
        f"讲解题目：{payload.question_content[:80]}",
        content,
        related_question_id=payload.question_id,
        exam_category=category,
    )
    await db.commit()
    return AITextResponse(
        title="AI 题目教练" if is_correct else "AI 错题教练",
        content=content,
        actions=(
            ["复述判断依据", "辨析相近选项", "继续下一题"]
            if is_correct
            else ["重看题干关键词", "再做一遍同类题", "标注真实错因"]
        ),
        is_demo=is_demo,
        session_id=session_id,
        user_message_id=user_message_id,
        assistant_message_id=assistant_message_id,
    )


def _knowledge_card_json(raw: str, fallback: dict) -> dict:
    candidates = [raw.strip()]
    match = re.search(r"\{[\s\S]*\}", raw)
    if match:
        candidates.append(match.group(0))
    for candidate in candidates:
        try:
            parsed = json.loads(candidate)
            if isinstance(parsed, dict):
                return parsed
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
    return fallback


def _string_list(value, fallback: list[str], limit: int = 4) -> list[str]:
    if not isinstance(value, list):
        return fallback
    items = [str(item).strip() for item in value if str(item).strip()]
    return items[:limit] or fallback


@router.post(
    "/reasoning-evaluate",
    response_model=AIReasoningEvaluationResponse,
)
async def ai_reasoning_evaluate(
    payload: AIReasoningEvaluateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """用主动复述检验理解，避免把“看懂解析”误当成真正掌握。"""
    category = try_normalize_exam_category(payload.exam_category)
    if category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")

    reasoning = payload.learner_reasoning.strip()
    if len(reasoning) < 2:
        raise HTTPException(status_code=422, detail="请先写下你的判断过程")
    explanation = (payload.reference_explanation or "").strip()
    has_reasoning_detail = len(reasoning) >= 35
    fallback_score = 82 if payload.is_correct else 58
    if has_reasoning_detail:
        fallback_score += 8
    elif len(reasoning) < 12:
        fallback_score -= 12
    fallback_score = max(20, min(95, fallback_score))
    focus = payload.tags[0] if payload.tags else "本题核心考点"
    fallback = {
        "score": fallback_score,
        "verdict": (
            "判断方向正确，已经能用自己的话说明主要依据。"
            if payload.is_correct
            else "已经开始形成推理链，但关键判断依据还需要补齐。"
        ),
        "strengths": [
            "愿意先输出自己的判断过程，而不是只看解析",
            (
                "结论与正确答案一致"
                if payload.is_correct
                else "能够暴露真实理解缺口，便于针对性纠正"
            ),
        ],
        "gaps": [
            f"需要把“{focus}”对应的题干证据说得更具体",
            "补充为什么其他选项不符合，形成完整的排除链",
        ],
        "coaching_questions": [
            "题干中哪个关键词最能支持正确答案？",
            "如果删除这个关键词，你的结论会发生什么变化？",
        ],
        "model_reasoning": explanation or (
            f"先定位题干中的关键条件，再核对正确答案 {payload.correct_answer or '所对应选项'}"
            "的适用范围，最后逐项排除与条件不符的干扰项。"
        ),
        "next_action": "合上解析，用 30 秒重新讲一遍“关键词—结论—排除依据”。",
    }
    fallback_text = json.dumps(fallback, ensure_ascii=False)
    generated, is_demo = await safe_ai_text(
        [
            {"role": "system", "content": build_medical_system_prompt()},
            {
                "role": "user",
                "content": (
                    "你是医考主动学习教练。请评估学员对一道题的费曼复述，"
                    "重点判断是否说清题干证据、核心机制和干扰项边界。"
                    "只输出严格 JSON，不要 Markdown，字段必须是 score(0-100整数)、"
                    "verdict、strengths、gaps、coaching_questions、model_reasoning、next_action。"
                    "不要仅因结论正确就给高分；医学表述错误必须明确指出，"
                    "但不要虚构题目之外的诊疗建议。\n"
                    f"考试分类：{category}\n"
                    f"题目：{payload.question_content}\n"
                    f"正确答案：{payload.correct_answer or '未提供'}\n"
                    f"学员选择：{payload.selected_answer or '未提供'}\n"
                    f"参考解析：{explanation or '未提供'}\n"
                    f"知识点：{', '.join(payload.tags[:5]) or '未提供'}\n"
                    f"学员复述：{reasoning}"
                ),
            },
        ],
        fallback_text,
    )
    data = _knowledge_card_json(generated, fallback)
    try:
        score = int(round(float(data.get("score", fallback_score))))
    except (TypeError, ValueError):
        score = fallback_score
    score = max(0, min(100, score))
    strengths = _string_list(data.get("strengths"), fallback["strengths"])
    gaps = _string_list(data.get("gaps"), fallback["gaps"])
    coaching_questions = _string_list(
        data.get("coaching_questions"),
        fallback["coaching_questions"],
        limit=3,
    )
    verdict = str(data.get("verdict") or fallback["verdict"])[:500]
    model_reasoning = str(
        data.get("model_reasoning") or fallback["model_reasoning"]
    )[:2000]
    next_action = str(data.get("next_action") or fallback["next_action"])[:500]
    session_id = f"reasoning-{current_user.id}-{uuid.uuid4().hex[:12]}"
    assistant_content = (
        f"AI 费曼复述评测｜{score}分\n\n"
        f"{verdict}\n\n"
        f"理解缺口：{'；'.join(gaps)}\n\n"
        f"参考推理：{model_reasoning}\n\n"
        f"下一步：{next_action}"
    )
    user_message_id, assistant_message_id = await _record_ai_learning_event(
        db,
        current_user.id,
        session_id,
        f"我对这道题的复述：{reasoning}",
        assistant_content,
        related_question_id=payload.question_id,
        exam_category=category,
    )
    await db.commit()
    return AIReasoningEvaluationResponse(
        score=score,
        verdict=verdict,
        strengths=strengths,
        gaps=gaps,
        coaching_questions=coaching_questions,
        model_reasoning=model_reasoning,
        next_action=next_action,
        is_demo=is_demo,
        session_id=session_id,
        user_message_id=user_message_id,
        assistant_message_id=assistant_message_id,
    )


def _case_stage_from_question(
    question: Question,
    chapter: Chapter,
    index: int,
) -> dict:
    tags = list(getattr(question, "知识点", None) or [])
    knowledge_point = tags[0] if tags else chapter.name
    step_names = ["捕捉关键证据", "形成诊断判断", "完成鉴别与处置"]
    return {
        "index": index,
        "title": f"第 {index + 1} 步 · {step_names[min(index, 2)]}",
        "scenario": question.content,
        "prompt": "结合当前信息，选择最合理的判断。",
        "options": dict(question.options or {}),
        "best_answer": str(question.answer or "").strip().upper(),
        "explanation": question.explanation or "先定位题干证据，再核对选项适用边界。",
        "hint": f"先找与“{knowledge_point}”直接相关的阳性或排除性证据。",
        "knowledge_point": knowledge_point,
        "source_question_id": question.id,
    }


def _normalize_case_stage(raw: dict, fallback: dict, index: int) -> dict:
    if not isinstance(raw, dict):
        raw = {}
    options = raw.get("options")
    if not isinstance(options, dict) or len(options) < 2:
        options = fallback["options"]
    options = {
        str(key).strip().upper(): str(value).strip()
        for key, value in options.items()
        if str(key).strip() and str(value).strip()
    }
    best_answer = str(raw.get("best_answer") or fallback["best_answer"]).strip().upper()
    if best_answer not in options:
        best_answer = fallback["best_answer"]
        options = fallback["options"]
    return {
        "index": index,
        "title": str(raw.get("title") or fallback["title"])[:160],
        "scenario": str(raw.get("scenario") or fallback["scenario"])[:2500],
        "prompt": str(raw.get("prompt") or fallback["prompt"])[:500],
        "options": options,
        "best_answer": best_answer,
        "explanation": str(raw.get("explanation") or fallback["explanation"])[:2000],
        "hint": str(raw.get("hint") or fallback["hint"])[:500],
        "knowledge_point": str(
            raw.get("knowledge_point") or fallback["knowledge_point"]
        )[:120],
        "source_question_id": fallback.get("source_question_id"),
    }


@router.post(
    "/case-simulation/generate",
    response_model=AICaseSimulationResponse,
)
async def generate_case_simulation(
    payload: AICaseSimulationRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """基于当前考试科目题库生成三阶段临床思维推演。"""
    category = try_normalize_exam_category(payload.exam_category)
    if category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")

    base_filters = [
        Chapter.exam_category == category,
        Question.question_type == "single",
    ]
    topic = (payload.topic or "").strip()
    topic_filter = None
    if topic:
        topic_filter = or_(
            Chapter.name.contains(topic),
            Question.content.contains(topic),
        )
    difficulty_filter = None
    if payload.difficulty == 1:
        difficulty_filter = Question.difficulty <= 2
    elif payload.difficulty == 2:
        difficulty_filter = Question.difficulty.between(2, 4)
    else:
        difficulty_filter = Question.difficulty >= 4

    async def load_rows(
        include_topic: bool,
        include_difficulty: bool,
        include_chapter: bool = True,
    ):
        filters = list(base_filters)
        if include_chapter and payload.chapter_id is not None:
            filters.append(Chapter.id == payload.chapter_id)
        if include_topic and topic_filter is not None:
            filters.append(topic_filter)
        if include_difficulty and difficulty_filter is not None:
            filters.append(difficulty_filter)
        result = await db.execute(
            select(Question, Chapter)
            .join(Chapter, Chapter.id == Question.chapter_id)
            .where(*filters)
            .order_by(func.random())
            .limit(6)
        )
        return result.all()

    rows = await load_rows(include_topic=True, include_difficulty=True)
    if len(rows) < 3:
        rows = await load_rows(include_topic=True, include_difficulty=False)
    if len(rows) < 3 and topic:
        rows = await load_rows(include_topic=False, include_difficulty=False)
    if len(rows) < 3 and payload.chapter_id is not None:
        rows = await load_rows(
            include_topic=False,
            include_difficulty=False,
            include_chapter=False,
        )
    if len(rows) < 3:
        raise HTTPException(
            status_code=404,
            detail="当前考试分类题量不足，至少需要 3 道单选题才能生成病例推演",
        )

    selected_rows = rows[:3]
    fallback_stages = [
        _case_stage_from_question(question, chapter, index)
        for index, (question, chapter) in enumerate(selected_rows)
    ]
    selected_chapter = selected_rows[0][1]
    resolved_topic = topic or selected_chapter.name
    objectives = []
    for stage in fallback_stages:
        if stage["knowledge_point"] not in objectives:
            objectives.append(stage["knowledge_point"])
    fallback = {
        "title": f"{resolved_topic} · AI 临床思维推演",
        "patient_profile": (
            f"当前为 {category} 的 {resolved_topic} 训练。AI 将分三步释放信息，"
            "请先独立判断，再查看解析。"
        ),
        "chief_complaint": fallback_stages[0]["scenario"],
        "learning_objectives": objectives[:4],
        "stages": fallback_stages,
    }
    reference_questions = [
        {
            "content": question.content,
            "options": question.options,
            "answer": question.answer,
            "explanation": question.explanation,
            "chapter": chapter.name,
            "tags": list(getattr(question, "知识点", None) or []),
        }
        for question, chapter in selected_rows
    ]
    generated, is_demo = await safe_ai_text(
        [
            {"role": "system", "content": build_medical_system_prompt()},
            {
                "role": "user",
                "content": (
                    "请基于给定题库资料生成一个连贯、适合医考训练的三阶段病例推演。"
                    "只输出严格 JSON，不要 Markdown。顶层字段必须是 title、patient_profile、"
                    "chief_complaint、learning_objectives、stages；stages 必须恰好3项，"
                    "每项字段为 title、scenario、prompt、options、best_answer、explanation、"
                    "hint、knowledge_point。options 为 A-D 字典，best_answer 必须是其中一个键。"
                    "三阶段依次训练信息提取、诊断/辨证、鉴别或处置。"
                    "只能使用参考题中的医学依据，不得编造药物剂量或超纲诊疗建议。\n"
                    f"考试分类：{category}\n训练主题：{resolved_topic}\n"
                    f"难度：{payload.difficulty}/3\n"
                    f"参考题库：{json.dumps(reference_questions, ensure_ascii=False)}"
                ),
            },
        ],
        json.dumps(fallback, ensure_ascii=False),
    )
    data = _knowledge_card_json(generated, fallback)
    raw_stages = data.get("stages")
    valid_generated_stages = isinstance(raw_stages, list) and len(raw_stages) == 3
    if not valid_generated_stages:
        raw_stages = fallback_stages
        is_demo = True
    stages = [
        _normalize_case_stage(raw_stages[index], fallback_stages[index], index)
        for index in range(3)
    ]
    learning_objectives = _string_list(
        data.get("learning_objectives"),
        fallback["learning_objectives"],
        limit=5,
    )
    return AICaseSimulationResponse(
        case_id=f"case-{current_user.id}-{uuid.uuid4().hex[:12]}",
        title=str(data.get("title") or fallback["title"])[:180],
        exam_category=category,
        topic=resolved_topic,
        difficulty=payload.difficulty,
        patient_profile=str(
            data.get("patient_profile") or fallback["patient_profile"]
        )[:1500],
        chief_complaint=str(
            data.get("chief_complaint") or fallback["chief_complaint"]
        )[:1500],
        learning_objectives=learning_objectives,
        stages=[AICaseSimulationStage(**stage) for stage in stages],
        is_demo=is_demo,
    )


def _normalized_answer(value: str) -> str:
    return ",".join(
        sorted(
            item.strip().upper()
            for item in str(value or "").replace("，", ",").split(",")
            if item.strip()
        )
    )


@router.post(
    "/case-simulation/review",
    response_model=AICaseReviewResponse,
)
async def review_case_simulation(
    payload: AICaseReviewRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    category = try_normalize_exam_category(payload.exam_category)
    if category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")
    total = len(payload.answers)
    correct_count = sum(
        1
        for answer in payload.answers
        if _normalized_answer(answer.selected_answer)
        == _normalized_answer(answer.best_answer)
    )
    score = int(round(correct_count / total * 100))
    wrong_points = []
    for answer in payload.answers:
        if (
            _normalized_answer(answer.selected_answer)
            != _normalized_answer(answer.best_answer)
            and answer.knowledge_point not in wrong_points
        ):
            wrong_points.append(answer.knowledge_point)
    if score >= 85:
        fallback_summary = (
            "三阶段判断整体连贯，能够从题干证据推进到结论。下一步应提高难度，"
            "并尝试在不看选项时先口述诊断依据。"
        )
        actions = ["挑战高难病例", "口述完整推理链", "复习易混鉴别点"]
    elif score >= 60:
        fallback_summary = (
            "已经建立基本临床思维链，但部分阶段仍依赖选项提示。"
            "建议回看错误阶段的关键证据，并立即完成一组同知识点练习。"
        )
        actions = ["重做错误阶段", "补充题干证据", "完成同类题训练"]
    else:
        fallback_summary = (
            "当前推理链存在明显断点。先不要追求速度，按“关键词—机制—结论—排除”"
            "四步重新复述，再回到题库巩固基础考点。"
        )
        actions = ["重学薄弱考点", "把错因制成记忆卡", "完成基础章节练习"]
    answer_summary = [
        {
            "stage": answer.stage_title,
            "selected": answer.selected_answer,
            "best": answer.best_answer,
            "knowledge_point": answer.knowledge_point,
        }
        for answer in payload.answers
    ]
    summary, is_demo = await safe_ai_text(
        [
            {"role": "system", "content": build_medical_system_prompt()},
            {
                "role": "user",
                "content": (
                    "请为这次医考病例推演生成简洁、可执行的学习复盘。"
                    "先总结推理表现，再指出最需要补的临床思维环节，最后给出今天能完成的动作。"
                    "不要使用 Markdown，不要给出脱离考试资料的临床诊疗建议。\n"
                    f"考试分类：{category}\n病例：{payload.case_title}\n"
                    f"主题：{payload.topic}\n得分：{score}\n"
                    f"答题明细：{json.dumps(answer_summary, ensure_ascii=False)}"
                ),
            },
        ],
        fallback_summary,
    )
    session_id = f"case-review-{current_user.id}-{uuid.uuid4().hex[:12]}"
    assistant_content = (
        f"AI 病例推演复盘｜{score}分\n\n{summary}\n\n"
        f"薄弱点：{'、'.join(wrong_points) if wrong_points else '本次三阶段均判断正确'}\n\n"
        f"下一步：{'；'.join(actions)}"
    )
    user_message_id, assistant_message_id = await _record_ai_learning_event(
        db,
        current_user.id,
        session_id,
        f"完成病例推演：{payload.case_title}（{correct_count}/{total}）",
        assistant_content,
        exam_category=category,
    )
    await db.commit()
    return AICaseReviewResponse(
        score=score,
        correct_count=correct_count,
        total_stages=total,
        summary=summary,
        wrong_points=wrong_points,
        actions=actions,
        is_demo=is_demo,
        session_id=session_id,
        user_message_id=user_message_id,
        assistant_message_id=assistant_message_id,
    )


def _adaptive_question_payload(question: Question, chapter: Chapter) -> dict:
    return {
        "id": question.id,
        "chapter_id": question.chapter_id,
        "exam_category": chapter.exam_category,
        "question_type": question.question_type,
        "content": question.content,
        "options": question.options or {},
        "answer": question.answer,
        "explanation": question.explanation,
        "difficulty": question.difficulty,
        "is_real_exam": question.is_real_exam,
        "exam_year": question.exam_year,
        "tags": list(getattr(question, "知识点", None) or []),
        "created_at": question.created_at,
    }


@router.post(
    "/adaptive-practice",
    response_model=AIAdaptivePracticeResponse,
)
async def generate_adaptive_practice(
    payload: AIAdaptivePracticeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """根据历史正确率、薄弱章节、题目难度和覆盖度生成下一组练习。"""
    category = try_normalize_exam_category(payload.exam_category)
    if category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")

    pool_result = await db.execute(
        select(Question, Chapter)
        .join(Chapter, Chapter.id == Question.chapter_id)
        .where(
            Chapter.exam_category == category,
            *(
                [Chapter.id == payload.chapter_id]
                if payload.chapter_id is not None
                else []
            ),
        )
    )
    pool_rows = pool_result.all()
    if not pool_rows:
        raise HTTPException(status_code=404, detail="当前考试分类暂无可用题目")

    history_result = await db.execute(
        select(QuestionRecord, Question, Chapter)
        .join(Question, Question.id == QuestionRecord.question_id)
        .join(Chapter, Chapter.id == Question.chapter_id)
        .where(
            QuestionRecord.user_id == current_user.id,
            Chapter.exam_category == category,
        )
        .order_by(QuestionRecord.created_at.desc(), QuestionRecord.id.desc())
        .limit(500)
    )
    history_rows = history_result.all()
    total_records = len(history_rows)
    correct_records = sum(1 for record, _, _ in history_rows if record.is_correct)
    accuracy = correct_records / total_records if total_records else None
    if accuracy is None:
        target_difficulty = 2
    elif accuracy < 0.5:
        target_difficulty = 2
    elif accuracy < 0.7:
        target_difficulty = 3
    elif accuracy < 0.85:
        target_difficulty = 4
    else:
        target_difficulty = 5

    chapter_stats: dict[int, dict] = {}
    question_stats: dict[int, dict] = {}
    weak_tag_counts: dict[str, int] = {}
    for record, question, chapter in history_rows:
        chapter_item = chapter_stats.setdefault(
            chapter.id,
            {"name": chapter.name, "total": 0, "correct": 0},
        )
        chapter_item["total"] += 1
        chapter_item["correct"] += int(bool(record.is_correct))
        question_item = question_stats.setdefault(
            question.id,
            {
                "attempts": 0,
                "correct": 0,
                "latest_correct": bool(record.is_correct),
                "last_seen": record.created_at,
            },
        )
        question_item["attempts"] += 1
        question_item["correct"] += int(bool(record.is_correct))
        if not record.is_correct:
            for tag in list(getattr(question, "知识点", None) or []):
                if tag:
                    weak_tag_counts[tag] = weak_tag_counts.get(tag, 0) + 1

    focus_chapter_id = payload.chapter_id
    focus_chapter_name = "全科综合"
    if focus_chapter_id is not None:
        focus_chapter = next(
            (chapter for _, chapter in pool_rows if chapter.id == focus_chapter_id),
            None,
        )
        if focus_chapter is None:
            raise HTTPException(status_code=404, detail="指定章节不属于当前考试分类")
        focus_chapter_name = focus_chapter.name
    elif chapter_stats:
        focus_chapter_id, weakest = min(
            chapter_stats.items(),
            key=lambda item: (
                item[1]["correct"] / item[1]["total"],
                -item[1]["total"],
                item[0],
            ),
        )
        focus_chapter_name = weakest["name"]

    excluded_ids = set(payload.exclude_question_ids)
    now = datetime.now()

    def candidate_score(row) -> tuple[float, int]:
        question, chapter = row
        stats = question_stats.get(question.id)
        score = 0.0
        if stats is None:
            score += 100
        else:
            question_accuracy = stats["correct"] / stats["attempts"]
            score += (1 - question_accuracy) * 55
            if not stats["latest_correct"]:
                score += 35
            if stats["last_seen"] is not None:
                age_days = max(0, (now - stats["last_seen"]).days)
                if age_days == 0:
                    score -= 35
                elif age_days <= 3:
                    score -= 15
                elif age_days >= 14:
                    score += 12
        if focus_chapter_id is not None and chapter.id == focus_chapter_id:
            score += 60
        score += max(0, 30 - abs(question.difficulty - target_difficulty) * 12)
        for tag in list(getattr(question, "知识点", None) or []):
            score += min(weak_tag_counts.get(tag, 0) * 7, 28)
        if question.id in excluded_ids:
            score -= 200
        return score, -question.id

    ranked = sorted(pool_rows, key=candidate_score, reverse=True)
    available = [row for row in ranked if row[0].id not in excluded_ids]
    if len(available) < payload.limit:
        available.extend(row for row in ranked if row[0].id in excluded_ids)

    selected_rows = []
    if focus_chapter_id is not None:
        focus_quota = max(1, round(payload.limit * 0.7))
        selected_rows.extend(
            row for row in available if row[1].id == focus_chapter_id
        )
        selected_rows = selected_rows[:focus_quota]
    selected_ids = {question.id for question, _ in selected_rows}
    for row in available:
        if row[0].id in selected_ids:
            continue
        selected_rows.append(row)
        selected_ids.add(row[0].id)
        if len(selected_rows) >= payload.limit:
            break
    selected_rows = selected_rows[: payload.limit]
    if not selected_rows:
        raise HTTPException(status_code=404, detail="暂时没有可生成的自适应题组")

    unseen_count = sum(
        1 for question, _ in selected_rows if question.id not in question_stats
    )
    weak_count = sum(
        1
        for question, _ in selected_rows
        if question.id in question_stats
        and question_stats[question.id]["correct"]
        < question_stats[question.id]["attempts"]
    )
    review_count = len(selected_rows) - unseen_count - weak_count
    if accuracy is None:
        reasons = [
            "当前历史数据较少，先用中等难度建立能力基线",
            f"优先安排 {unseen_count} 道未做题，扩大知识覆盖面",
            "完成后将根据首轮正确率自动调整下一组难度",
        ]
    else:
        reasons = [
            f"近期累计正确率约 {round(accuracy * 100)}%，目标难度调整为 {target_difficulty}/5",
            f"重点补强「{focus_chapter_name}」，同时保留少量跨章节迁移题",
            f"本组包含 {unseen_count} 道未做题、{weak_count} 道薄弱回测题",
        ]
    target_accuracy = 75 if target_difficulty <= 3 else 70
    fallback_strategy = (
        f"本组聚焦「{focus_chapter_name}」，难度设为 {target_difficulty}/5。"
        f"先完成 {unseen_count} 道知识覆盖题，再用 {weak_count} 道薄弱回测题检查是否真正掌握。"
        "不要追求做得快，优先把每题的判断依据说清楚。"
    )
    strategy, is_demo = await safe_ai_text(
        [
            {"role": "system", "content": build_medical_system_prompt()},
            {
                "role": "user",
                "content": (
                    "请根据学习数据，为医考学员解释这一组自适应练习为什么这样选。"
                    "用三到四句中文，说明薄弱点、目标难度、做题策略和完成后的调整标准。"
                    "不要使用 Markdown，不要夸大 AI 能力。\n"
                    f"考试分类：{category}\n历史题量：{total_records}\n"
                    f"历史正确率：{round((accuracy or 0) * 100)}%\n"
                    f"聚焦章节：{focus_chapter_name}\n目标难度：{target_difficulty}/5\n"
                    f"题组构成：未做{unseen_count}、薄弱回测{weak_count}、间隔复习{review_count}"
                ),
            },
        ],
        fallback_strategy,
    )
    next_adjustment_hint = (
        f"本组达到 {target_accuracy}% 后，下一组将提高难度或扩大章节范围；"
        "低于目标则降低难度并增加错题同类训练。"
    )
    session_id = f"adaptive-{current_user.id}-{uuid.uuid4().hex[:12]}"
    assistant_content = (
        f"AI 自适应练习方案\n\n{strategy}\n\n"
        f"选题原因：{'；'.join(reasons)}\n\n{next_adjustment_hint}"
    )
    user_message_id, assistant_message_id = await _record_ai_learning_event(
        db,
        current_user.id,
        session_id,
        f"为 {category} 生成下一组自适应练习",
        assistant_content,
        exam_category=category,
    )
    await db.commit()
    return AIAdaptivePracticeResponse(
        title=f"AI 自适应训练 · {focus_chapter_name}",
        strategy=strategy,
        focus_chapter_id=focus_chapter_id,
        focus_chapter_name=focus_chapter_name,
        target_difficulty=target_difficulty,
        target_accuracy=target_accuracy,
        estimated_minutes=max(5, round(len(selected_rows) * 1.5)),
        question_count=len(selected_rows),
        selection_breakdown={
            "unseen": unseen_count,
            "weak_review": weak_count,
            "spaced_review": review_count,
        },
        reasons=reasons,
        next_adjustment_hint=next_adjustment_hint,
        questions=[
            _adaptive_question_payload(question, chapter)
            for question, chapter in selected_rows
        ],
        is_demo=is_demo,
        session_id=session_id,
        user_message_id=user_message_id,
        assistant_message_id=assistant_message_id,
    )


@router.post("/knowledge-cards/generate", response_model=AIKnowledgeCardResponse)
async def generate_knowledge_card(
    payload: AIKnowledgeCardGenerateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    source = await db.scalar(
        select(AIConversation).where(
            AIConversation.id == payload.source_message_id,
            AIConversation.user_id == current_user.id,
            AIConversation.message_type == "assistant",
        )
    )
    if source is None:
        raise HTTPException(status_code=404, detail="AI 回复不存在")
    existing = await db.scalar(
        select(AIKnowledgeCard).where(
            AIKnowledgeCard.user_id == current_user.id,
            AIKnowledgeCard.source_message_id == source.id,
        )
    )
    if existing is not None:
        return existing

    raw_category = payload.exam_category or source.exam_category or current_user.target_exam
    category = try_normalize_exam_category(raw_category)
    if category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")

    question = None
    if source.related_question_id is not None:
        question = await db.get(Question, source.related_question_id)
    question_tags = list(getattr(question, "知识点", None) or []) if question else []
    focus = (
        (payload.title_hint or "").strip()
        or (question_tags[0] if question_tags else "本次 AI 讲解")
    )
    fallback = {
        "title": f"{focus}记忆卡",
        "front": f"遇到「{focus}」相关题目时，最关键的判断依据是什么？",
        "back": source.content[:1000],
        "mnemonic": "先找题干关键词，再核对核心概念，最后辨析相近选项。",
        "tags": question_tags[:5] or [focus],
    }
    fallback_text = json.dumps(fallback, ensure_ascii=False)
    generated, _ = await safe_ai_text(
        [
            {"role": "system", "content": build_medical_system_prompt()},
            {
                "role": "user",
                "content": (
                    "请把下面的医考讲解压缩成一张用于主动回忆的记忆卡。"
                    "只输出严格 JSON，不要 Markdown，字段必须是 title、front、back、mnemonic、tags。"
                    "front 必须是一个可自测的问题；back 120字以内；mnemonic 简短且注明适用边界；"
                    "tags 为最多5个字符串。不得补充来源中没有依据的医学结论。\n"
                    f"考试分类：{category}\n题目：{question.content if question else '暂无关联题目'}\n"
                    f"AI讲解：{source.content[:3000]}"
                ),
            },
        ],
        fallback_text,
    )
    card_data = _knowledge_card_json(generated, fallback)
    tags = card_data.get("tags")
    if not isinstance(tags, list):
        tags = fallback["tags"]
    tags = [str(tag).strip() for tag in tags if str(tag).strip()][:5]
    card = AIKnowledgeCard(
        user_id=current_user.id,
        exam_category=category,
        source_message_id=source.id,
        related_question_id=source.related_question_id,
        title=str(card_data.get("title") or fallback["title"])[:120],
        front=str(card_data.get("front") or fallback["front"])[:1000],
        back=str(card_data.get("back") or fallback["back"])[:2000],
        mnemonic=str(card_data.get("mnemonic") or fallback["mnemonic"])[:1000],
        tags=tags,
        mastery_level=0,
        review_count=0,
        next_review_at=datetime.now(),
    )
    db.add(card)
    await _increment_ai_question_count(db, current_user.id)
    await db.commit()
    await db.refresh(card)
    return card


@router.get("/knowledge-cards", response_model=List[AIKnowledgeCardResponse])
async def get_knowledge_cards(
    exam_category: Optional[str] = None,
    due_only: bool = False,
    limit: int = 100,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    filters = [AIKnowledgeCard.user_id == current_user.id]
    if exam_category:
        category = try_normalize_exam_category(exam_category)
        if category is None:
            return []
        filters.append(AIKnowledgeCard.exam_category == category)
    if due_only:
        filters.append(AIKnowledgeCard.next_review_at <= datetime.now())
    result = await db.execute(
        select(AIKnowledgeCard)
        .where(*filters)
        .order_by(AIKnowledgeCard.next_review_at.asc(), AIKnowledgeCard.created_at.desc())
        .limit(max(1, min(limit, 200)))
    )
    return result.scalars().all()


@router.post(
    "/knowledge-cards/{card_id}/review",
    response_model=AIKnowledgeCardResponse,
)
async def review_knowledge_card(
    card_id: int,
    payload: AIKnowledgeCardReviewRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if payload.rating not in {"again", "hard", "good", "easy"}:
        raise HTTPException(status_code=400, detail="复习评价不正确")
    card = await db.scalar(
        select(AIKnowledgeCard).where(
            AIKnowledgeCard.id == card_id,
            AIKnowledgeCard.user_id == current_user.id,
        )
    )
    if card is None:
        raise HTTPException(status_code=404, detail="记忆卡不存在")
    schedules = {
        "again": [1, 1, 1, 1, 1],
        "hard": [1, 2, 3, 5, 7],
        "good": [2, 4, 7, 14, 30],
        "easy": [4, 7, 14, 30, 60],
    }
    index = min(card.review_count, len(schedules[payload.rating]) - 1)
    interval_days = schedules[payload.rating][index]
    card.review_count += 1
    if payload.rating == "again":
        card.mastery_level = max(0, card.mastery_level - 1)
    elif payload.rating == "hard":
        card.mastery_level = min(5, card.mastery_level + 0)
    elif payload.rating == "good":
        card.mastery_level = min(5, card.mastery_level + 1)
    else:
        card.mastery_level = min(5, card.mastery_level + 2)
    card.last_reviewed_at = datetime.now()
    card.next_review_at = datetime.now() + timedelta(days=interval_days)
    await db.commit()
    await db.refresh(card)
    return card


@router.delete("/knowledge-cards/{card_id}")
async def delete_knowledge_card(
    card_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    card = await db.scalar(
        select(AIKnowledgeCard).where(
            AIKnowledgeCard.id == card_id,
            AIKnowledgeCard.user_id == current_user.id,
        )
    )
    if card is None:
        raise HTTPException(status_code=404, detail="记忆卡不存在")
    await db.delete(card)
    await db.commit()
    return {"message": "记忆卡已删除"}


@router.post("/weakness-insights", response_model=AIWeaknessInsightsResponse)
async def ai_weakness_insights(
    payload: AIWeaknessInsightsRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """比较最近周期与上一周期表现，识别真正持续或恶化的薄弱章节。"""
    category = try_normalize_exam_category(payload.exam_category)
    if category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")
    now = datetime.now()
    recent_start = now - timedelta(days=payload.period_days)
    previous_start = recent_start - timedelta(days=payload.period_days)
    rows = (
        await db.execute(
            select(QuestionRecord, Question, Chapter)
            .join(Question, QuestionRecord.question_id == Question.id)
            .join(Chapter, Question.chapter_id == Chapter.id)
            .where(
                QuestionRecord.user_id == current_user.id,
                QuestionRecord.selected_answer.is_not(None),
                Chapter.exam_category == category,
                QuestionRecord.created_at >= previous_start,
            )
        )
    ).all()
    chapter_stats = {}
    for record, _, chapter in rows:
        item = chapter_stats.setdefault(
            chapter.id,
            {
                "chapter": chapter,
                "recent_total": 0,
                "recent_correct": 0,
                "previous_total": 0,
                "previous_correct": 0,
            },
        )
        if record.created_at >= recent_start:
            item["recent_total"] += 1
            item["recent_correct"] += 1 if record.is_correct else 0
        else:
            item["previous_total"] += 1
            item["previous_correct"] += 1 if record.is_correct else 0

    insights = []
    for item in chapter_stats.values():
        recent_total = item["recent_total"]
        previous_total = item["previous_total"]
        if recent_total <= 0:
            continue
        recent_accuracy = item["recent_correct"] / recent_total
        previous_accuracy = (
            item["previous_correct"] / previous_total if previous_total else None
        )
        delta = (
            recent_accuracy - previous_accuracy
            if previous_accuracy is not None
            else None
        )
        if previous_accuracy is None:
            trend = "数据积累中"
        elif delta >= 0.1:
            trend = "明显进步"
        elif delta <= -0.1:
            trend = "有所下降"
        else:
            trend = "基本稳定"
        if recent_total < 5:
            status = "样本较少"
            recommendation = "再完成至少 5 道本章节题，让诊断更稳定。"
        elif recent_accuracy < 0.6:
            status = "重点补强"
            recommendation = "先复习本章错题，再做 10 道同类题并标注错因。"
        elif recent_accuracy < 0.75:
            status = "薄弱"
            recommendation = "完成一组章节练习，重点辨析反复混淆的选项。"
        elif delta is not None and delta <= -0.1:
            status = "需要回稳"
            recommendation = "正确率近期下降，建议用限时小练习恢复熟练度。"
        else:
            status = "稳定"
            recommendation = "保持少量随机复习，避免遗忘。"
        chapter = item["chapter"]
        insights.append(
            AIWeaknessInsightItem(
                chapter_id=chapter.id,
                chapter_name=chapter.name,
                recent_questions=recent_total,
                previous_questions=previous_total,
                recent_accuracy=recent_accuracy,
                previous_accuracy=previous_accuracy,
                trend_delta=delta,
                trend=trend,
                wrong_count=recent_total - item["recent_correct"],
                status=status,
                recommendation=recommendation,
            )
        )
    insights.sort(
        key=lambda insight: (
            insight.recent_accuracy,
            -insight.wrong_count,
            -insight.recent_questions,
        )
    )
    insights = insights[:5]
    total_records = sum(item.recent_questions for item in insights)
    if not insights:
        summary = (
            f"当前还没有足够的 {category} 做题数据。先完成一组章节或随机练习，"
            "我会从正确率、题量和变化趋势三个维度持续跟踪。"
        )
        return AIWeaknessInsightsResponse(
            title="AI 长期薄弱点追踪",
            summary=summary,
            period_days=payload.period_days,
            total_records=0,
            items=[],
            actions=["先完成一组随机练习", "答错后标注错因", "积累后重新诊断"],
            is_demo=True,
        )

    compact = [
        {
            "chapter": item.chapter_name,
            "recent_accuracy": round(item.recent_accuracy * 100),
            "trend": item.trend,
            "wrong_count": item.wrong_count,
            "status": item.status,
        }
        for item in insights
    ]
    fallback = (
        f"最近 {payload.period_days} 天共分析 {total_records} 道题。"
        f"当前最需要关注「{insights[0].chapter_name}」，正确率约"
        f" {round(insights[0].recent_accuracy * 100)}%。"
        "建议先处理低正确率且近期下降的章节，再用同类题验证补强效果。"
    )
    summary, is_demo = await safe_ai_text(
        [
            {"role": "system", "content": build_medical_system_prompt()},
            {
                "role": "user",
                "content": (
                    "请根据长期学习趋势生成医考薄弱点诊断摘要。中文100字以内，"
                    "指出最优先章节、趋势和一条行动建议；不得夸大少量样本。\n"
                    f"考试分类：{category}\n周期：{payload.period_days}天\n数据：{compact}"
                ),
            },
        ],
        fallback,
    )
    session_id = f"weakness-insights-{category}"
    user_message_id, assistant_message_id = await _record_ai_learning_event(
        db,
        current_user.id,
        session_id,
        f"生成{category}{payload.period_days}天薄弱点趋势诊断",
        summary,
        exam_category=category,
    )
    await db.commit()
    return AIWeaknessInsightsResponse(
        title="AI 长期薄弱点追踪",
        summary=summary,
        period_days=payload.period_days,
        total_records=total_records,
        items=insights,
        actions=["先练最低正确率章节", "复习近期新增错题", "7天后重新诊断"],
        is_demo=is_demo,
        session_id=session_id,
        user_message_id=user_message_id,
        assistant_message_id=assistant_message_id,
    )


@router.post("/error-patterns", response_model=AIErrorPatternResponse)
async def ai_error_patterns(
    payload: AIErrorPatternRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """跨题目识别稳定错因模式，并给出可直接进入题组的纠偏处方。"""
    category = try_normalize_exam_category(payload.exam_category)
    if category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")
    cutoff = datetime.now() - timedelta(days=payload.period_days)
    rows = (
        await db.execute(
            select(WrongQuestion, Question, Chapter)
            .join(Question, WrongQuestion.question_id == Question.id)
            .join(Chapter, Question.chapter_id == Chapter.id)
            .where(
                WrongQuestion.user_id == current_user.id,
                WrongQuestion.is_mastered == False,
                WrongQuestion.created_at >= cutoff,
                Chapter.exam_category == category,
            )
            .order_by(WrongQuestion.created_at.desc())
        )
    ).all()
    if not rows:
        return AIErrorPatternResponse(
            summary=(
                f"最近 {payload.period_days} 天还没有可诊断的 {category} 错题。"
                "先完成一组练习，AI 会从错因、用时、难度和重复失分中识别模式。"
            ),
            exam_category=category,
            period_days=payload.period_days,
            total_wrong=0,
            analyzed_records=0,
            patterns=[],
            training_sequence=["完成一组 AI 自适应练习", "答错后标注真实错因"],
            actions=["开始 AI 自适应练习", "完成后重新诊断"],
            is_demo=True,
        )

    question_ids = [question.id for _, question, _ in rows]
    incorrect_records = list(
        (
            await db.execute(
                select(QuestionRecord)
                .where(
                    QuestionRecord.user_id == current_user.id,
                    QuestionRecord.question_id.in_(question_ids),
                    QuestionRecord.is_correct == False,
                )
                .order_by(QuestionRecord.created_at.desc())
            )
        ).scalars().all()
    )
    latest_records: dict[int, QuestionRecord] = {}
    for record in incorrect_records:
        latest_records.setdefault(record.question_id, record)

    definitions = {
        "knowledge_gap": {
            "name": "知识漏洞",
            "diagnosis": "基础概念或章节知识链尚未建立，容易在同类考点连续失分。",
            "correction": "先回看对应章节核心概念，再完成 10 道由易到难的同类题。",
            "mode": "chapter",
        },
        "concept_confusion": {
            "name": "概念混淆",
            "diagnosis": "相近概念、适应证或辨证要点边界不清，干扰项容易互相替代。",
            "correction": "用对比表整理易混点，再闭卷说出关键差异并做同标签题。",
            "mode": "tag",
        },
        "memory_decay": {
            "name": "记忆不牢",
            "diagnosis": "知识曾经学过但提取不稳定，同一道题复习后仍会再次失分。",
            "correction": "采用 1、3、7 天间隔复习，并把关键结论制成 AI 记忆卡。",
            "mode": "wrong",
        },
        "reading_bias": {
            "name": "审题偏差",
            "diagnosis": "作答过快或遗漏限定词，知识本身可能掌握但没有完整读取题干。",
            "correction": "训练圈出否定词、时间和对象，每题作答前用一句话复述题意。",
            "mode": "random",
        },
        "time_pressure": {
            "name": "时间压力",
            "diagnosis": "单题耗时明显偏长，推理过程卡顿并挤压后续题目的检查时间。",
            "correction": "先做限时小题组，超过 90 秒先标记跳过，完成后再回看。",
            "mode": "random",
        },
        "reasoning_chain": {
            "name": "推理链断点",
            "diagnosis": "面对综合题时无法把题干线索串成完整判断链，容易停在局部信息。",
            "correction": "先写出线索、判断、排除三步，再用 AI 费曼复述检查推理链。",
            "mode": "chapter",
        },
    }

    def classify(
        wrong: WrongQuestion,
        question: Question,
        record: Optional[QuestionRecord],
    ) -> str:
        reason = (wrong.wrong_reason or "").strip()
        if any(token in reason for token in ("粗心", "审题", "看错")):
            return "reading_bias"
        if any(token in reason for token in ("记忆", "忘记", "背诵")):
            return "memory_decay"
        if any(token in reason for token in ("混淆", "易混")):
            return "concept_confusion"
        if any(token in reason for token in ("时间", "来不及", "太慢")):
            return "time_pressure"
        if any(token in reason for token in ("推理", "分析", "病例")):
            return "reasoning_chain"

        time_spent = record.time_spent if record else 0
        if wrong.review_count >= 2:
            return "memory_decay"
        if 0 < time_spent <= 12:
            return "reading_bias"
        if time_spent >= 120:
            return "time_pressure"
        if (question.difficulty or 3) >= 4:
            return "reasoning_chain"
        if reason == "概念不清" and question.知识点:
            return "concept_confusion"
        return "knowledge_gap"

    grouped: dict[str, dict] = {}
    generic_tags = {
        category,
        "执业资格",
        "执业医师",
        "助理医师",
        "初级职称",
        "中级职称",
        "高级职称",
    }
    for wrong, question, chapter in rows:
        record = latest_records.get(question.id)
        key = classify(wrong, question, record)
        item = grouped.setdefault(
            key,
            {
                "question_ids": [],
                "times": [],
                "chapter_counts": {},
                "chapters": {},
                "tag_counts": {},
                "reason_counts": {},
            },
        )
        item["question_ids"].append(question.id)
        if record and record.time_spent > 0:
            item["times"].append(record.time_spent)
        item["chapter_counts"][chapter.id] = (
            item["chapter_counts"].get(chapter.id, 0) + 1
        )
        item["chapters"][chapter.id] = chapter.name
        for tag in question.知识点 or []:
            if tag and tag not in generic_tags and tag != chapter.name:
                item["tag_counts"][tag] = item["tag_counts"].get(tag, 0) + 1
        reason = (wrong.wrong_reason or "未标注错因").strip()
        item["reason_counts"][reason] = item["reason_counts"].get(reason, 0) + 1

    patterns = []
    for key, item in grouped.items():
        count = len(item["question_ids"])
        percentage = count / len(rows)
        top_chapter_id = max(
            item["chapter_counts"],
            key=item["chapter_counts"].get,
        )
        top_chapter_name = item["chapters"][top_chapter_id]
        top_tag = (
            max(item["tag_counts"], key=item["tag_counts"].get)
            if item["tag_counts"]
            else None
        )
        top_reason = max(item["reason_counts"], key=item["reason_counts"].get)
        evidence = [f"{count} 道错题，占当前待复习错题的 {round(percentage * 100)}%"]
        evidence.append(
            f"主要集中在「{top_chapter_name}」"
            + (f"的「{top_tag}」考点" if top_tag else "")
        )
        if item["times"]:
            evidence.append(
                f"相关错题平均用时 {round(sum(item['times']) / len(item['times']))} 秒"
            )
        if top_reason != "未标注错因":
            evidence.append(f"已标注错因以「{top_reason}」为主")
        severity = "高" if percentage >= 0.4 or count >= 5 else "中" if count >= 2 else "低"
        definition = definitions[key]
        patterns.append(
            AIErrorPatternItem(
                key=key,
                name=definition["name"],
                count=count,
                percentage=percentage,
                severity=severity,
                diagnosis=definition["diagnosis"],
                evidence=evidence,
                correction=definition["correction"],
                chapter_id=top_chapter_id,
                chapter_name=top_chapter_name,
                tag=top_tag,
                mode=definition["mode"],
                question_ids=item["question_ids"][:10],
            )
        )
    patterns.sort(key=lambda item: (-item.count, item.name))
    top_pattern = patterns[0]
    training_sequence = [
        f"第 1 步：先完成「{top_pattern.name}」纠偏题组",
        "第 2 步：错题必须标注真实错因，并用一句话复述正确依据",
        "第 3 步：24 小时后重做同组题，正确率达到 80% 再进入下一模式",
    ]
    compact = [
        {
            "name": item.name,
            "count": item.count,
            "percentage": round(item.percentage * 100),
            "chapter": item.chapter_name,
        }
        for item in patterns[:4]
    ]
    fallback = (
        f"最近 {payload.period_days} 天分析了 {len(rows)} 道待复习错题，最突出的是"
        f"「{top_pattern.name}」，占 {round(top_pattern.percentage * 100)}%。"
        f"建议先处理「{top_pattern.chapter_name}」，完成一组纠偏题后于次日复测。"
    )
    summary, is_demo = await safe_ai_text(
        [
            {"role": "system", "content": build_medical_system_prompt()},
            {
                "role": "user",
                "content": (
                    "请作为医考错因诊断教练，用100字以内总结错题模式。"
                    "必须指出首要错因、证据、优先章节和一项可验证的纠偏动作；"
                    "不要把少量样本说成确定结论。\n"
                    f"考试分类：{category}\n周期：{payload.period_days}天\n模式：{compact}"
                ),
            },
        ],
        fallback,
    )
    session_id = f"error-patterns-{category}"
    user_message_id, assistant_message_id = await _record_ai_learning_event(
        db,
        current_user.id,
        session_id,
        f"诊断{category}最近{payload.period_days}天错因模式",
        summary,
        exam_category=category,
    )
    await db.commit()
    return AIErrorPatternResponse(
        summary=summary,
        exam_category=category,
        period_days=payload.period_days,
        total_wrong=len(rows),
        analyzed_records=len(latest_records),
        top_pattern=top_pattern.name,
        patterns=patterns,
        training_sequence=training_sequence,
        actions=["开始首要错因纠偏", "标注未分类错题", "24小时后复测"],
        is_demo=is_demo,
        session_id=session_id,
        user_message_id=user_message_id,
        assistant_message_id=assistant_message_id,
    )


@router.post("/sprint-plan", response_model=AISprintPlanResponse)
async def ai_sprint_plan(
    payload: AISprintPlanRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """根据考期、可用时间和真实练习记录生成可落地的阶段冲刺计划。"""
    category = try_normalize_exam_category(payload.exam_category)
    if category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")

    target_datetime = payload.exam_date or current_user.target_date
    if target_datetime is None:
        raise HTTPException(status_code=400, detail="请先设置考试日期")
    exam_day = target_datetime.date()
    today = datetime.now().date()
    days_remaining = (exam_day - today).days + 1
    if days_remaining <= 0:
        raise HTTPException(status_code=400, detail="考试日期必须晚于今天")

    chapters = list(
        (
            await db.execute(
                select(Chapter)
                .where(Chapter.exam_category == category)
                .order_by(Chapter.order.asc(), Chapter.id.asc())
            )
        ).scalars().all()
    )
    record_rows = (
        await db.execute(
            select(QuestionRecord, Question)
            .join(Question, QuestionRecord.question_id == Question.id)
            .join(Chapter, Question.chapter_id == Chapter.id)
            .where(
                QuestionRecord.user_id == current_user.id,
                QuestionRecord.selected_answer.is_not(None),
                Chapter.exam_category == category,
            )
        )
    ).all()
    chapter_stats: dict[int, dict[str, int]] = {}
    for record, question in record_rows:
        item = chapter_stats.setdefault(
            question.chapter_id,
            {"total": 0, "correct": 0},
        )
        item["total"] += 1
        item["correct"] += 1 if record.is_correct else 0

    def chapter_rank(chapter: Chapter) -> tuple[float, int, int]:
        item = chapter_stats.get(chapter.id, {"total": 0, "correct": 0})
        total = item["total"]
        # 已暴露出的低正确率优先，其次是尚未覆盖章节，最后才是已掌握章节。
        if total:
            return (item["correct"] / total, 0, chapter.order or 0)
        return (0.72, 1, chapter.order or 0)

    priority_chapters = []
    for chapter in sorted(chapters, key=chapter_rank)[:5]:
        item = chapter_stats.get(chapter.id, {"total": 0, "correct": 0})
        total = item["total"]
        accuracy = item["correct"] / total if total else None
        if total == 0:
            reason = "尚未练习，优先建立基础覆盖"
        elif accuracy < 0.6:
            reason = f"正确率仅 {round(accuracy * 100)}%，是当前首要提分点"
        elif accuracy < 0.75:
            reason = f"正确率 {round(accuracy * 100)}%，需要专项补强"
        else:
            reason = "已有基础，用间隔练习保持稳定"
        priority_chapters.append(
            AISprintPriorityChapter(
                chapter_id=chapter.id,
                chapter_name=chapter.name,
                accuracy_rate=accuracy,
                practiced_questions=total,
                reason=reason,
            )
        )

    intensity_factor = {
        "steady": 0.85,
        "accelerated": 1.0,
        "sprint": 1.2,
    }[payload.intensity]
    daily_questions = max(
        10,
        min(120, round(payload.daily_minutes * 0.55 * intensity_factor)),
    )
    weekly_mock_exams = 2 if payload.intensity == "sprint" else 1
    if days_remaining < 10:
        weekly_mock_exams = max(2, weekly_mock_exams)

    priority_name = (
        priority_chapters[0].chapter_name if priority_chapters else "核心考点"
    )
    phases: list[AISprintPhase] = []

    def add_phase(
        name: str,
        start_day: int,
        end_day: int,
        focus: str,
        actions: list[str],
        milestone: str,
    ) -> None:
        if end_day < start_day:
            return
        phases.append(
            AISprintPhase(
                name=name,
                start_day=start_day,
                end_day=end_day,
                days=end_day - start_day + 1,
                focus=focus,
                daily_actions=actions,
                milestone=milestone,
            )
        )

    if days_remaining >= 45:
        foundation_end = max(1, round(days_remaining * 0.45))
        strengthen_end = max(foundation_end + 1, round(days_remaining * 0.8))
        add_phase(
            "基础覆盖期",
            1,
            foundation_end,
            "按大纲完成章节覆盖，建立稳定正确率",
            ["章节精学", "完成未做题", "当天错题当天复盘"],
            "主要章节完成首轮覆盖，正确率稳定到 70%",
        )
        add_phase(
            "薄弱强化期",
            foundation_end + 1,
            strengthen_end,
            f"集中攻克「{priority_name}」等低正确率章节",
            ["AI 自适应训练", "错题二刷", "每周一次模考"],
            "重点章节正确率提升到 80% 左右",
        )
        add_phase(
            "冲刺回稳期",
            strengthen_end + 1,
            days_remaining,
            "模考校准节奏，高频考点和错题快速回看",
            ["限时模考", "AI 模考复盘", "记忆卡快速回忆"],
            "形成稳定答题节奏并减少重复失分",
        )
    elif days_remaining >= 21:
        foundation_end = max(1, round(days_remaining * 0.3))
        strengthen_end = max(foundation_end + 1, round(days_remaining * 0.75))
        add_phase(
            "重点覆盖期",
            1,
            foundation_end,
            "快速覆盖未做章节，同时标出真实薄弱点",
            ["未做题训练", "课程重点回看", "错题标因"],
            "完成重点章节首轮覆盖",
        )
        add_phase(
            "专项提分期",
            foundation_end + 1,
            strengthen_end,
            f"优先补强「{priority_name}」并持续自适应调难",
            ["AI 自适应训练", "费曼复述", "错题间隔复习"],
            "薄弱章节连续两组正确率达到 80%",
        )
        add_phase(
            "考前冲刺期",
            strengthen_end + 1,
            days_remaining,
            "用模考定位最后失分点，控制复习范围",
            ["限时模考", "AI 复盘", "高频记忆卡"],
            "答题速度和正确率进入稳定区间",
        )
    elif days_remaining >= 10:
        strengthen_end = max(1, round(days_remaining * 0.65))
        add_phase(
            "高效补弱期",
            1,
            strengthen_end,
            f"放弃平均用力，先拿下「{priority_name}」等高收益章节",
            ["AI 自适应训练", "错题止血", "高频考点"],
            "最弱章节不再连续重复失分",
        )
        add_phase(
            "实战冲刺期",
            strengthen_end + 1,
            days_remaining,
            "限时模考与轻量复盘交替，保持考试手感",
            ["隔日模考", "只复盘高价值错题", "睡前记忆卡"],
            "稳定完成整套题并留出检查时间",
        )
    else:
        add_phase(
            "考前抢分期",
            1,
            days_remaining,
            f"聚焦「{priority_name}」、高频考点和近期错题，不再盲目扩展范围",
            ["上午高频考点", "下午限时题组", "晚上错题与记忆卡"],
            "减少可避免失分，保持作息和答题节奏",
        )

    question_minutes = max(10, round(payload.daily_minutes * 0.5))
    review_minutes = max(5, round(payload.daily_minutes * 0.2))
    course_minutes = max(5, payload.daily_minutes - question_minutes - review_minutes)
    daily_schedule = [
        f"{question_minutes} 分钟：完成约 {daily_questions} 道 AI 自适应/章节题",
        f"{review_minutes} 分钟：复习到期错题并标注真实错因",
        f"{course_minutes} 分钟：课程精学或 AI 费曼复述",
        "结束前 3 分钟：查看 AI 小结并确定明日第一项任务",
    ]
    today_actions = [
        f"先做「{priority_name}」{min(daily_questions, 20)} 道专项题",
        "复习 5 道到期错题，答完再看解析",
        "选 1 个易混考点做 AI 费曼复述",
    ]

    total_records = len(record_rows)
    total_correct = sum(1 for record, _ in record_rows if record.is_correct)
    overall_accuracy = total_correct / total_records if total_records else None
    risk_alerts = []
    if total_records < 20:
        risk_alerts.append("当前历史做题样本较少，先完成两组练习后再让 AI 校准计划。")
    if days_remaining < 14:
        risk_alerts.append("距离考试不足 14 天，应优先高频考点和旧错题，避免全面铺新内容。")
    if payload.daily_minutes < 40:
        risk_alerts.append("每日时间较紧，建议固定同一学习时段，减少启动成本。")
    if overall_accuracy is not None and overall_accuracy < 0.6:
        risk_alerts.append("当前综合正确率偏低，前半程先保证基础题正确率，不宜盲目追难题。")
    if not priority_chapters:
        risk_alerts.append("当前考试分类尚无章节数据，计划暂按通用节奏生成。")

    intensity_label = {
        "steady": "稳步",
        "accelerated": "加速",
        "sprint": "冲刺",
    }[payload.intensity]
    fallback_summary = (
        f"距离 {category} 考试还有 {days_remaining} 天。我按每天 {payload.daily_minutes} 分钟"
        f"生成了 {intensity_label}计划：每日约 {daily_questions} 题，优先补强「{priority_name}」，"
        f"并用错题复习和每周 {weekly_mock_exams} 次模考持续校准。"
    )
    summary, is_demo = await safe_ai_text(
        [
            {"role": "system", "content": build_medical_system_prompt()},
            {
                "role": "user",
                "content": (
                    "请作为医考冲刺规划师，用不超过120字总结可执行备考策略。"
                    "必须提到剩余天数、每日时间、首要薄弱章节和模考频率，不要鸡汤。\n"
                    f"考试：{category}\n剩余：{days_remaining}天\n"
                    f"每日：{payload.daily_minutes}分钟/{daily_questions}题\n"
                    f"强度：{intensity_label}\n优先章节："
                    f"{[item.model_dump() for item in priority_chapters]}"
                ),
            },
        ],
        fallback_summary,
    )
    session_id = f"sprint-plan-{category}"
    user_message_id, assistant_message_id = await _record_ai_learning_event(
        db,
        current_user.id,
        session_id,
        f"生成{category}{days_remaining}天AI冲刺计划",
        summary,
        exam_category=category,
    )
    await db.commit()

    return AISprintPlanResponse(
        title=f"{category} · AI {days_remaining} 天冲刺计划",
        summary=summary,
        exam_category=category,
        exam_date=datetime.combine(exam_day, datetime.min.time()),
        days_remaining=days_remaining,
        daily_minutes=payload.daily_minutes,
        daily_questions=daily_questions,
        weekly_mock_exams=weekly_mock_exams,
        intensity=payload.intensity,
        priority_chapters=priority_chapters,
        phases=phases,
        daily_schedule=daily_schedule,
        today_actions=today_actions,
        risk_alerts=risk_alerts,
        is_demo=is_demo,
        session_id=session_id,
        user_message_id=user_message_id,
        assistant_message_id=assistant_message_id,
    )


@router.post("/course-coach", response_model=AITextResponse)
async def ai_course_coach(
    payload: AICourseCoachRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """课程伴学：课前明确学习目标，课后给出检验与巩固动作。"""
    category = try_normalize_exam_category(payload.exam_category)
    if category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")
    if payload.stage not in {"preview", "review"}:
        raise HTTPException(status_code=400, detail="课程伴学阶段不正确")

    chapter = (payload.chapter_name or "课程关联考点").strip()
    completed = max(0, min(payload.completed_lessons, payload.lesson_count))
    is_preview = payload.stage == "preview"
    if is_preview:
        title = "AI 课前导学"
        fallback = (
            f"本课围绕「{chapter}」展开。学习前先明确三个任务：梳理核心概念，"
            "带着易混点问题听课，并记录一个仍不确定的判断依据。"
            "学完后立即完成关联章节练习，用结果检验是否真正掌握。"
        )
        actions = ["明确本课学习目标", "带着易混问题听课", "学完立即做课后练习"]
        task = (
            "请生成课前导学。分成【本课目标】【带着问题学】【听课重点】【学后检验】四段，"
            "不超过260字。不得假装看过未提供的具体课程内容，只能依据课程标题、简介和关联章节。"
        )
    else:
        title = "AI 课后复盘"
        fallback = (
            f"当前已完成 {completed}/{max(payload.lesson_count, 1)} 讲。"
            f"请先不看资料复述「{chapter}」的三个关键点，再完成关联章节练习。"
            "把新错题标注为知识盲区、审题失误或记忆混淆，明天优先二刷未掌握题。"
        )
        actions = ["闭卷复述三个重点", "完成关联章节练习", "明天二刷新错题"]
        task = (
            "请生成课后复盘计划。分成【完成情况】【闭卷自测】【练习安排】【明日复习】四段，"
            "不超过260字。不得编造用户已经掌握的具体知识，只给出可验证的学习动作。"
        )

    content, is_demo = await safe_ai_text(
        [
            {"role": "system", "content": build_medical_system_prompt()},
            {
                "role": "user",
                "content": (
                    f"{task}\n考试分类：{category}\n课程：{payload.course_title}\n"
                    f"关联章节：{chapter}\n课程简介：{payload.description or '暂无'}\n"
                    f"课程讲数：{payload.lesson_count}\n已完成：{completed}"
                ),
            },
        ],
        fallback,
    )
    course_key = payload.course_id or "custom"
    session_id = f"course-coach-{course_key}-{payload.stage}"
    user_message_id, assistant_message_id = await _record_ai_learning_event(
        db,
        current_user.id,
        session_id,
        f"生成《{payload.course_title}》{'课前导学' if is_preview else '课后复盘'}",
        content,
        exam_category=category,
    )
    await db.commit()
    return AITextResponse(
        title=title,
        content=content,
        actions=actions,
        is_demo=is_demo,
        session_id=session_id,
        user_message_id=user_message_id,
        assistant_message_id=assistant_message_id,
    )


@router.post("/practice-review", response_model=AITextResponse)
async def ai_practice_review(
    payload: AIPracticeReviewRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """整组练习复盘：把成绩、速度和失分点转成下一步训练动作。"""
    category = try_normalize_exam_category(payload.exam_category)
    if category is None:
        raise HTTPException(status_code=400, detail="考试分类不正确")
    if payload.answered_count <= 0:
        raise HTTPException(status_code=400, detail="至少完成一道题后才能生成练习复盘")

    answered = max(payload.answered_count, 1)
    accuracy = round(payload.correct_count / answered * 100)
    average_seconds = round(payload.time_spent / answered)
    sorted_tags = sorted(
        payload.wrong_tags.items(), key=lambda item: item[1], reverse=True
    )[:3]
    weak_text = "、".join(name for name, _ in sorted_tags) or "暂未发现集中失分点"
    fallback = (
        f"本组完成 {payload.answered_count} 题，正确率 {accuracy}%，平均每题约 {average_seconds} 秒。"
        f"当前重点关注：{weak_text}。"
        "下一组先复盘本次错题，再做10道同知识点题；做题时先圈关键词，再排除明显干扰项。"
    )
    content, is_demo = await safe_ai_text(
        [
            {"role": "system", "content": build_medical_system_prompt()},
            {
                "role": "user",
                "content": (
                    "请作为医考练习教练生成整组练习复盘。分成【表现判断】【失分模式】"
                    "【下一组训练】【复习时间】四段，不超过280字。"
                    "只能依据提供的数据判断，不得编造用户能力或医学结论。\n"
                    f"考试分类：{category}\n练习：{payload.practice_title}\n"
                    f"题目总数：{payload.total_questions}\n已答：{payload.answered_count}\n"
                    f"正确：{payload.correct_count}\n错误：{payload.wrong_count}\n"
                    f"总用时：{payload.time_spent}秒\n失分知识点：{payload.wrong_tags}"
                ),
            },
        ],
        fallback,
    )
    session_id = f"practice-review-{category}"
    user_message_id, assistant_message_id = await _record_ai_learning_event(
        db,
        current_user.id,
        session_id,
        f"复盘{payload.practice_title}：正确{payload.correct_count}/{payload.answered_count}",
        content,
        exam_category=category,
    )
    await db.commit()
    return AITextResponse(
        title="AI 练习小结",
        content=content,
        actions=["先复习本组错题", "再做10道同类题", "明天二刷未掌握题"],
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
