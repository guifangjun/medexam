"""启动时初始化数据库表，并在空库时写入种子数据。"""
from sqlalchemy import func, select

from app.core.database import AsyncSessionLocal, Base, engine
from app.models import conversation, question, study, user  # noqa: F401
from app.models.question import Chapter


async def init_database() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as db:
        chapter_count = await db.scalar(select(func.count()).select_from(Chapter))

    if not chapter_count:
        from seed_data import seed_chapters, seed_questions

        await seed_chapters()
        await seed_questions()
