"""启动时初始化数据库表，并在空库时写入种子数据。"""
from passlib.context import CryptContext
from sqlalchemy import func, select

from app.core.database import AsyncSessionLocal, Base, engine
from app.models import admin_user, conversation, course, question, study, user  # noqa: F401
from app.models.admin_user import AdminUser
from app.models.question import Chapter
from app.models.user import User


pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


async def init_database() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as db:
        chapter_count = await db.scalar(select(func.count()).select_from(Chapter))

    if not chapter_count:
        from seed_data import seed_chapters, seed_questions

        await seed_chapters()
        await seed_questions()

    async with AsyncSessionLocal() as db:
        demo_user = await db.scalar(select(User).where(User.username == "demo"))
        if demo_user is None:
            db.add(
                User(
                    username="demo",
                    email="demo@medexam.local",
                    hashed_password=pwd_context.hash("demo123"),
                    full_name="演示医生",
                    target_exam="执业资格",
                    daily_goal=30,
                )
            )
            await db.commit()

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
