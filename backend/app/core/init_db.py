"""启动时初始化数据库表，并在空库时写入种子数据。"""
from passlib.context import CryptContext
from sqlalchemy import delete, func, select, text

from app.core.database import AsyncSessionLocal, Base, engine
from app.models import admin_user, conversation, course, question, study, user  # noqa: F401
from app.models.admin_user import AdminUser
from app.models.course import Course
from app.models.conversation import AIConversation
from app.models.question import Chapter, ExamAttempt, Question, QuestionRecord
from app.models.study import DailyTask, StudyPlan, StudyStats, WrongQuestion
from app.models.user import User
from app.core.licensed_exam_questions import build_licensed_exam_questions
from app.core.exam_categories import (
    EXAM_CATEGORY_ALIASES,
    EXAM_CATEGORIES,
    normalize_exam_category,
)


pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


async def init_database() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await _ensure_sqlite_columns(conn)

    async with AsyncSessionLocal() as db:
        chapter_count = await db.scalar(select(func.count()).select_from(Chapter))

    if not chapter_count:
        from seed_data import seed_chapters, seed_questions

        await seed_chapters()
        await seed_questions()

    await _ensure_exam_category_content()

    async with AsyncSessionLocal() as db:
        await _normalize_user_exam_categories(db)
        await _cleanup_orphan_user_data(db)
        await _ensure_demo_user(db)
        await _ensure_course_chapter_links(db)


async def _ensure_demo_user(db) -> None:
    demo_phone = "13800000000"
    legacy_demo = await db.scalar(select(User).where(User.username == "demo"))
    if legacy_demo is not None:
        legacy_demo.username = demo_phone
        legacy_demo.phone = demo_phone
        legacy_demo.email = f"{demo_phone}@phone.medexam.cn"
        legacy_demo.hashed_password = pwd_context.hash("demo123")
        legacy_demo.full_name = legacy_demo.full_name or "演示医生"
        legacy_demo.target_exam = "执业资格"
        legacy_demo.daily_goal = 30
        await db.commit()

    demo_user = await db.scalar(select(User).where(User.username == demo_phone))
    if demo_user is None:
        db.add(
            User(
                username=demo_phone,
                email=f"{demo_phone}@phone.medexam.cn",
                phone=demo_phone,
                hashed_password=pwd_context.hash("demo123"),
                full_name="演示医生",
                target_exam="执业资格",
                daily_goal=30,
            )
        )
        await db.commit()
    else:
        demo_user.phone = demo_phone
        demo_user.email = f"{demo_phone}@phone.medexam.cn"
        demo_user.hashed_password = pwd_context.hash("demo123")
        demo_user.full_name = demo_user.full_name or "演示医生"
        demo_user.target_exam = "执业资格"
        demo_user.daily_goal = demo_user.daily_goal or 30
    await db.commit()


async def _cleanup_orphan_user_data(db) -> None:
    """清理历史遗留的无主学习数据，避免后台统计被已删除用户污染。"""
    user_ids = select(User.id)
    for model in (
        AIConversation,
        ExamAttempt,
        WrongQuestion,
        QuestionRecord,
        DailyTask,
        StudyStats,
        StudyPlan,
    ):
        await db.execute(delete(model).where(model.user_id.not_in(user_ids)))
    await db.commit()


async def _ensure_course_chapter_links(db) -> None:
    """为未关联章节的课程补齐同考试类别章节，保证课程-题库闭环默认可用。"""
    chapter_rows = (
        await db.execute(select(Chapter).order_by(Chapter.exam_category, Chapter.order))
    ).scalars().all()
    first_chapter_by_category = {}
    for chapter in chapter_rows:
        first_chapter_by_category.setdefault(chapter.exam_category, chapter)

    courses = (await db.execute(select(Course))).scalars().all()
    changed = False
    for item in courses:
        normalized_category = normalize_exam_category(item.exam_category)
        if item.exam_category != normalized_category:
            item.exam_category = normalized_category
            changed = True
        if item.chapter_id is not None:
            continue
        chapter = first_chapter_by_category.get(item.exam_category)
        if chapter is None:
            continue
        item.chapter_id = chapter.id
        changed = True
    if changed:
        await db.commit()


async def _normalize_user_exam_categories(db) -> None:
    changed = False
    users = (await db.execute(select(User))).scalars().all()
    for item in users:
        target = item.target_exam or "执业资格"
        normalized = EXAM_CATEGORY_ALIASES.get(target, target)
        if normalized not in EXAM_CATEGORIES:
            normalized = "执业资格"
        if item.target_exam != normalized:
            item.target_exam = normalized
            changed = True
    if changed:
        await db.commit()


async def _ensure_sqlite_columns(conn) -> None:
    if engine.url.get_backend_name() != "sqlite":
        return

    result = await conn.execute(text("PRAGMA table_info(chapters)"))
    columns = {row[1] for row in result.fetchall()}
    if "exam_category" not in columns:
        await conn.execute(
            text(
                "ALTER TABLE chapters "
                "ADD COLUMN exam_category VARCHAR(50) NOT NULL DEFAULT '执业资格'"
            )
        )

    result = await conn.execute(text("PRAGMA table_info(users)"))
    user_columns = {row[1] for row in result.fetchall()}
    if "phone" not in user_columns:
        await conn.execute(text("ALTER TABLE users ADD COLUMN phone VARCHAR(20)"))

    result = await conn.execute(text("PRAGMA table_info(courses)"))
    course_columns = {row[1] for row in result.fetchall()}
    if "chapter_id" not in course_columns:
        await conn.execute(text("ALTER TABLE courses ADD COLUMN chapter_id INTEGER"))

    result = await conn.execute(text("PRAGMA table_info(daily_tasks)"))
    daily_task_columns = {row[1] for row in result.fetchall()}
    if "exam_category" not in daily_task_columns:
        await conn.execute(
            text(
                "ALTER TABLE daily_tasks "
                "ADD COLUMN exam_category VARCHAR(50) NOT NULL DEFAULT '执业资格'"
            )
        )

    result = await conn.execute(text("PRAGMA table_info(study_plans)"))
    study_plan_columns = {row[1] for row in result.fetchall()}
    if "exam_category" not in study_plan_columns:
        await conn.execute(
            text("ALTER TABLE study_plans ADD COLUMN exam_category VARCHAR(50)")
        )

    result = await conn.execute(text("PRAGMA table_info(ai_conversations)"))
    ai_conversation_columns = {row[1] for row in result.fetchall()}
    if "exam_category" not in ai_conversation_columns:
        await conn.execute(
            text("ALTER TABLE ai_conversations ADD COLUMN exam_category VARCHAR(50)")
        )


async def _ensure_exam_category_content() -> None:
    licensed_chapters = [
        (
            "医学人文综合",
            ["医学心理学", "医学伦理学", "卫生法规", "医学人文素养"],
        ),
        (
            "基础医学综合",
            ["解剖学", "生理学", "生物化学", "病理学", "药理学", "医学微生物学", "医学免疫学"],
        ),
        (
            "预防医学综合",
            ["预防医学", "流行病学", "卫生统计学", "公共卫生"],
        ),
        (
            "临床医学综合",
            [
                "呼吸系统",
                "心血管系统",
                "消化系统",
                "泌尿系统",
                "女性生殖系统",
                "血液系统",
                "内分泌系统",
                "神经精神系统",
                "运动系统",
                "儿科疾病",
                "传染病",
                "急诊与危重症",
            ],
        ),
        (
            "中医学基础",
            ["中医基础理论", "中医诊断基础", "常见中医治法"],
        ),
        (
            "实践综合",
            ["临床思维", "体格检查", "基本操作", "辅助检查判读"],
        ),
    ]
    chapter_seed = {
        "执业资格": licensed_chapters,
        "初级职称": [
            ("初级基础知识", ["生理学", "病理学", "药理学"]),
            ("专业理论与技能", ["诊断学", "内科学", "外科学"]),
            ("常见病诊疗", ["心血管疾病", "呼吸系统", "消化系统"]),
        ],
        "中级职称": [
            ("中级临床理论", ["病理生理学", "分子生物学", "免疫学"]),
            ("专业进展", ["循证医学", "临床指南", "新技术应用"]),
            ("疑难病例分析", ["复杂病例", "多学科会诊"]),
        ],
        "高级职称": [
            ("学科前沿", ["最新研究成果", "前沿技术"]),
            ("临床科研方法", ["临床试验", "医学统计学", "论文写作"]),
            ("医学教育", ["教学能力", "继续教育"]),
        ],
    }

    async with AsyncSessionLocal() as db:
        licensed_question_count = await db.scalar(
            select(func.count()).select_from(Question).join(Chapter).where(
                Chapter.exam_category == "执业资格"
            )
        )
        if not licensed_question_count:
            licensed_existing = (
                (
                    await db.execute(
                        select(Chapter)
                        .where(Chapter.exam_category == "执业资格")
                        .order_by(Chapter.order)
                    )
                )
                .scalars()
                .all()
            )
            desired_names = [name for name, _ in licensed_chapters]
            existing_names = [chapter.name for chapter in licensed_existing]
            if existing_names != desired_names:
                for chapter in licensed_existing:
                    await db.delete(chapter)
                for index, (name, subjects) in enumerate(licensed_chapters, start=1):
                    db.add(
                        Chapter(
                            name=name,
                            exam_category="执业资格",
                            subjects=subjects,
                            order=index,
                        )
                    )

        for category, chapters in chapter_seed.items():
            existing_count = await db.scalar(
                select(func.count()).select_from(Chapter).where(
                    Chapter.exam_category == category
                )
            )
            if not existing_count:
                for index, (name, subjects) in enumerate(chapters, start=1):
                    db.add(
                        Chapter(
                            name=name,
                            exam_category=category,
                            subjects=subjects,
                            order=index,
                        )
                    )
        legacy_intermediate = await db.scalar(
            select(Chapter).where(
                Chapter.exam_category == "中级职称",
                Chapter.name == "高级临床理论",
            )
        )
        if legacy_intermediate is not None:
            legacy_intermediate.name = "中级临床理论"
        await db.commit()

    await _ensure_licensed_exam_questions()

    async with AsyncSessionLocal() as db:
        admin = await db.scalar(select(AdminUser).where(AdminUser.username == "admin"))
        if admin is None:
            db.add(
                AdminUser(
                    username="admin",
                    hashed_password=pwd_context.hash("admin123"),
                    full_name="系统管理员",
                    role="super_admin",
                )
            )
            await db.commit()


async def _ensure_licensed_exam_questions() -> None:
    rows = build_licensed_exam_questions()
    async with AsyncSessionLocal() as db:
        chapters_result = await db.execute(
            select(Chapter).where(Chapter.exam_category == "执业资格")
        )
        chapters_by_name = {
            chapter.name: chapter for chapter in chapters_result.scalars().all()
        }
        missing_chapters = sorted(
            {chapter_name for chapter_name, *_ in rows} - set(chapters_by_name)
        )
        if missing_chapters:
            raise RuntimeError(f"缺少执业资格章节: {', '.join(missing_chapters)}")

        content_result = await db.execute(
            select(Question.content).join(Chapter).where(
                Chapter.exam_category == "执业资格"
            )
        )
        existing_contents = set(content_result.scalars().all())
        inserted = False
        for chapter_name, subject, content, options, answer, explanation, difficulty in rows:
            if content in existing_contents:
                continue
            chapter = chapters_by_name[chapter_name]
            db.add(
                Question(
                    chapter_id=chapter.id,
                    question_type="single",
                    content=content,
                    options=options,
                    answer=answer,
                    explanation=explanation,
                    difficulty=difficulty,
                    is_real_exam=True,
                    exam_year=2026,
                    知识点=["执业资格", "执业医师", chapter_name, subject],
                )
            )
            existing_contents.add(content)
            inserted = True
        if inserted:
            await db.commit()

    async with AsyncSessionLocal() as db:
        course_count = await db.scalar(select(func.count()).select_from(Course))
        if not course_count:
            chapter_rows = (
                await db.execute(
                    select(Chapter).order_by(Chapter.exam_category, Chapter.order)
                )
            ).scalars().all()
            first_chapter_by_category = {}
            for chapter in chapter_rows:
                first_chapter_by_category.setdefault(chapter.exam_category, chapter)

            db.add_all(
                [
                    Course(
                        title="执业资格考前高频考点直播",
                        course_type="live",
                        exam_category="执业资格",
                        chapter_id=first_chapter_by_category.get("执业资格").id,
                        teacher="三甲医院教研组",
                        schedule="今晚 20:00",
                        lesson_count=1,
                        description="围绕基础医学、临床医学和医学人文梳理高频考点。",
                    ),
                    Course(
                        title="初级职称专业基础直播班",
                        course_type="live",
                        exam_category="初级职称",
                        chapter_id=first_chapter_by_category.get("初级职称").id,
                        teacher="初级职称命题研究组",
                        schedule="明晚 19:30",
                        lesson_count=1,
                        description="聚焦专业基础、常见题型和岗位规范。",
                    ),
                    Course(
                        title="中级职称病例分析实战课",
                        course_type="live",
                        exam_category="中级职称",
                        chapter_id=first_chapter_by_category.get("中级职称").id,
                        teacher="临床病例教研中心",
                        schedule="周六 20:00",
                        lesson_count=1,
                        description="拆解病例题审题、诊断和治疗决策路径。",
                    ),
                    Course(
                        title="高级职称专科前沿公开课",
                        course_type="live",
                        exam_category="高级职称",
                        chapter_id=first_chapter_by_category.get("高级职称").id,
                        teacher="高级职称评审专家组",
                        schedule="周日 19:30",
                        lesson_count=1,
                        description="讲解指南更新、专科前沿和综合病例答题框架。",
                    ),
                    Course(
                        title="执业资格核心基础精讲",
                        course_type="recorded",
                        exam_category="执业资格",
                        chapter_id=first_chapter_by_category.get("执业资格").id,
                        teacher="系统课教研组",
                        schedule="随到随学",
                        lesson_count=32,
                        description="按考试大纲拆解基础医学、临床医学和预防医学。",
                    ),
                    Course(
                        title="初级职称常见病诊疗专题",
                        course_type="recorded",
                        exam_category="初级职称",
                        chapter_id=first_chapter_by_category.get("初级职称").id,
                        teacher="专业基础教研组",
                        schedule="随到随学",
                        lesson_count=24,
                        description="覆盖常见病诊疗、专业基础与技能规范。",
                    ),
                    Course(
                        title="中级职称真题与错题专题课",
                        course_type="recorded",
                        exam_category="中级职称",
                        chapter_id=first_chapter_by_category.get("中级职称").id,
                        teacher="中级职称冲刺组",
                        schedule="随到随学",
                        lesson_count=20,
                        description="按真题题型复盘高频错点与病例综合题。",
                    ),
                    Course(
                        title="高级职称科研与病例综合课",
                        course_type="recorded",
                        exam_category="高级职称",
                        chapter_id=first_chapter_by_category.get("高级职称").id,
                        teacher="高级职称教研组",
                        schedule="随到随学",
                        lesson_count=18,
                        description="覆盖临床科研方法、指南更新和综合答辩能力。",
                    ),
                    Course(
                        title="未发布课程示例",
                        course_type="recorded",
                        exam_category="执业资格",
                        chapter_id=first_chapter_by_category.get("执业资格").id,
                        teacher="后台测试",
                        schedule="待定",
                        lesson_count=4,
                        description="用于验证学员端不会展示未发布课程。",
                        is_published=False,
                    ),
                ]
            )
            await db.commit()
