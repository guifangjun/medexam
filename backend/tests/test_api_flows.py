import os
import asyncio
import tempfile
import unittest
from datetime import datetime, timedelta


_db_file = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
_db_file.close()
os.environ["DATABASE_URL"] = f"sqlite+aiosqlite:///{_db_file.name}"
os.environ["DEBUG"] = "false"

import httpx
from sqlalchemy import func, select

from app.core.database import AsyncSessionLocal
from app.core.init_db import init_database
from app.main import app
from app.models.conversation import AIConversation
from app.models.question import Chapter, ExamAttempt, Question, QuestionRecord
from app.models.study import DailyTask, StudyPlan, StudyStats, WrongQuestion
from app.models.user import User


class ApiFlowTests(unittest.IsolatedAsyncioTestCase):
    @classmethod
    def tearDownClass(cls):
        os.unlink(_db_file.name)

    async def asyncSetUp(self):
        await init_database()
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app), base_url="http://test"
        )
        login = await self.client.post(
            "/api/auth/login", data={"username": "13800000000", "password": "demo123"}
        )
        self.assertEqual(login.status_code, 200, login.text)
        self.user_headers = {
            "Authorization": f"Bearer {login.json()['access_token']}"
        }
        admin_login = await self.client.post(
            "/api/admin/auth/login",
            data={"username": "admin", "password": "admin123"},
        )
        self.assertEqual(admin_login.status_code, 200, admin_login.text)
        self.admin_headers = {
            "Authorization": f"Bearer {admin_login.json()['access_token']}"
        }

        async with AsyncSessionLocal() as db:
            for model in (
                WrongQuestion,
                StudyStats,
                DailyTask,
                StudyPlan,
                QuestionRecord,
                AIConversation,
            ):
                rows = (await db.execute(select(model))).scalars().all()
                for row in rows:
                    await db.delete(row)
            await db.commit()

    async def asyncTearDown(self):
        await self.client.aclose()

    async def test_health_aliases_are_available(self):
        root_health = await self.client.get("/health")
        api_health = await self.client.get("/api/health")
        self.assertEqual(root_health.status_code, 200, root_health.text)
        self.assertEqual(api_health.status_code, 200, api_health.text)
        self.assertEqual(root_health.json()["status"], "healthy")
        self.assertEqual(api_health.json()["status"], "healthy")

    async def test_public_courses_hide_unpublished_but_admin_sees_all(self):
        public = await self.client.get("/api/admin/courses")
        admin = await self.client.get(
            "/api/admin/courses", headers=self.admin_headers
        )
        self.assertEqual(public.status_code, 200, public.text)
        self.assertTrue(public.json())
        self.assertTrue(all(course["is_published"] for course in public.json()))
        linked_course = next(
            course for course in public.json() if course["chapter_id"] is not None
        )
        self.assertTrue(linked_course["chapter_name"])
        self.assertGreaterEqual(linked_course["chapter_question_count"], 0)
        self.assertGreater(len(admin.json()), len(public.json()))

    async def test_invalid_admin_list_filters_do_not_fallback_to_default(self):
        public_courses = await self.client.get(
            "/api/admin/courses", params={"exam_category": "junior"}
        )
        admin_courses = await self.client.get(
            "/api/admin/courses",
            params={"exam_category": "junior"},
            headers=self.admin_headers,
        )
        admin_questions = await self.client.get(
            "/api/admin/questions",
            params={"exam_category": "junior"},
            headers=self.admin_headers,
        )
        admin_users = await self.client.get(
            "/api/admin/users",
            params={"exam_category": "junior"},
            headers=self.admin_headers,
        )
        self.assertEqual(public_courses.status_code, 200, public_courses.text)
        self.assertEqual(admin_courses.status_code, 200, admin_courses.text)
        self.assertEqual(admin_questions.status_code, 200, admin_questions.text)
        self.assertEqual(admin_users.status_code, 200, admin_users.text)
        self.assertEqual(public_courses.json(), [])
        self.assertEqual(admin_courses.json(), [])
        self.assertEqual(admin_questions.json(), [])
        self.assertEqual(admin_users.json(), [])

    async def test_admin_rejects_invalid_exam_category_on_write(self):
        phone = "13900001234"
        bad_user = await self.client.post(
            "/api/admin/users",
            json={
                "phone": phone,
                "password": "test123",
                "full_name": "非法分类用户",
                "target_exam": "junior",
                "is_active": True,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(bad_user.status_code, 400, bad_user.text)

        good_user = await self.client.post(
            "/api/admin/users",
            json={
                "phone": phone,
                "password": "test123",
                "full_name": "合法分类用户",
                "target_exam": "licensed_doctor",
                "is_active": True,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(good_user.status_code, 200, good_user.text)
        self.assertEqual(good_user.json()["target_exam"], "执业资格")
        bad_user_update = await self.client.put(
            f"/api/admin/users/{good_user.json()['id']}",
            json={"target_exam": "junior"},
            headers=self.admin_headers,
        )
        self.assertEqual(bad_user_update.status_code, 400, bad_user_update.text)
        await self.client.delete(
            f"/api/admin/users/{good_user.json()['id']}",
            headers=self.admin_headers,
        )

        chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "执业资格"}
        )
        chapter_id = chapters.json()[0]["id"]
        bad_course = await self.client.post(
            "/api/admin/courses",
            json={
                "title": "非法分类课程",
                "course_type": "recorded",
                "exam_category": "junior",
                "chapter_id": chapter_id,
                "teacher": "测试讲师",
                "schedule": "随到随学",
                "lesson_count": 1,
                "description": "非法分类",
                "is_published": True,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(bad_course.status_code, 422, bad_course.text)

        good_course = await self.client.post(
            "/api/admin/courses",
            json={
                "title": "合法别名课程",
                "course_type": "recorded",
                "exam_category": "licensed_doctor",
                "chapter_id": chapter_id,
                "teacher": "测试讲师",
                "schedule": "随到随学",
                "lesson_count": 1,
                "description": "合法别名",
                "is_published": True,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(good_course.status_code, 200, good_course.text)
        self.assertEqual(good_course.json()["exam_category"], "执业资格")
        bad_course_update = await self.client.put(
            f"/api/admin/courses/{good_course.json()['id']}",
            json={"exam_category": "junior"},
            headers=self.admin_headers,
        )
        self.assertEqual(bad_course_update.status_code, 422, bad_course_update.text)
        await self.client.delete(
            f"/api/admin/courses/{good_course.json()['id']}",
            headers=self.admin_headers,
        )

    async def test_admin_course_chapter_must_match_exam_category(self):
        licensed_chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "执业资格"}
        )
        junior_chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "初级职称"}
        )
        self.assertTrue(licensed_chapters.json())
        self.assertTrue(junior_chapters.json())
        licensed_chapter_id = licensed_chapters.json()[0]["id"]
        junior_chapter_id = junior_chapters.json()[0]["id"]

        bad_create = await self.client.post(
            "/api/admin/courses",
            json={
                "title": "跨分类错误课程",
                "course_type": "recorded",
                "exam_category": "初级职称",
                "chapter_id": licensed_chapter_id,
                "teacher": "测试讲师",
                "schedule": "随到随学",
                "lesson_count": 1,
                "description": "用于验证课程章节分类一致性",
                "is_published": True,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(bad_create.status_code, 400)

        created = await self.client.post(
            "/api/admin/courses",
            json={
                "title": "分类一致课程",
                "course_type": "recorded",
                "exam_category": "初级职称",
                "chapter_id": junior_chapter_id,
                "teacher": "测试讲师",
                "schedule": "随到随学",
                "lesson_count": 1,
                "description": "用于验证课程章节分类一致性",
                "is_published": True,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(created.status_code, 200, created.text)
        self.assertEqual(created.json()["chapter_id"], junior_chapter_id)
        self.assertTrue(created.json()["chapter_name"])
        self.assertGreaterEqual(created.json()["chapter_question_count"], 0)

        updated = await self.client.put(
            f"/api/admin/courses/{created.json()['id']}",
            json={"title": "分类一致课程-已编辑"},
            headers=self.admin_headers,
        )
        self.assertEqual(updated.status_code, 200, updated.text)
        self.assertEqual(updated.json()["chapter_id"], junior_chapter_id)
        self.assertEqual(updated.json()["chapter_name"], created.json()["chapter_name"])

        bad_update = await self.client.put(
            f"/api/admin/courses/{created.json()['id']}",
            json={"chapter_id": licensed_chapter_id},
            headers=self.admin_headers,
        )
        self.assertEqual(bad_update.status_code, 400)
        await self.client.delete(
            f"/api/admin/courses/{created.json()['id']}",
            headers=self.admin_headers,
        )

    async def test_linked_public_course_can_open_pre_and_post_practice(self):
        courses = await self.client.get(
            "/api/admin/courses", params={"exam_category": "执业资格"}
        )
        self.assertEqual(courses.status_code, 200, courses.text)
        linked = next(
            (
                course
                for course in courses.json()
                if course["chapter_id"] is not None
                and course["chapter_question_count"] > 0
            ),
            None,
        )
        self.assertIsNotNone(linked, courses.json())

        for mode in ("unanswered", "chapter"):
            questions = await self.client.get(
                "/api/questions/practice",
                params={
                    "exam_category": linked["exam_category"],
                    "chapter_id": linked["chapter_id"],
                    "mode": mode,
                    "limit": 5,
                },
                headers=self.user_headers,
            )
            self.assertEqual(questions.status_code, 200, questions.text)
            self.assertTrue(questions.json(), f"{mode} should return questions")
            self.assertTrue(
                all(
                    question["chapter_id"] == linked["chapter_id"]
                    and question["exam_category"] == linked["exam_category"]
                    for question in questions.json()
                ),
                questions.json(),
            )

    async def test_admin_dashboard_chapter_question_count_is_not_duplicated_by_records(self):
        async with AsyncSessionLocal() as db:
            user = (
                await db.execute(select(User).where(User.username == "13800000000"))
            ).scalar_one()
            question = (await db.execute(select(Question).limit(1))).scalar_one()
            chapter_id = question.chapter_id
            actual_question_count = await db.scalar(
                select(func.count(Question.id)).where(Question.chapter_id == chapter_id)
            )
            total_question_count = await db.scalar(select(func.count(Question.id)))
            db.add_all(
                [
                    QuestionRecord(
                        user_id=user.id,
                        question_id=question.id,
                        selected_answer="A",
                        is_correct=True,
                        is_wrong=False,
                        time_spent=10,
                    ),
                    QuestionRecord(
                        user_id=user.id,
                        question_id=question.id,
                        selected_answer="B",
                        is_correct=False,
                        is_wrong=True,
                        time_spent=12,
                    ),
                ]
            )
            await db.commit()

        dashboard = await self.client.get(
            "/api/admin/dashboard", headers=self.admin_headers
        )
        self.assertEqual(dashboard.status_code, 200, dashboard.text)
        self.assertEqual(dashboard.json()["question_count"], total_question_count)
        row = next(
            item
            for item in dashboard.json()["chapter_activity"]
            if item["chapter_id"] == chapter_id
        )
        self.assertEqual(row["question_count"], actual_question_count)
        self.assertEqual(row["practice_count"], 2)

    async def test_admin_user_exam_category_alias_is_normalized(self):
        created = await self.client.post(
            "/api/admin/users",
            json={
                "phone": "13900000001",
                "password": "demo123",
                "full_name": "别名分类测试用户",
                "target_exam": "执业医师",
            },
            headers=self.admin_headers,
        )
        self.assertEqual(created.status_code, 200, created.text)
        self.assertEqual(created.json()["target_exam"], "执业资格")

        updated = await self.client.put(
            f"/api/admin/users/{created.json()['id']}",
            json={"target_exam": "助理医师"},
            headers=self.admin_headers,
        )
        self.assertEqual(updated.status_code, 200, updated.text)
        self.assertEqual(updated.json()["target_exam"], "执业资格")

        filtered = await self.client.get(
            "/api/admin/users",
            params={"exam_category": "执业医师"},
            headers=self.admin_headers,
        )
        self.assertEqual(filtered.status_code, 200, filtered.text)
        self.assertTrue(
            any(item["id"] == created.json()["id"] for item in filtered.json())
        )

    async def test_admin_delete_user_cleans_learning_data(self):
        created = await self.client.post(
            "/api/admin/users",
            json={
                "phone": "13900000004",
                "password": "demo123",
                "full_name": "删除清理测试用户",
                "target_exam": "执业资格",
            },
            headers=self.admin_headers,
        )
        self.assertEqual(created.status_code, 200, created.text)
        user_id = created.json()["id"]
        login = await self.client.post(
            "/api/auth/login",
            data={"username": "13900000004", "password": "demo123"},
        )
        self.assertEqual(login.status_code, 200, login.text)
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

        questions = await self.client.get(
            "/api/questions/exam",
            params={"question_count": 2, "exam_category": "执业资格"},
        )
        self.assertGreaterEqual(len(questions.json()), 2)
        wrong_answer = next(
            key for key in questions.json()[0]["options"]
            if key != questions.json()[0]["answer"]
        )
        practice = await self.client.post(
            "/api/questions/submit",
            json={
                "question_id": questions.json()[0]["id"],
                "selected_answer": wrong_answer,
                "time_spent": 10,
            },
            headers=headers,
        )
        self.assertEqual(practice.status_code, 200, practice.text)
        exam = await self.client.post(
            "/api/questions/exam/submit",
            json={
                "time_spent": 60,
                "answers": [
                    {
                        "question_id": questions.json()[0]["id"],
                        "selected_answer": questions.json()[0]["answer"],
                    },
                    {
                        "question_id": questions.json()[1]["id"],
                        "selected_answer": None,
                    },
                ],
            },
            headers=headers,
        )
        self.assertEqual(exam.status_code, 200, exam.text)
        plan = await self.client.post(
            "/api/study/plan",
            json={
                "title": "删除用户测试计划",
                "plan_type": "daily",
                "target_chapters": [],
                "daily_questions": 20,
                "start_date": datetime.now().isoformat(),
                "end_date": (datetime.now() + timedelta(days=7)).isoformat(),
            },
            headers=headers,
        )
        self.assertEqual(plan.status_code, 200, plan.text)
        chat = await self.client.post(
            "/api/ai/chat",
            json={"content": "删除用户前的学习记录"},
            headers=headers,
        )
        self.assertEqual(chat.status_code, 200, chat.text)

        deleted = await self.client.delete(
            f"/api/admin/users/{user_id}", headers=self.admin_headers
        )
        self.assertEqual(deleted.status_code, 200, deleted.text)

        async with AsyncSessionLocal() as db:
            for model in (
                WrongQuestion,
                StudyStats,
                StudyPlan,
                DailyTask,
                QuestionRecord,
            ):
                count = await db.scalar(
                    select(func.count()).select_from(model).where(model.user_id == user_id)
                )
                self.assertEqual(count, 0, model.__name__)
            from app.models.conversation import AIConversation
            from app.models.question import ExamAttempt

            for model in (AIConversation, ExamAttempt):
                count = await db.scalar(
                    select(func.count()).select_from(model).where(model.user_id == user_id)
                )
                self.assertEqual(count, 0, model.__name__)

        relogin = await self.client.post(
            "/api/auth/login",
            data={"username": "13900000004", "password": "demo123"},
        )
        self.assertEqual(relogin.status_code, 401)

    async def test_init_database_cleans_orphan_user_data(self):
        orphan_user_id = 999999
        async with AsyncSessionLocal() as db:
            question_id = await db.scalar(select(Question.id).limit(1))
            self.assertIsNotNone(question_id)
            db.add_all(
                [
                    AIConversation(
                        user_id=orphan_user_id,
                        session_id="orphan-session",
                        message_type="user",
                        content="无主 AI 消息",
                    ),
                    ExamAttempt(
                        user_id=orphan_user_id,
                        exam_category="执业资格",
                        total_questions=1,
                        answered_count=1,
                        correct_count=1,
                        score=1,
                        accuracy_rate=1,
                        report={},
                    ),
                    WrongQuestion(
                        user_id=orphan_user_id,
                        question_id=question_id,
                    ),
                    QuestionRecord(
                        user_id=orphan_user_id,
                        question_id=question_id,
                        selected_answer="A",
                        is_correct=True,
                        is_wrong=False,
                    ),
                    DailyTask(
                        user_id=orphan_user_id,
                        date=datetime.now().strftime("%Y-%m-%d"),
                        target_questions=20,
                    ),
                    StudyStats(
                        user_id=orphan_user_id,
                        date=datetime.now().strftime("%Y-%m-%d"),
                        total_questions=1,
                        correct_count=1,
                    ),
                    StudyPlan(
                        user_id=orphan_user_id,
                        title="无主计划",
                        plan_type="daily",
                        target_chapters=[],
                        daily_questions=20,
                        start_date=datetime.now(),
                        end_date=datetime.now() + timedelta(days=7),
                    ),
                ]
            )
            await db.commit()

        await init_database()

        async with AsyncSessionLocal() as db:
            for model in (
                AIConversation,
                ExamAttempt,
                WrongQuestion,
                QuestionRecord,
                DailyTask,
                StudyStats,
                StudyPlan,
            ):
                count = await db.scalar(
                    select(func.count()).select_from(model).where(
                        model.user_id == orphan_user_id
                    )
                )
                self.assertEqual(count, 0, model.__name__)

    async def test_admin_delete_question_cleans_records_and_wrong_book(self):
        chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "执业资格"}
        )
        self.assertEqual(chapters.status_code, 200, chapters.text)
        chapter_id = chapters.json()[0]["id"]
        created = await self.client.post(
            "/api/admin/questions",
            json={
                "chapter_id": chapter_id,
                "question_type": "single",
                "content": "后台删除清理测试题",
                "options": {"A": "正确项", "B": "错误项"},
                "answer": "A",
                "explanation": "用于验证删除题目时清理学习记录",
                "difficulty": 1,
                "tags": ["后台验收"],
            },
            headers=self.admin_headers,
        )
        self.assertEqual(created.status_code, 200, created.text)
        question_id = created.json()["id"]

        submitted = await self.client.post(
            "/api/questions/submit",
            json={
                "question_id": question_id,
                "selected_answer": "B",
                "time_spent": 8,
            },
            headers=self.user_headers,
        )
        self.assertEqual(submitted.status_code, 200, submitted.text)

        deleted = await self.client.delete(
            f"/api/admin/questions/{question_id}", headers=self.admin_headers
        )
        self.assertEqual(deleted.status_code, 200, deleted.text)

        async with AsyncSessionLocal() as db:
            self.assertEqual(
                await db.scalar(
                    select(func.count(Question.id)).where(Question.id == question_id)
                ),
                0,
            )
            self.assertEqual(
                await db.scalar(
                    select(func.count(QuestionRecord.id)).where(
                        QuestionRecord.question_id == question_id
                    )
                ),
                0,
            )
            self.assertEqual(
                await db.scalar(
                    select(func.count(WrongQuestion.id)).where(
                        WrongQuestion.question_id == question_id
                    )
                ),
                0,
            )

    async def test_inactive_user_cannot_login_with_password(self):
        created = await self.client.post(
            "/api/admin/users",
            json={
                "phone": "13900000002",
                "password": "demo123",
                "full_name": "停用登录测试用户",
                "target_exam": "执业资格",
                "is_active": False,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(created.status_code, 200, created.text)

        login = await self.client.post(
            "/api/auth/login",
            data={"username": "13900000002", "password": "demo123"},
        )
        self.assertEqual(login.status_code, 401)
        self.assertIn("账号已停用", login.json()["detail"])

    async def test_register_rejects_short_password(self):
        code_res = await self.client.post(
            "/api/auth/sms-code",
            json={"phone": "13900000003", "purpose": "register"},
        )
        self.assertEqual(code_res.status_code, 200, code_res.text)
        registered = await self.client.post(
            "/api/auth/register",
            json={
                "phone": "13900000003",
                "sms_code": code_res.json()["code"],
                "password": "12345",
            },
        )
        self.assertEqual(registered.status_code, 422)

    async def test_auth_rejects_invalid_exam_category_and_sms_purpose_mismatch(self):
        phone = "13900000007"
        code_res = await self.client.post(
            "/api/auth/sms-code",
            json={"phone": phone, "purpose": "register"},
        )
        self.assertEqual(code_res.status_code, 200, code_res.text)
        bad_register = await self.client.post(
            "/api/auth/register",
            json={
                "phone": phone,
                "sms_code": code_res.json()["code"],
                "password": "demo123",
                "target_exam": "junior",
            },
        )
        self.assertEqual(bad_register.status_code, 422, bad_register.text)

        good_register = await self.client.post(
            "/api/auth/register",
            json={
                "phone": phone,
                "sms_code": code_res.json()["code"],
                "password": "demo123",
                "target_exam": "licensed_doctor",
            },
        )
        self.assertEqual(good_register.status_code, 200, good_register.text)
        self.assertEqual(good_register.json()["target_exam"], "执业资格")

        register_code_for_login = await self.client.post(
            "/api/auth/sms-code",
            json={"phone": "13900000008", "purpose": "register"},
        )
        self.assertEqual(
            register_code_for_login.status_code, 200, register_code_for_login.text
        )
        created = await self.client.post(
            "/api/admin/users",
            json={
                "phone": "13900000008",
                "password": "demo123",
                "target_exam": "执业资格",
                "is_active": True,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(created.status_code, 200, created.text)
        bad_sms_login = await self.client.post(
            "/api/auth/login/sms",
            json={
                "phone": "13900000008",
                "sms_code": register_code_for_login.json()["code"],
            },
        )
        self.assertEqual(bad_sms_login.status_code, 401, bad_sms_login.text)

        login_code = await self.client.post(
            "/api/auth/sms-code",
            json={"phone": phone, "purpose": "login"},
        )
        self.assertEqual(login_code.status_code, 200, login_code.text)
        sms_login = await self.client.post(
            "/api/auth/login/sms",
            json={"phone": phone, "sms_code": login_code.json()["code"]},
        )
        self.assertEqual(sms_login.status_code, 200, sms_login.text)
        headers = {"Authorization": f"Bearer {sms_login.json()['access_token']}"}
        bad_update = await self.client.put(
            "/api/auth/me", json={"target_exam": "junior"}, headers=headers
        )
        self.assertEqual(bad_update.status_code, 422, bad_update.text)

        alias_update = await self.client.put(
            "/api/auth/me", json={"target_exam": "执业医师"}, headers=headers
        )
        self.assertEqual(alias_update.status_code, 200, alias_update.text)
        self.assertEqual(alias_update.json()["target_exam"], "执业资格")

    async def test_sms_code_purpose_matches_account_state(self):
        unregistered_login = await self.client.post(
            "/api/auth/sms-code",
            json={"phone": "13900000005", "purpose": "login"},
        )
        self.assertEqual(unregistered_login.status_code, 400)

        registered_login = await self.client.post(
            "/api/auth/sms-code",
            json={"phone": "13800000000", "purpose": "login"},
        )
        registered_register = await self.client.post(
            "/api/auth/sms-code",
            json={"phone": "13800000000", "purpose": "register"},
        )
        bad_purpose = await self.client.post(
            "/api/auth/sms-code",
            json={"phone": "13800000000", "purpose": "reset"},
        )
        self.assertEqual(registered_login.status_code, 200, registered_login.text)
        self.assertEqual(registered_register.status_code, 400)
        self.assertEqual(bad_purpose.status_code, 400)

        created = await self.client.post(
            "/api/admin/users",
            json={
                "phone": "13900000006",
                "password": "demo123",
                "full_name": "停用验证码测试用户",
                "target_exam": "执业资格",
                "is_active": False,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(created.status_code, 200, created.text)
        inactive_login = await self.client.post(
            "/api/auth/sms-code",
            json={"phone": "13900000006", "purpose": "login"},
        )
        self.assertEqual(inactive_login.status_code, 400)

        from app.api import deps as auth_deps

        auth_deps._sms_codes["13900000006"] = {
            "code": "123456",
            "purpose": "login",
            "expires_at": datetime.utcnow() + timedelta(minutes=5),
        }
        inactive_sms_login = await self.client.post(
            "/api/auth/login/sms",
            json={"phone": "13900000006", "sms_code": "123456"},
        )
        self.assertEqual(inactive_sms_login.status_code, 401)

    async def test_sms_code_expires_for_register_and_login(self):
        from app.api import deps as auth_deps

        register_phone = "13900000009"
        register_code = await self.client.post(
            "/api/auth/sms-code",
            json={"phone": register_phone, "purpose": "register"},
        )
        self.assertEqual(register_code.status_code, 200, register_code.text)
        auth_deps._sms_codes[register_phone]["expires_at"] = (
            datetime.utcnow() - timedelta(seconds=1)
        )
        expired_register = await self.client.post(
            "/api/auth/register",
            json={
                "phone": register_phone,
                "sms_code": register_code.json()["code"],
                "password": "demo123",
            },
        )
        self.assertEqual(expired_register.status_code, 400, expired_register.text)

        login_phone = "13800000000"
        login_code = await self.client.post(
            "/api/auth/sms-code",
            json={"phone": login_phone, "purpose": "login"},
        )
        self.assertEqual(login_code.status_code, 200, login_code.text)
        auth_deps._sms_codes[login_phone]["expires_at"] = (
            datetime.utcnow() - timedelta(seconds=1)
        )
        expired_login = await self.client.post(
            "/api/auth/login/sms",
            json={
                "phone": login_phone,
                "sms_code": login_code.json()["code"],
            },
        )
        self.assertEqual(expired_login.status_code, 401, expired_login.text)

    async def test_user_phone_update_keeps_login_account_consistent(self):
        created = await self.client.post(
            "/api/admin/users",
            json={
                "phone": "13900000010",
                "password": "demo123",
                "full_name": "手机号修改测试",
                "target_exam": "执业资格",
            },
            headers=self.admin_headers,
        )
        self.assertEqual(created.status_code, 200, created.text)

        login = await self.client.post(
            "/api/auth/login",
            data={"username": "13900000010", "password": "demo123"},
        )
        self.assertEqual(login.status_code, 200, login.text)
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

        invalid_phone = await self.client.put(
            "/api/auth/me",
            json={"phone": "abc"},
            headers=headers,
        )
        duplicate_phone = await self.client.put(
            "/api/auth/me",
            json={"phone": "13800000000"},
            headers=headers,
        )
        updated = await self.client.put(
            "/api/auth/me",
            json={"phone": "13900000011"},
            headers=headers,
        )
        self.assertEqual(invalid_phone.status_code, 422, invalid_phone.text)
        self.assertEqual(duplicate_phone.status_code, 400, duplicate_phone.text)
        self.assertEqual(updated.status_code, 200, updated.text)
        self.assertEqual(updated.json()["username"], "13900000011")
        self.assertEqual(updated.json()["phone"], "13900000011")
        self.assertEqual(updated.json()["email"], "13900000011@phone.medexam.cn")

        old_login = await self.client.post(
            "/api/auth/login",
            data={"username": "13900000010", "password": "demo123"},
        )
        new_login = await self.client.post(
            "/api/auth/login",
            data={"username": "13900000011", "password": "demo123"},
        )
        self.assertEqual(old_login.status_code, 401, old_login.text)
        self.assertEqual(new_login.status_code, 200, new_login.text)

    async def test_student_and_admin_tokens_are_not_interchangeable(self):
        student_on_admin = await self.client.get(
            "/api/admin/auth/me", headers=self.user_headers
        )
        admin_on_student = await self.client.get(
            "/api/auth/me", headers=self.admin_headers
        )
        self.assertEqual(student_on_admin.status_code, 401, student_on_admin.text)
        self.assertEqual(admin_on_student.status_code, 401, admin_on_student.text)

    async def test_admin_questions_filter_by_exam_category(self):
        chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "高级职称"}
        )
        self.assertEqual(chapters.status_code, 200, chapters.text)
        self.assertTrue(chapters.json())
        senior_chapter_id = chapters.json()[0]["id"]
        created = await self.client.post(
            "/api/admin/questions",
            json={
                "chapter_id": senior_chapter_id,
                "question_type": "single",
                "content": "高级职称分类过滤测试题",
                "options": {"A": "正确", "B": "错误"},
                "answer": "A",
                "explanation": "用于验证后台题库按考试科目过滤。",
                "difficulty": 2,
                "is_real_exam": False,
                "tags": ["高级职称", "分类过滤"],
            },
            headers=self.admin_headers,
        )
        self.assertEqual(created.status_code, 200, created.text)

        licensed = await self.client.get(
            "/api/admin/questions",
            params={"exam_category": "执业资格"},
            headers=self.admin_headers,
        )
        senior = await self.client.get(
            "/api/admin/questions",
            params={"exam_category": "高级职称"},
            headers=self.admin_headers,
        )
        self.assertEqual(licensed.status_code, 200, licensed.text)
        self.assertEqual(senior.status_code, 200, senior.text)
        self.assertTrue(licensed.json())
        self.assertTrue(senior.json())
        self.assertTrue(
            all("高级职称" in question["tags"] for question in senior.json())
        )

        matching_chapter = await self.client.get(
            "/api/admin/questions",
            params={
                "chapter_id": senior_chapter_id,
                "exam_category": "高级职称",
            },
            headers=self.admin_headers,
        )
        mismatched_chapter = await self.client.get(
            "/api/admin/questions",
            params={
                "chapter_id": senior_chapter_id,
                "exam_category": "执业资格",
            },
            headers=self.admin_headers,
        )
        self.assertEqual(matching_chapter.status_code, 200, matching_chapter.text)
        self.assertEqual(
            mismatched_chapter.status_code, 200, mismatched_chapter.text
        )
        self.assertTrue(
            any(item["id"] == created.json()["id"] for item in matching_chapter.json())
        )
        self.assertEqual(mismatched_chapter.json(), [])

    async def test_question_catalog_filters_by_exam_category(self):
        junior_chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "初级职称"}
        )
        senior_chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "高级职称"}
        )
        self.assertEqual(senior_chapters.status_code, 200, senior_chapters.text)
        self.assertTrue(senior_chapters.json())
        created = await self.client.post(
            "/api/admin/questions",
            json={
                "chapter_id": senior_chapters.json()[0]["id"],
                "question_type": "single",
                "content": "高级职称客户端过滤测试题",
                "options": {"A": "正确", "B": "错误"},
                "answer": "A",
                "difficulty": 2,
                "tags": ["高级职称", "客户端过滤"],
            },
            headers=self.admin_headers,
        )
        self.assertEqual(created.status_code, 200, created.text)
        senior_questions = await self.client.get(
            "/api/questions/practice", params={"exam_category": "高级职称"}
        )
        self.assertEqual(junior_chapters.status_code, 200, junior_chapters.text)
        self.assertEqual(senior_questions.status_code, 200, senior_questions.text)
        self.assertTrue(junior_chapters.json())
        self.assertTrue(
            all(chapter["exam_category"] == "初级职称" for chapter in junior_chapters.json())
        )
        self.assertTrue(senior_questions.json())
        self.assertTrue(
            all("高级职称" in question["tags"] for question in senior_questions.json())
        )

    async def test_public_question_endpoints_normalize_category_and_validate_query(self):
        canonical_chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "执业资格"}
        )
        alias_chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "执业医师"}
        )
        self.assertEqual(canonical_chapters.status_code, 200, canonical_chapters.text)
        self.assertEqual(alias_chapters.status_code, 200, alias_chapters.text)
        self.assertEqual(
            [item["id"] for item in alias_chapters.json()],
            [item["id"] for item in canonical_chapters.json()],
        )

        alias_practice = await self.client.get(
            "/api/questions/practice",
            params={"exam_category": "助理医师", "limit": 3},
        )
        bad_mode = await self.client.get(
            "/api/questions/practice",
            params={"exam_category": "执业资格", "mode": "unknown"},
        )
        bad_limit = await self.client.get(
            "/api/questions/practice",
            params={"exam_category": "执业资格", "limit": 0},
        )
        mismatched_chapter_practice = await self.client.get(
            "/api/questions/practice",
            params={
                "exam_category": "初级职称",
                "chapter_id": canonical_chapters.json()[0]["id"],
                "mode": "chapter",
            },
        )
        alias_exam = await self.client.get(
            "/api/questions/exam",
            params={"exam_category": "执业医师", "question_count": 2},
        )
        count_alias_exam = await self.client.get(
            "/api/questions/exam",
            params={"exam_category": "执业资格", "count": 3},
        )
        bad_exam_count = await self.client.get(
            "/api/questions/exam",
            params={"exam_category": "执业资格", "count": 0},
        )
        alias_exam_count = await self.client.get(
            "/api/questions/exam/count",
            params={"exam_category": "执业医师"},
        )
        junior_exam_chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "初级职称"}
        )
        junior_exam = await self.client.get(
            "/api/questions/exam",
            params={"exam_category": "初级职称", "question_count": 2},
        )
        junior_exam_count = await self.client.get(
            "/api/questions/exam/count",
            params={"exam_category": "初级职称"},
        )
        invalid_exam_count = await self.client.get(
            "/api/questions/exam/count",
            params={"exam_category": "junior"},
        )
        self.assertEqual(alias_practice.status_code, 200, alias_practice.text)
        self.assertTrue(alias_practice.json())
        self.assertEqual(bad_mode.status_code, 400)
        self.assertEqual(bad_limit.status_code, 422)
        self.assertEqual(
            mismatched_chapter_practice.status_code,
            200,
            mismatched_chapter_practice.text,
        )
        self.assertEqual(mismatched_chapter_practice.json(), [])
        self.assertEqual(alias_exam.status_code, 200, alias_exam.text)
        self.assertEqual(count_alias_exam.status_code, 200, count_alias_exam.text)
        self.assertLessEqual(len(count_alias_exam.json()), 3)
        self.assertEqual(bad_exam_count.status_code, 422)
        self.assertEqual(alias_exam_count.status_code, 200, alias_exam_count.text)
        self.assertGreaterEqual(alias_exam_count.json()["count"], len(alias_exam.json()))
        self.assertEqual(
            junior_exam_chapters.status_code, 200, junior_exam_chapters.text
        )
        self.assertEqual(junior_exam.status_code, 200, junior_exam.text)
        self.assertEqual(junior_exam_count.status_code, 200, junior_exam_count.text)
        self.assertEqual(invalid_exam_count.status_code, 200, invalid_exam_count.text)
        self.assertTrue(junior_exam.json())
        self.assertGreaterEqual(
            junior_exam_count.json()["count"], len(junior_exam.json())
        )
        self.assertEqual(invalid_exam_count.json()["count"], 0)
        junior_chapter_ids = {item["id"] for item in junior_exam_chapters.json()}
        self.assertTrue(
            all(item["chapter_id"] in junior_chapter_ids for item in junior_exam.json())
        )

        admin_alias_questions = await self.client.get(
            "/api/admin/questions",
            params={"exam_category": "执业医师"},
            headers=self.admin_headers,
        )
        admin_alias_courses = await self.client.get(
            "/api/admin/courses",
            params={"exam_category": "执业医师"},
            headers=self.admin_headers,
        )
        self.assertEqual(
            admin_alias_questions.status_code, 200, admin_alias_questions.text
        )
        self.assertEqual(admin_alias_courses.status_code, 200, admin_alias_courses.text)
        self.assertTrue(admin_alias_questions.json())
        self.assertTrue(admin_alias_courses.json())

    async def test_admin_exam_category_crud_creates_default_chapter(self):
        suffix = datetime.now().strftime("%H%M%S%f")
        name = f"自动化测试类别{suffix}"
        renamed = f"自动化测试类别更新{suffix}"

        listed = await self.client.get(
            "/api/admin/exam-categories", headers=self.admin_headers
        )
        self.assertEqual(listed.status_code, 200, listed.text)
        self.assertIn("执业资格", [item["name"] for item in listed.json()])
        self.assertIn("临床执业医师", [item["name"] for item in listed.json()])
        self.assertIn(3, [item["level"] for item in listed.json()])

        root = await self.client.post(
            "/api/admin/exam-categories",
            json={
                "name": f"{name}一级",
                "level": 1,
                "description": "接口自动化创建一级",
                "sort_order": 990,
                "is_active": True,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(root.status_code, 200, root.text)
        section = await self.client.post(
            "/api/admin/exam-categories",
            json={
                "name": f"{name}二级",
                "parent_id": root.json()["id"],
                "level": 2,
                "description": "接口自动化创建二级",
                "sort_order": 991,
                "is_active": True,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(section.status_code, 200, section.text)
        created = await self.client.post(
            "/api/admin/exam-categories",
            json={
                "name": name,
                "parent_id": section.json()["id"],
                "level": 3,
                "description": "接口自动化创建三级",
                "sort_order": 992,
                "is_active": True,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(created.status_code, 200, created.text)
        category_id = created.json()["id"]

        chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": name}
        )
        self.assertEqual(chapters.status_code, 200, chapters.text)
        self.assertTrue(chapters.json())
        self.assertEqual(chapters.json()[0]["exam_category"], name)

        updated = await self.client.put(
            f"/api/admin/exam-categories/{category_id}",
            json={"name": renamed, "description": "已更新", "sort_order": 1000},
            headers=self.admin_headers,
        )
        self.assertEqual(updated.status_code, 200, updated.text)
        self.assertEqual(updated.json()["name"], renamed)

        renamed_chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": renamed}
        )
        self.assertEqual(renamed_chapters.status_code, 200, renamed_chapters.text)
        self.assertTrue(renamed_chapters.json())

        deleted = await self.client.delete(
            f"/api/admin/exam-categories/{category_id}",
            headers=self.admin_headers,
        )
        self.assertEqual(deleted.status_code, 200, deleted.text)
        deleted_section = await self.client.delete(
            f"/api/admin/exam-categories/{section.json()['id']}",
            headers=self.admin_headers,
        )
        self.assertEqual(deleted_section.status_code, 200, deleted_section.text)
        deleted_root = await self.client.delete(
            f"/api/admin/exam-categories/{root.json()['id']}",
            headers=self.admin_headers,
        )
        self.assertEqual(deleted_root.status_code, 200, deleted_root.text)

    async def test_admin_question_rejects_invalid_chapter_and_answer(self):
        bad_chapter = await self.client.post(
            "/api/admin/questions",
            json={
                "chapter_id": 999999,
                "question_type": "single",
                "content": "无效章节题",
                "options": {"A": "对", "B": "错"},
                "answer": "A",
                "difficulty": 3,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(bad_chapter.status_code, 400)

        chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "执业资格"}
        )
        chapter_id = chapters.json()[0]["id"]
        bad_answer = await self.client.post(
            "/api/admin/questions",
            json={
                "chapter_id": chapter_id,
                "question_type": "single",
                "content": "答案不在选项中的题",
                "options": {"A": "对", "B": "错"},
                "answer": "C",
                "difficulty": 3,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(bad_answer.status_code, 422)

        created = await self.client.post(
            "/api/admin/questions",
            json={
                "chapter_id": chapter_id,
                "question_type": "single",
                "content": "更新答案校验题",
                "options": {"A": "对", "B": "错"},
                "answer": "A",
                "difficulty": 3,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(created.status_code, 200, created.text)
        bad_update = await self.client.put(
            f"/api/admin/questions/{created.json()['id']}",
            json={"options": {"B": "错", "C": "不确定"}},
            headers=self.admin_headers,
        )
        self.assertEqual(bad_update.status_code, 400)

    async def test_admin_course_rejects_invalid_shape(self):
        invalid_type = await self.client.post(
            "/api/admin/courses",
            json={
                "title": "非法课程类型",
                "course_type": "audio",
                "exam_category": "执业资格",
                "teacher": "测试讲师",
                "schedule": "随到随学",
                "lesson_count": 1,
                "is_published": True,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(invalid_type.status_code, 422)

        invalid_lessons = await self.client.post(
            "/api/admin/courses",
            json={
                "title": "非法课时课程",
                "course_type": "recorded",
                "exam_category": "执业资格",
                "teacher": "测试讲师",
                "schedule": "随到随学",
                "lesson_count": 0,
                "is_published": True,
            },
            headers=self.admin_headers,
        )
        self.assertEqual(invalid_lessons.status_code, 422)

    async def test_hot_tag_practice_auto_selects_tags_by_exam_category(self):
        response = await self.client.get(
            "/api/questions/practice",
            params={
                "exam_category": "执业资格",
                "mode": "tag",
                "limit": 5,
            },
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertTrue(response.json())
        self.assertTrue(
            all(question["tags"] for question in response.json())
        )

    async def test_submit_tracks_time_and_deduplicates_wrong_book(self):
        questions = await self.client.get("/api/questions/practice", params={"limit": 1})
        question = questions.json()[0]
        wrong_answer = next(
            key for key in question["options"] if key != question["answer"]
        )
        payload = {
            "question_id": question["id"],
            "selected_answer": f" {wrong_answer.lower()} ",
            "time_spent": 17,
        }
        for _ in range(2):
            response = await self.client.post(
                "/api/questions/submit", json=payload, headers=self.user_headers
            )
            self.assertEqual(response.status_code, 200, response.text)
            self.assertFalse(response.json()["is_correct"])

        stats = await self.client.get(
            "/api/study/stats/today", headers=self.user_headers
        )
        wrongs = await self.client.get("/api/study/wrong", headers=self.user_headers)
        self.assertEqual(stats.json()["total_questions"], 2)
        self.assertEqual(stats.json()["time_spent"], 34)
        self.assertEqual(len(wrongs.json()), 1)

    async def test_answering_wrong_question_correctly_updates_review_progress(self):
        questions = await self.client.get(
            "/api/questions/practice",
            params={"exam_category": "执业资格", "limit": 1},
        )
        self.assertEqual(questions.status_code, 200, questions.text)
        question = questions.json()[0]
        wrong_answer = next(
            key for key in question["options"] if key != question["answer"]
        )
        first_wrong = await self.client.post(
            "/api/questions/submit",
            json={
                "question_id": question["id"],
                "selected_answer": wrong_answer,
                "time_spent": 5,
            },
            headers=self.user_headers,
        )
        self.assertEqual(first_wrong.status_code, 200, first_wrong.text)
        self.assertFalse(first_wrong.json()["is_correct"])

        for _ in range(3):
            reviewed = await self.client.post(
                "/api/questions/submit",
                json={
                    "question_id": question["id"],
                    "selected_answer": question["answer"],
                    "time_spent": 5,
                },
                headers=self.user_headers,
            )
            self.assertEqual(reviewed.status_code, 200, reviewed.text)
            self.assertTrue(reviewed.json()["is_correct"])

        async with AsyncSessionLocal() as db:
            wrong = (
                await db.execute(
                    select(WrongQuestion).where(
                        WrongQuestion.question_id == question["id"]
                    )
                )
            ).scalar_one()
            self.assertEqual(wrong.review_count, 3)
            self.assertTrue(wrong.is_mastered)
            self.assertIsNotNone(wrong.last_reviewed_at)

        wrong_practice = await self.client.get(
            "/api/questions/practice",
            params={"exam_category": "执业资格", "mode": "wrong"},
            headers=self.user_headers,
        )
        self.assertEqual(wrong_practice.status_code, 200, wrong_practice.text)
        self.assertNotIn(
            question["id"], [item["id"] for item in wrong_practice.json()]
        )

    async def test_today_stats_can_be_filtered_by_exam_category(self):
        licensed = await self.client.get(
            "/api/questions/practice",
            params={"exam_category": "执业资格", "limit": 1},
        )
        junior = await self.client.get(
            "/api/questions/practice",
            params={"exam_category": "初级职称", "limit": 1},
        )
        self.assertEqual(licensed.status_code, 200, licensed.text)
        self.assertEqual(junior.status_code, 200, junior.text)
        self.assertTrue(licensed.json())
        self.assertTrue(junior.json())

        licensed_question = licensed.json()[0]
        junior_question = junior.json()[0]
        for question in (licensed_question, junior_question):
            submitted = await self.client.post(
                "/api/questions/submit",
                json={
                    "question_id": question["id"],
                    "selected_answer": question["answer"],
                    "time_spent": 11,
                },
                headers=self.user_headers,
            )
            self.assertEqual(submitted.status_code, 200, submitted.text)

        all_stats = await self.client.get(
            "/api/study/stats/today", headers=self.user_headers
        )
        licensed_stats = await self.client.get(
            "/api/study/stats/today",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        junior_stats = await self.client.get(
            "/api/study/stats/today",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        invalid_stats = await self.client.get(
            "/api/study/stats/today",
            params={"exam_category": "junior"},
            headers=self.user_headers,
        )

        self.assertEqual(all_stats.status_code, 200, all_stats.text)
        self.assertEqual(licensed_stats.status_code, 200, licensed_stats.text)
        self.assertEqual(junior_stats.status_code, 200, junior_stats.text)
        self.assertEqual(invalid_stats.status_code, 200, invalid_stats.text)
        self.assertEqual(all_stats.json()["total_questions"], 2)
        self.assertEqual(licensed_stats.json()["total_questions"], 1)
        self.assertEqual(junior_stats.json()["total_questions"], 1)
        self.assertEqual(invalid_stats.json()["total_questions"], 0)

    async def test_stats_overview_can_be_filtered_by_exam_category(self):
        licensed = await self.client.get(
            "/api/questions/practice",
            params={"exam_category": "执业资格", "limit": 1},
        )
        junior = await self.client.get(
            "/api/questions/practice",
            params={"exam_category": "初级职称", "limit": 1},
        )
        self.assertEqual(licensed.status_code, 200, licensed.text)
        self.assertEqual(junior.status_code, 200, junior.text)
        licensed_question = licensed.json()[0]
        junior_question = junior.json()[0]

        wrong_answer = "B" if junior_question["answer"] != "B" else "A"
        for question, answer in (
            (licensed_question, licensed_question["answer"]),
            (junior_question, wrong_answer),
        ):
            submitted = await self.client.post(
                "/api/questions/submit",
                json={
                    "question_id": question["id"],
                    "selected_answer": answer,
                    "time_spent": 11,
                },
                headers=self.user_headers,
            )
            self.assertEqual(submitted.status_code, 200, submitted.text)

        all_overview = await self.client.get(
            "/api/study/stats/overview", headers=self.user_headers
        )
        licensed_overview = await self.client.get(
            "/api/study/stats/overview",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        junior_overview = await self.client.get(
            "/api/study/stats/overview",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        invalid_overview = await self.client.get(
            "/api/study/stats/overview",
            params={"exam_category": "junior"},
            headers=self.user_headers,
        )

        self.assertEqual(all_overview.status_code, 200, all_overview.text)
        self.assertEqual(licensed_overview.status_code, 200, licensed_overview.text)
        self.assertEqual(junior_overview.status_code, 200, junior_overview.text)
        self.assertEqual(invalid_overview.status_code, 200, invalid_overview.text)
        self.assertEqual(all_overview.json()["total_questions"], 2)
        self.assertEqual(all_overview.json()["total_correct"], 1)
        self.assertEqual(licensed_overview.json()["total_questions"], 1)
        self.assertEqual(licensed_overview.json()["total_correct"], 1)
        self.assertEqual(junior_overview.json()["total_questions"], 1)
        self.assertEqual(junior_overview.json()["total_correct"], 0)
        self.assertEqual(invalid_overview.json()["total_questions"], 0)
        self.assertTrue(
            all(
                item["exam_category"] == "执业资格"
                for item in licensed_overview.json()["subject_stats"].values()
            )
        )
        self.assertTrue(
            all(
                item["exam_category"] == "初级职称"
                for item in junior_overview.json()["subject_stats"].values()
            )
        )

    async def test_study_plans_and_today_task_follow_exam_category(self):
        licensed_chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "执业资格"}
        )
        junior_chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "初级职称"}
        )
        self.assertEqual(licensed_chapters.status_code, 200, licensed_chapters.text)
        self.assertEqual(junior_chapters.status_code, 200, junior_chapters.text)
        licensed_ids = [item["id"] for item in licensed_chapters.json()]
        junior_ids = [item["id"] for item in junior_chapters.json()]
        self.assertTrue(licensed_ids)
        self.assertTrue(junior_ids)

        start = datetime.now()
        end = start + timedelta(days=30)
        licensed_plan = await self.client.post(
            "/api/study/plan",
            json={
                "title": "执业资格冲刺",
                "plan_type": "daily",
                "target_chapters": licensed_ids,
                "daily_questions": 31,
                "start_date": start.isoformat(),
                "end_date": end.isoformat(),
            },
            headers=self.user_headers,
        )
        junior_plan = await self.client.post(
            "/api/study/plan",
            json={
                "title": "初级职称冲刺",
                "plan_type": "daily",
                "target_chapters": junior_ids,
                "daily_questions": 21,
                "start_date": start.isoformat(),
                "end_date": end.isoformat(),
            },
            headers=self.user_headers,
        )
        senior_plan = await self.client.post(
            "/api/study/plan",
            json={
                "title": "高级职称每日目标",
                "plan_type": "daily",
                "exam_category": "高级职称",
                "target_chapters": [],
                "daily_questions": 11,
                "start_date": start.isoformat(),
                "end_date": end.isoformat(),
            },
            headers=self.user_headers,
        )
        self.assertEqual(licensed_plan.status_code, 200, licensed_plan.text)
        self.assertEqual(junior_plan.status_code, 200, junior_plan.text)
        self.assertEqual(senior_plan.status_code, 200, senior_plan.text)
        self.assertEqual(senior_plan.json()["exam_category"], "高级职称")

        licensed_plans = await self.client.get(
            "/api/study/plan",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        junior_plans = await self.client.get(
            "/api/study/plan",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        senior_plans = await self.client.get(
            "/api/study/plan",
            params={"exam_category": "高级职称"},
            headers=self.user_headers,
        )
        self.assertEqual(licensed_plans.status_code, 200, licensed_plans.text)
        self.assertEqual(junior_plans.status_code, 200, junior_plans.text)
        self.assertEqual(senior_plans.status_code, 200, senior_plans.text)
        self.assertEqual([item["title"] for item in licensed_plans.json()], ["执业资格冲刺"])
        self.assertEqual([item["title"] for item in junior_plans.json()], ["初级职称冲刺"])
        self.assertEqual([item["title"] for item in senior_plans.json()], ["高级职称每日目标"])
        self.assertTrue(licensed_plans.json()[0]["is_active"])
        self.assertTrue(junior_plans.json()[0]["is_active"])
        self.assertTrue(senior_plans.json()[0]["is_active"])

        licensed_task = await self.client.get(
            "/api/study/today",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        junior_task = await self.client.get(
            "/api/study/today",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        senior_task = await self.client.get(
            "/api/study/today",
            params={"exam_category": "高级职称"},
            headers=self.user_headers,
        )
        self.assertEqual(licensed_task.status_code, 200, licensed_task.text)
        self.assertEqual(junior_task.status_code, 200, junior_task.text)
        self.assertEqual(senior_task.status_code, 200, senior_task.text)
        self.assertEqual(licensed_task.json()["target_questions"], 31)
        self.assertEqual(junior_task.json()["target_questions"], 21)
        self.assertEqual(senior_task.json()["target_questions"], 11)
        self.assertEqual(licensed_task.json()["exam_category"], "执业资格")
        self.assertEqual(junior_task.json()["exam_category"], "初级职称")
        self.assertEqual(senior_task.json()["exam_category"], "高级职称")
        self.assertNotEqual(licensed_task.json()["id"], junior_task.json()["id"])
        self.assertEqual(licensed_task.json()["target_chapters"], licensed_ids)
        self.assertEqual(junior_task.json()["target_chapters"], junior_ids)
        self.assertEqual(senior_task.json()["plan_id"], senior_plan.json()["id"])
        self.assertEqual(senior_task.json()["target_chapters"], [])

    async def test_uncategorized_legacy_plan_stays_with_user_default_exam(self):
        junior_chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "初级职称"}
        )
        self.assertEqual(junior_chapters.status_code, 200, junior_chapters.text)
        junior_ids = [item["id"] for item in junior_chapters.json()]
        self.assertTrue(junior_ids)

        start = datetime.now()
        end = start + timedelta(days=30)
        legacy_plan = await self.client.post(
            "/api/study/plan",
            json={
                "title": "旧版无分类计划",
                "plan_type": "daily",
                "target_chapters": [],
                "daily_questions": 17,
                "start_date": start.isoformat(),
                "end_date": end.isoformat(),
            },
            headers=self.user_headers,
        )
        junior_plan = await self.client.post(
            "/api/study/plan",
            json={
                "title": "初级职称新计划",
                "plan_type": "daily",
                "target_chapters": junior_ids,
                "daily_questions": 23,
                "start_date": start.isoformat(),
                "end_date": end.isoformat(),
            },
            headers=self.user_headers,
        )
        self.assertEqual(legacy_plan.status_code, 200, legacy_plan.text)
        self.assertEqual(junior_plan.status_code, 200, junior_plan.text)

        licensed_plans = await self.client.get(
            "/api/study/plan",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        junior_plans = await self.client.get(
            "/api/study/plan",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        self.assertEqual(
            [(item["title"], item["is_active"]) for item in licensed_plans.json()],
            [("旧版无分类计划", True)],
        )
        self.assertEqual(
            [(item["title"], item["is_active"]) for item in junior_plans.json()],
            [("初级职称新计划", True)],
        )

    async def test_stats_overview_uses_real_records_for_trend_and_subjects(self):
        questions = await self.client.get("/api/questions/practice", params={"limit": 1})
        question = questions.json()[0]
        response = await self.client.post(
            "/api/questions/submit",
            json={
                "question_id": question["id"],
                "selected_answer": question["answer"],
                "time_spent": 9,
            },
            headers=self.user_headers,
        )
        self.assertEqual(response.status_code, 200, response.text)

        overview = await self.client.get(
            "/api/study/stats/overview", headers=self.user_headers
        )
        self.assertEqual(overview.status_code, 200, overview.text)
        body = overview.json()
        self.assertEqual(body["total_questions"], 1)
        self.assertEqual(body["total_correct"], 1)
        self.assertTrue(body["accuracy_trend"])
        self.assertTrue(body["subject_stats"])
        first_subject = next(iter(body["subject_stats"].values()))
        self.assertEqual(first_subject["total_questions"], 1)
        self.assertEqual(first_subject["correct_count"], 1)

    async def test_stats_overview_keeps_same_named_chapters_separate(self):
        async with AsyncSessionLocal() as db:
            user = (
                await db.execute(select(User).where(User.username == "13800000000"))
            ).scalar_one()
            first = Chapter(name="同名统计章节", exam_category="执业资格", order=901)
            second = Chapter(name="同名统计章节", exam_category="初级职称", order=902)
            db.add_all([first, second])
            await db.flush()
            q1 = Question(
                chapter_id=first.id,
                content="同名章节统计测试题 1",
                options={"A": "对", "B": "错"},
                answer="A",
                explanation="测试",
                difficulty=1,
                知识点=["统计测试"],
            )
            q2 = Question(
                chapter_id=second.id,
                content="同名章节统计测试题 2",
                options={"A": "对", "B": "错"},
                answer="A",
                explanation="测试",
                difficulty=1,
                知识点=["统计测试"],
            )
            db.add_all([q1, q2])
            await db.flush()
            db.add_all(
                [
                    QuestionRecord(
                        user_id=user.id,
                        question_id=q1.id,
                        selected_answer="A",
                        is_correct=True,
                        is_wrong=False,
                        time_spent=8,
                    ),
                    QuestionRecord(
                        user_id=user.id,
                        question_id=q2.id,
                        selected_answer="B",
                        is_correct=False,
                        is_wrong=True,
                        time_spent=9,
                    ),
                ]
            )
            await db.commit()

        overview = await self.client.get(
            "/api/study/stats/overview", headers=self.user_headers
        )
        self.assertEqual(overview.status_code, 200, overview.text)
        subject_stats = overview.json()["subject_stats"]
        matched = [
            item
            for item in subject_stats.values()
            if item.get("name") == "同名统计章节"
        ]
        self.assertEqual(len(matched), 2)
        self.assertEqual(
            {item["exam_category"] for item in matched},
            {"执业资格", "初级职称"},
        )

    async def test_study_prescription_filters_wrong_questions_by_exam_category(self):
        async with AsyncSessionLocal() as db:
            user = (
                await db.execute(select(User).where(User.username == "13800000000"))
            ).scalar_one()
            licensed_question = (
                await db.execute(
                    select(Question)
                    .join(Chapter, Question.chapter_id == Chapter.id)
                    .where(Chapter.exam_category == "执业资格")
                    .limit(1)
                )
            ).scalar_one()
            db.add(
                WrongQuestion(
                    user_id=user.id,
                    question_id=licensed_question.id,
                    wrong_reason="概念不清",
                    is_mastered=False,
                )
            )
            db.add(
                StudyStats(
                    user_id=user.id,
                    date=datetime.now().strftime("%Y-%m-%d"),
                    total_questions=5,
                    correct_count=2,
                    wrong_count=3,
                    accuracy_rate=0.4,
                    time_spent=120,
                )
            )
            await db.commit()

        prescription = await self.client.get(
            "/api/study/prescription",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        self.assertEqual(prescription.status_code, 200, prescription.text)
        self.assertNotEqual(prescription.json()["recommended_mode"], "wrong")

    async def test_study_prescription_uses_exam_category_today_records(self):
        async with AsyncSessionLocal() as db:
            user = (
                await db.execute(select(User).where(User.username == "13800000000"))
            ).scalar_one()
            licensed_question = (
                await db.execute(
                    select(Question)
                    .join(Chapter, Question.chapter_id == Chapter.id)
                    .where(Chapter.exam_category == "执业资格")
                    .limit(1)
                )
            ).scalar_one()
            junior_question = (
                await db.execute(
                    select(Question)
                    .join(Chapter, Question.chapter_id == Chapter.id)
                    .where(Chapter.exam_category == "初级职称")
                    .limit(1)
                )
            ).scalar_one()
            db.add_all(
                [
                    QuestionRecord(
                        user_id=user.id,
                        question_id=licensed_question.id,
                        selected_answer=licensed_question.answer,
                        is_correct=True,
                        is_wrong=False,
                        time_spent=12,
                    ),
                    QuestionRecord(
                        user_id=user.id,
                        question_id=junior_question.id,
                        selected_answer="B"
                        if junior_question.answer != "B"
                        else "A",
                        is_correct=False,
                        is_wrong=True,
                        time_spent=20,
                    ),
                ]
            )
            db.add(
                StudyStats(
                    user_id=user.id,
                    date=datetime.now().strftime("%Y-%m-%d"),
                    total_questions=2,
                    correct_count=1,
                    wrong_count=1,
                    accuracy_rate=0.5,
                    time_spent=32,
                )
            )
            await db.commit()

        licensed = await self.client.get(
            "/api/study/prescription",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        junior = await self.client.get(
            "/api/study/prescription",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        invalid = await self.client.get(
            "/api/study/prescription",
            params={"exam_category": "junior"},
            headers=self.user_headers,
        )
        self.assertEqual(licensed.status_code, 200, licensed.text)
        self.assertEqual(junior.status_code, 200, junior.text)
        self.assertEqual(invalid.status_code, 200, invalid.text)
        self.assertEqual(licensed.json()["completed_questions"], 1)
        self.assertEqual(licensed.json()["accuracy_rate"], 1.0)
        self.assertEqual(licensed.json()["time_spent"], 12)
        self.assertEqual(junior.json()["completed_questions"], 1)
        self.assertEqual(junior.json()["accuracy_rate"], 0.0)
        self.assertEqual(junior.json()["time_spent"], 20)
        self.assertEqual(invalid.json()["completed_questions"], 0)

    async def test_wrong_book_filters_by_exam_category(self):
        async with AsyncSessionLocal() as db:
            user = (
                await db.execute(select(User).where(User.username == "13800000000"))
            ).scalar_one()
            licensed_question = (
                await db.execute(
                    select(Question)
                    .join(Chapter, Question.chapter_id == Chapter.id)
                    .where(Chapter.exam_category == "执业资格")
                    .limit(1)
                )
            ).scalar_one()
            junior_question = (
                await db.execute(
                    select(Question)
                    .join(Chapter, Question.chapter_id == Chapter.id)
                    .where(Chapter.exam_category == "初级职称")
                    .limit(1)
                )
            ).scalar_one()
            db.add_all(
                [
                    WrongQuestion(
                        user_id=user.id,
                        question_id=licensed_question.id,
                        wrong_reason="概念不清",
                        is_mastered=False,
                    ),
                    WrongQuestion(
                        user_id=user.id,
                        question_id=junior_question.id,
                        wrong_reason="记忆模糊",
                        is_mastered=False,
                    ),
                ]
            )
            await db.commit()

        licensed_wrongs = await self.client.get(
            "/api/study/wrong",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        junior_wrongs = await self.client.get(
            "/api/study/wrong",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        self.assertEqual(licensed_wrongs.status_code, 200, licensed_wrongs.text)
        self.assertEqual(junior_wrongs.status_code, 200, junior_wrongs.text)
        self.assertEqual(
            [item["question_id"] for item in licensed_wrongs.json()],
            [licensed_question.id],
        )
        self.assertEqual(
            [item["question_id"] for item in junior_wrongs.json()],
            [junior_question.id],
        )

        licensed_calendar = await self.client.get(
            "/api/study/wrong/calendar",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        junior_plan = await self.client.get(
            "/api/study/wrong/review-plan",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        self.assertEqual(licensed_calendar.status_code, 200, licensed_calendar.text)
        self.assertEqual(junior_plan.status_code, 200, junior_plan.text)
        self.assertEqual(licensed_calendar.json()["total_wrong"], 1)
        self.assertIn("记忆模糊", [item["label"] for item in junior_plan.json()["focus_reasons"]])

        invalid_wrongs = await self.client.get(
            "/api/study/wrong",
            params={"exam_category": "junior"},
            headers=self.user_headers,
        )
        invalid_calendar = await self.client.get(
            "/api/study/wrong/calendar",
            params={"exam_category": "junior"},
            headers=self.user_headers,
        )
        invalid_plan = await self.client.get(
            "/api/study/wrong/review-plan",
            params={"exam_category": "junior"},
            headers=self.user_headers,
        )
        self.assertEqual(invalid_wrongs.status_code, 200, invalid_wrongs.text)
        self.assertEqual(invalid_calendar.status_code, 200, invalid_calendar.text)
        self.assertEqual(invalid_plan.status_code, 200, invalid_plan.text)
        self.assertEqual(invalid_wrongs.json(), [])
        self.assertEqual(invalid_calendar.json()["total_wrong"], 0)
        self.assertEqual(invalid_plan.json()["suggested_count"], 0)
        self.assertEqual(invalid_plan.json()["focus_reasons"], [])

    async def test_practice_wrong_can_be_limited_to_specific_question_ids(self):
        async with AsyncSessionLocal() as db:
            user = (
                await db.execute(select(User).where(User.username == "13800000000"))
            ).scalar_one()
            questions = (
                await db.execute(
                    select(Question)
                    .join(Chapter, Question.chapter_id == Chapter.id)
                    .where(Chapter.exam_category == "执业资格")
                    .limit(2)
                )
            ).scalars().all()
            junior_question = (
                await db.execute(
                    select(Question)
                    .join(Chapter, Question.chapter_id == Chapter.id)
                    .where(Chapter.exam_category == "初级职称")
                    .limit(1)
                )
            ).scalar_one()
            self.assertGreaterEqual(len(questions), 2)
            db.add_all(
                [
                    WrongQuestion(
                        user_id=user.id,
                        question_id=questions[0].id,
                        wrong_reason="概念不清",
                        is_mastered=False,
                    ),
                    WrongQuestion(
                        user_id=user.id,
                        question_id=questions[1].id,
                        wrong_reason="粗心大意",
                        is_mastered=False,
                    ),
                    WrongQuestion(
                        user_id=user.id,
                        question_id=junior_question.id,
                        wrong_reason="记忆模糊",
                        is_mastered=False,
                    ),
                ]
            )
            await db.commit()

        scoped = await self.client.get(
            "/api/questions/practice",
            params={
                "mode": "wrong",
                "exam_category": "执业资格",
                "question_ids": str(questions[0].id),
            },
            headers=self.user_headers,
        )
        category_scoped = await self.client.get(
            "/api/questions/practice",
            params={"mode": "wrong", "exam_category": "执业资格", "limit": 20},
            headers=self.user_headers,
        )
        invalid = await self.client.get(
            "/api/questions/practice",
            params={"mode": "wrong", "question_ids": "abc"},
            headers=self.user_headers,
        )
        self.assertEqual(scoped.status_code, 200, scoped.text)
        self.assertEqual(category_scoped.status_code, 200, category_scoped.text)
        self.assertEqual([item["id"] for item in scoped.json()], [questions[0].id])
        category_ids = {item["id"] for item in category_scoped.json()}
        self.assertIn(questions[0].id, category_ids)
        self.assertIn(questions[1].id, category_ids)
        self.assertNotIn(junior_question.id, category_ids)
        self.assertEqual(invalid.status_code, 400)

    async def test_new_plan_deactivates_previous_and_validates_dates(self):
        start = datetime.now()
        first = await self._create_plan("第一阶段", start, start + timedelta(days=7))
        second = await self._create_plan("第二阶段", start, start + timedelta(days=14))
        self.assertEqual(first.status_code, 200, first.text)
        self.assertEqual(second.status_code, 200, second.text)

        plans = await self.client.get("/api/study/plan", headers=self.user_headers)
        active = [plan for plan in plans.json() if plan["is_active"]]
        self.assertEqual([plan["title"] for plan in active], ["第二阶段"])

        invalid = await self._create_plan(
            "错误日期", start, start - timedelta(days=1)
        )
        self.assertEqual(invalid.status_code, 400)

    async def test_wrong_review_accepts_client_contract(self):
        questions = await self.client.get("/api/questions/practice", params={"limit": 1})
        question = questions.json()[0]
        wrong_answer = next(
            key for key in question["options"] if key != question["answer"]
        )
        await self.client.post(
            "/api/questions/submit",
            json={"question_id": question["id"], "selected_answer": wrong_answer},
            headers=self.user_headers,
        )
        wrong = (await self.client.get(
            "/api/study/wrong", headers=self.user_headers
        )).json()[0]
        reviewed = await self.client.post(
            f"/api/study/wrong/{wrong['id']}/review",
            params={"is_correct": "true"},
            headers=self.user_headers,
        )
        self.assertEqual(reviewed.status_code, 200, reviewed.text)

    async def test_wrong_calendar_and_review_plan_after_wrong_answer(self):
        questions = await self.client.get("/api/questions/practice", params={"limit": 1})
        question = questions.json()[0]
        wrong_answer = next(
            key for key in question["options"] if key != question["answer"]
        )
        submitted = await self.client.post(
            "/api/questions/submit",
            json={
                "question_id": question["id"],
                "selected_answer": wrong_answer,
                "time_spent": 30,
            },
            headers=self.user_headers,
        )
        self.assertEqual(submitted.status_code, 200, submitted.text)

        calendar = await self.client.get(
            "/api/study/wrong/calendar", headers=self.user_headers
        )
        plan = await self.client.get(
            "/api/study/wrong/review-plan", headers=self.user_headers
        )
        self.assertEqual(calendar.status_code, 200, calendar.text)
        self.assertEqual(plan.status_code, 200, plan.text)
        self.assertGreaterEqual(calendar.json()["total_wrong"], 1)
        self.assertTrue(calendar.json()["upcoming"])
        self.assertTrue(plan.json()["title"])
        self.assertTrue(plan.json()["actions"])

    async def test_wrong_review_plan_uses_actionable_focus_tags(self):
        chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "执业资格"}
        )
        self.assertEqual(chapters.status_code, 200, chapters.text)
        chapter = chapters.json()[0]
        created = await self.client.post(
            "/api/admin/questions",
            json={
                "chapter_id": chapter["id"],
                "question_type": "single",
                "content": "泛标签错题复盘测试题",
                "options": {"A": "正确项", "B": "干扰项"},
                "answer": "A",
                "explanation": "用于验证错题复盘焦点不会展示考试大类。",
                "difficulty": 1,
                "tags": ["执业资格", "执业医师"],
            },
            headers=self.admin_headers,
        )
        self.assertEqual(created.status_code, 200, created.text)

        submitted = await self.client.post(
            "/api/questions/submit",
            json={
                "question_id": created.json()["id"],
                "selected_answer": "B",
                "time_spent": 20,
            },
            headers=self.user_headers,
        )
        self.assertEqual(submitted.status_code, 200, submitted.text)

        plan = await self.client.get(
            "/api/study/wrong/review-plan",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        self.assertEqual(plan.status_code, 200, plan.text)
        labels = [item["label"] for item in plan.json()["focus_tags"]]
        self.assertNotIn("执业资格", labels)
        self.assertNotIn("执业医师", labels)
        self.assertIn(chapter["name"], labels)

    async def test_ai_learning_tools_return_non_blocking_advice(self):
        before = await self.client.get(
            "/api/study/stats/today", headers=self.user_headers
        )
        self.assertEqual(before.status_code, 200, before.text)
        advice = await self.client.post(
            "/api/ai/study-advice",
            json={
                "exam_category": "执业资格",
                "today_stats": {"total_questions": 10, "accuracy_rate": 0.6},
                "weak_areas": [{"name": "消化系统", "wrong_count": 3}],
            },
            headers=self.user_headers,
        )
        wrong_explain = await self.client.post(
            "/api/ai/wrong-explain",
            json={
                "question_content": "消化性溃疡最重要的病因之一是？",
                "question_options": {"A": "幽门螺杆菌感染", "B": "维生素C缺乏"},
                "correct_answer": "A",
                "selected_answer": "B",
                "tags": ["消化系统"],
            },
            headers=self.user_headers,
        )
        exam_report = await self.client.post(
            "/api/ai/exam-report",
            json={
                "exam_category": "执业资格",
                "total_questions": 10,
                "correct_count": 6,
                "wrong_count": 4,
                "accuracy_rate": 0.6,
                "time_spent": 600,
                "weak_tags": {"消化系统": 2},
            },
            headers=self.user_headers,
        )
        for response in (advice, wrong_explain, exam_report):
            self.assertEqual(response.status_code, 200, response.text)
            body = response.json()
            self.assertTrue(body["title"])
            self.assertTrue(body["content"])
            self.assertTrue(body["actions"])
            self.assertTrue(body["session_id"])
            self.assertIsNotNone(body["user_message_id"])
            self.assertIsNotNone(body["assistant_message_id"])

        after = await self.client.get(
            "/api/study/stats/today", headers=self.user_headers
        )
        self.assertEqual(after.status_code, 200, after.text)
        self.assertEqual(
            after.json()["ai_questions"],
            before.json()["ai_questions"] + 3,
        )

        sessions = await self.client.get("/api/ai/sessions", headers=self.user_headers)
        self.assertEqual(sessions.status_code, 200, sessions.text)
        session_ids = {item["session_id"] for item in sessions.json()}
        self.assertIn(advice.json()["session_id"], session_ids)
        self.assertIn(wrong_explain.json()["session_id"], session_ids)
        self.assertIn(exam_report.json()["session_id"], session_ids)

        history = await self.client.get(
            "/api/ai/history",
            params={"session_id": wrong_explain.json()["session_id"]},
            headers=self.user_headers,
        )
        self.assertEqual(history.status_code, 200, history.text)
        self.assertTrue(
            any(
                item["id"] == wrong_explain.json()["assistant_message_id"]
                for item in history.json()
            )
        )
        collected = await self.client.post(
            f"/api/ai/{wrong_explain.json()['assistant_message_id']}/collect",
            headers=self.user_headers,
        )
        self.assertEqual(collected.status_code, 200, collected.text)
        self.assertTrue(collected.json()["is_collected"])

    async def test_ai_chat_increments_today_ai_question_count(self):
        before = await self.client.get(
            "/api/study/stats/today", headers=self.user_headers
        )
        self.assertEqual(before.status_code, 200, before.text)
        sent = await self.client.post(
            "/api/ai/chat",
            json={"content": "高血压诊断标准是什么？"},
            headers=self.user_headers,
        )
        after = await self.client.get(
            "/api/study/stats/today", headers=self.user_headers
        )
        self.assertEqual(sent.status_code, 200, sent.text)
        self.assertEqual(after.status_code, 200, after.text)
        self.assertEqual(
            after.json()["ai_questions"],
            before.json()["ai_questions"] + 1,
        )

    async def test_ai_chat_falls_back_when_model_call_fails(self):
        from app.api import ai_chat as ai_chat_module

        original_call_ai_model = ai_chat_module.call_ai_model

        async def failing_call_ai_model(messages):
            raise RuntimeError("model unavailable")

        ai_chat_module.call_ai_model = failing_call_ai_model
        try:
            sent = await self.client.post(
                "/api/ai/chat",
                json={"content": "模型异常时也应该能给用户兜底回复"},
                headers=self.user_headers,
            )
        finally:
            ai_chat_module.call_ai_model = original_call_ai_model

        self.assertEqual(sent.status_code, 200, sent.text)
        body = sent.json()
        self.assertIn("AI 未配置", body["answer"])
        self.assertIsNotNone(body["assistant_message_id"])

    async def test_ai_chat_times_out_slow_model_with_demo_fallback(self):
        from app.api import ai_chat as ai_chat_module
        from app.core import config

        original_key = config.settings.AI_API_KEY
        original_call_ai_model = ai_chat_module.call_ai_model
        original_timeout = ai_chat_module.AI_FALLBACK_TIMEOUT_SECONDS

        async def slow_call_ai_model(messages):
            await asyncio.sleep(0.05)
            return "不应该返回这个慢答案"

        config.settings.AI_API_KEY = "real-but-slow-test-key"
        ai_chat_module.call_ai_model = slow_call_ai_model
        ai_chat_module.AI_FALLBACK_TIMEOUT_SECONDS = 0.001
        try:
            sent = await self.client.post(
                "/api/ai/chat",
                json={
                    "content": "慢模型兜底测试",
                    "session_id": "slow-ai-fallback",
                    "exam_category": "执业资格",
                },
                headers=self.user_headers,
            )
        finally:
            config.settings.AI_API_KEY = original_key
            ai_chat_module.call_ai_model = original_call_ai_model
            ai_chat_module.AI_FALLBACK_TIMEOUT_SECONDS = original_timeout

        self.assertEqual(sent.status_code, 200, sent.text)
        body = sent.json()
        self.assertIn("AI 未配置", body["answer"])
        self.assertEqual(body["session_id"], "slow-ai-fallback")
        self.assertIsNotNone(body["assistant_message_id"])

    async def test_ai_chat_without_session_creates_fresh_sessions(self):
        first = await self.client.post(
            "/api/ai/chat",
            json={"content": "心力衰竭的分类有哪些？", "exam_category": "执业资格"},
            headers=self.user_headers,
        )
        second = await self.client.post(
            "/api/ai/chat",
            json={"content": "糖尿病诊断标准是什么？", "exam_category": "执业资格"},
            headers=self.user_headers,
        )
        self.assertEqual(first.status_code, 200, first.text)
        self.assertEqual(second.status_code, 200, second.text)
        self.assertNotEqual(first.json()["session_id"], second.json()["session_id"])
        self.assertTrue(first.json()["session_id"].startswith("chat-"))
        self.assertTrue(second.json()["session_id"].startswith("chat-"))

    async def test_ai_question_count_follows_exam_category(self):
        licensed_before = await self.client.get(
            "/api/study/stats/today",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        junior_before = await self.client.get(
            "/api/study/stats/today",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        self.assertEqual(licensed_before.status_code, 200, licensed_before.text)
        self.assertEqual(junior_before.status_code, 200, junior_before.text)

        sent = await self.client.post(
            "/api/ai/chat",
            json={
                "content": "初级职称常见病诊疗怎么复习？",
                "exam_category": "初级职称",
            },
            headers=self.user_headers,
        )
        self.assertEqual(sent.status_code, 200, sent.text)

        licensed_after = await self.client.get(
            "/api/study/stats/today",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        junior_after = await self.client.get(
            "/api/study/stats/today",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        self.assertEqual(licensed_after.status_code, 200, licensed_after.text)
        self.assertEqual(junior_after.status_code, 200, junior_after.text)
        self.assertEqual(
            licensed_after.json()["ai_questions"],
            licensed_before.json()["ai_questions"],
        )
        self.assertEqual(
            junior_after.json()["ai_questions"],
            junior_before.json()["ai_questions"] + 1,
        )

    async def test_ai_chat_returns_collectable_message_id_and_sessions(self):
        sent = await self.client.post(
            "/api/ai/chat",
            json={
                "content": "青霉素过敏性休克如何处理？",
                "session_id": "shock-review",
                "exam_category": "执业资格",
            },
            headers=self.user_headers,
        )
        self.assertEqual(sent.status_code, 200, sent.text)
        body = sent.json()
        self.assertEqual(body["session_id"], "shock-review")
        self.assertIsNotNone(body["user_message_id"])
        self.assertIsNotNone(body["assistant_message_id"])

        user_collect = await self.client.post(
            f"/api/ai/{body['user_message_id']}/collect",
            headers=self.user_headers,
        )
        self.assertEqual(user_collect.status_code, 400, user_collect.text)
        self.assertIn("AI 回复", user_collect.json()["detail"])

        collected = await self.client.post(
            f"/api/ai/{body['assistant_message_id']}/collect",
            headers=self.user_headers,
        )
        self.assertEqual(collected.status_code, 200, collected.text)
        self.assertTrue(collected.json()["is_collected"])

        sessions = await self.client.get("/api/ai/sessions", headers=self.user_headers)
        history = await self.client.get(
            "/api/ai/history",
            params={"session_id": body["session_id"]},
            headers=self.user_headers,
        )
        collections = await self.client.get(
            "/api/ai/collections",
            headers=self.user_headers,
        )
        self.assertEqual(sessions.status_code, 200, sessions.text)
        self.assertEqual(history.status_code, 200, history.text)
        self.assertEqual(collections.status_code, 200, collections.text)
        self.assertTrue(sessions.json())
        session = next(
            item for item in sessions.json() if item["session_id"] == "shock-review"
        )
        self.assertIn("青霉素过敏性休克", session["title"])
        self.assertEqual(session["exam_category"], "执业资格")
        self.assertEqual(session["collected_count"], 1)
        self.assertTrue(
            any(item["session_id"] == "shock-review" for item in sessions.json())
        )
        history_items = history.json()
        self.assertGreaterEqual(len(history_items), 2)
        self.assertEqual(history_items[0]["id"], body["user_message_id"])
        self.assertEqual(history_items[0]["message_type"], "user")
        self.assertEqual(history_items[1]["id"], body["assistant_message_id"])
        self.assertEqual(history_items[1]["message_type"], "assistant")
        assistant = next(
            item for item in history_items if item["id"] == body["assistant_message_id"]
        )
        self.assertTrue(assistant["is_collected"])
        self.assertEqual(assistant["exam_category"], "执业资格")
        self.assertTrue(
            any(item["id"] == body["assistant_message_id"] for item in collections.json())
        )
        collected_item = next(
            item for item in collections.json() if item["id"] == body["assistant_message_id"]
        )
        self.assertEqual(collected_item["exam_category"], "执业资格")

        dashboard = await self.client.get(
            "/api/admin/dashboard", headers=self.admin_headers
        )
        self.assertEqual(dashboard.status_code, 200, dashboard.text)
        self.assertGreaterEqual(dashboard.json()["today_ai_questions"], 1)
        self.assertGreaterEqual(dashboard.json()["ai_session_count"], 1)
        self.assertGreaterEqual(dashboard.json()["ai_collection_count"], 1)

    async def test_ai_sessions_and_collections_filter_by_exam_category(self):
        licensed = await self.client.post(
            "/api/ai/chat",
            json={
                "content": "执业资格 AI 分类过滤问题",
                "session_id": "licensed-ai-filter",
                "exam_category": "执业资格",
            },
            headers=self.user_headers,
        )
        junior = await self.client.post(
            "/api/ai/chat",
            json={
                "content": "初级职称 AI 分类过滤问题",
                "session_id": "junior-ai-filter",
                "exam_category": "初级职称",
            },
            headers=self.user_headers,
        )
        self.assertEqual(licensed.status_code, 200, licensed.text)
        self.assertEqual(junior.status_code, 200, junior.text)
        for body in (licensed.json(), junior.json()):
            collected = await self.client.post(
                f"/api/ai/{body['assistant_message_id']}/collect",
                headers=self.user_headers,
            )
            self.assertEqual(collected.status_code, 200, collected.text)

        licensed_sessions = await self.client.get(
            "/api/ai/sessions",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        junior_sessions = await self.client.get(
            "/api/ai/sessions",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        licensed_collections = await self.client.get(
            "/api/ai/collections",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        junior_collections = await self.client.get(
            "/api/ai/collections",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        self.assertEqual(licensed_sessions.status_code, 200, licensed_sessions.text)
        self.assertEqual(junior_sessions.status_code, 200, junior_sessions.text)
        self.assertEqual(
            licensed_collections.status_code, 200, licensed_collections.text
        )
        self.assertEqual(junior_collections.status_code, 200, junior_collections.text)
        self.assertTrue(
            any(item["session_id"] == "licensed-ai-filter" for item in licensed_sessions.json())
        )
        self.assertFalse(
            any(item["session_id"] == "junior-ai-filter" for item in licensed_sessions.json())
        )
        self.assertTrue(
            any(item["session_id"] == "junior-ai-filter" for item in junior_sessions.json())
        )
        self.assertFalse(
            any(item["session_id"] == "licensed-ai-filter" for item in junior_sessions.json())
        )
        self.assertTrue(
            all(item["exam_category"] == "执业资格" for item in licensed_collections.json())
        )
        self.assertTrue(
            all(item["exam_category"] == "初级职称" for item in junior_collections.json())
        )

    async def test_ai_study_advice_has_demo_fallback(self):
        invalid = await self.client.post(
            "/api/ai/study-advice",
            json={"exam_category": "junior"},
            headers=self.user_headers,
        )
        self.assertEqual(invalid.status_code, 400, invalid.text)

        alias = await self.client.post(
            "/api/ai/study-advice",
            json={"exam_category": "执业医师", "today_stats": {}},
            headers=self.user_headers,
        )
        self.assertEqual(alias.status_code, 200, alias.text)
        self.assertEqual(alias.json()["session_id"], "study-advice-执业资格")

        res = await self.client.post(
            "/api/ai/study-advice",
            json={
                "exam_category": "执业资格",
                "today_stats": {
                    "total_questions": 12,
                    "correct_count": 8,
                    "wrong_count": 4,
                    "accuracy_rate": 0.67,
                    "time_spent": 900,
                },
                "weak_areas": [
                    {
                        "chapter_id": 1,
                        "chapter_name": "循环系统",
                        "exam_category": "执业资格",
                        "practice_count": 10,
                        "wrong_count": 4,
                        "accuracy_rate": 0.6,
                        "status": "薄弱",
                    }
                ],
                "wrong_summary": {"pending_wrong_count": 4},
            },
            headers=self.user_headers,
        )
        self.assertEqual(res.status_code, 200, res.text)
        body = res.json()
        self.assertEqual(body["title"], "AI 今日学习教练")
        self.assertGreater(len(body["content"]), 20)
        self.assertTrue(body["actions"])
        self.assertIn("is_demo", body)

    async def test_ai_exam_report_rejects_invalid_exam_category_and_normalizes_alias(self):
        invalid = await self.client.post(
            "/api/ai/exam-report",
            json={
                "exam_category": "junior",
                "total_questions": 10,
                "correct_count": 6,
                "wrong_count": 4,
            },
            headers=self.user_headers,
        )
        self.assertEqual(invalid.status_code, 400, invalid.text)

        alias = await self.client.post(
            "/api/ai/exam-report",
            json={
                "exam_category": "助理医师",
                "total_questions": 10,
                "correct_count": 6,
                "wrong_count": 4,
                "accuracy_rate": 0.6,
            },
            headers=self.user_headers,
        )
        self.assertEqual(alias.status_code, 200, alias.text)
        self.assertEqual(alias.json()["session_id"], "exam-report-执业资格")

    async def test_exam_attempt_history_and_report_detail(self):
        questions = await self.client.get(
            "/api/questions/exam",
            params={"question_count": 2, "exam_category": "执业资格"},
        )
        self.assertEqual(questions.status_code, 200, questions.text)
        self.assertGreaterEqual(len(questions.json()), 2)
        payload = {
            "time_spent": 120,
            "answers": [
                {
                    "question_id": item["id"],
                    "selected_answer": item["answer"],
                }
                for item in questions.json()[:2]
            ],
        }
        submitted = await self.client.post(
            "/api/questions/exam/submit", json=payload, headers=self.user_headers
        )
        self.assertEqual(submitted.status_code, 200, submitted.text)
        attempt_id = submitted.json()["id"]
        self.assertIsNotNone(attempt_id)
        self.assertEqual(submitted.json()["attempt_id"], attempt_id)

        attempts = await self.client.get(
            "/api/questions/exam/attempts", headers=self.user_headers
        )
        detail = await self.client.get(
            f"/api/questions/exam/attempts/{attempt_id}",
            headers=self.user_headers,
        )
        self.assertEqual(attempts.status_code, 200, attempts.text)
        self.assertEqual(detail.status_code, 200, detail.text)
        self.assertTrue(
            any(item["id"] == attempt_id for item in attempts.json())
        )
        self.assertEqual(detail.json()["total_questions"], 2)
        self.assertEqual(detail.json()["attempt_id"], attempt_id)
        self.assertEqual(detail.json()["correct_count"], 2)
        self.assertTrue(detail.json()["results"][0]["chapter_name"])

    async def test_ai_exam_report_is_cached_on_attempt_detail(self):
        questions = await self.client.get(
            "/api/questions/exam",
            params={"question_count": 2, "exam_category": "执业资格"},
        )
        self.assertEqual(questions.status_code, 200, questions.text)
        self.assertGreaterEqual(len(questions.json()), 2)
        submitted = await self.client.post(
            "/api/questions/exam/submit",
            json={
                "time_spent": 90,
                "answers": [
                    {
                        "question_id": questions.json()[0]["id"],
                        "selected_answer": questions.json()[0]["answer"],
                    },
                    {
                        "question_id": questions.json()[1]["id"],
                        "selected_answer": None,
                    },
                ],
            },
            headers=self.user_headers,
        )
        self.assertEqual(submitted.status_code, 200, submitted.text)
        attempt_id = submitted.json()["id"]
        self.assertIsNone(submitted.json().get("ai_report"))

        generated = await self.client.post(
            "/api/ai/exam-report",
            json={
                "attempt_id": attempt_id,
                "exam_category": "执业资格",
                "total_questions": 2,
                "correct_count": 1,
                "wrong_count": 1,
                "unanswered_count": 1,
                "accuracy_rate": 0.5,
                "time_spent": 90,
                "weak_tags": {"基础医学综合": 1},
            },
            headers=self.user_headers,
        )
        self.assertEqual(generated.status_code, 200, generated.text)
        self.assertEqual(generated.json()["title"], "AI 模考报告")

        detail = await self.client.get(
            f"/api/questions/exam/attempts/{attempt_id}",
            headers=self.user_headers,
        )
        self.assertEqual(detail.status_code, 200, detail.text)
        ai_report = detail.json().get("ai_report")
        self.assertIsNotNone(ai_report)
        self.assertEqual(ai_report["title"], "AI 模考报告")
        self.assertEqual(ai_report["content"], generated.json()["content"])

        from app.api import deps as auth_deps

        auth_deps._sms_codes["13900009991"] = {
            "code": "123456",
            "purpose": "register",
            "expires_at": datetime.utcnow() + timedelta(minutes=5),
        }
        other_register = await self.client.post(
            "/api/auth/register",
            json={
                "username": "13900009991",
                "phone": "13900009991",
                "sms_code": "123456",
                "password": "demo123",
                "full_name": "模考越权测试用户",
                "target_exam": "执业资格",
            },
        )
        self.assertEqual(other_register.status_code, 200, other_register.text)
        other_login = await self.client.post(
            "/api/auth/login",
            data={"username": "13900009991", "password": "demo123"},
        )
        self.assertEqual(other_login.status_code, 200, other_login.text)
        other_headers = {
            "Authorization": f"Bearer {other_login.json()['access_token']}"
        }
        forbidden = await self.client.post(
            "/api/ai/exam-report",
            json={
                "attempt_id": attempt_id,
                "exam_category": "执业资格",
                "total_questions": 2,
                "correct_count": 1,
                "wrong_count": 1,
                "unanswered_count": 1,
                "accuracy_rate": 0.5,
                "time_spent": 90,
                "weak_tags": {"基础医学综合": 1},
            },
            headers=other_headers,
        )
        self.assertEqual(forbidden.status_code, 404, forbidden.text)
        self.assertEqual(forbidden.json()["detail"], "模考记录不存在")

    async def test_exam_submit_updates_only_matching_category_today_task(self):
        licensed_task = await self.client.get(
            "/api/study/today",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        junior_task = await self.client.get(
            "/api/study/today",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        self.assertEqual(licensed_task.status_code, 200, licensed_task.text)
        self.assertEqual(junior_task.status_code, 200, junior_task.text)
        self.assertNotEqual(licensed_task.json()["id"], junior_task.json()["id"])
        licensed_before = licensed_task.json()["completed_questions"]
        junior_before = junior_task.json()["completed_questions"]

        questions = await self.client.get(
            "/api/questions/exam",
            params={"question_count": 2, "exam_category": "执业资格"},
        )
        self.assertEqual(questions.status_code, 200, questions.text)
        self.assertGreaterEqual(len(questions.json()), 2)
        submitted = await self.client.post(
            "/api/questions/exam/submit",
            json={
                "time_spent": 60,
                "answers": [
                    {
                        "question_id": item["id"],
                        "selected_answer": item["answer"],
                    }
                    for item in questions.json()[:2]
                ],
            },
            headers=self.user_headers,
        )
        self.assertEqual(submitted.status_code, 200, submitted.text)

        licensed_after = await self.client.get(
            "/api/study/today",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        junior_after = await self.client.get(
            "/api/study/today",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        self.assertEqual(
            licensed_after.json()["completed_questions"], licensed_before + 2
        )
        self.assertEqual(junior_after.json()["completed_questions"], junior_before)

    async def test_exam_unanswered_is_separate_from_wrong_book_and_wrong_count(self):
        before_task = await self.client.get(
            "/api/study/today",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        self.assertEqual(before_task.status_code, 200, before_task.text)
        before_completed = before_task.json()["completed_questions"]
        questions = await self.client.get(
            "/api/questions/exam",
            params={"question_count": 2, "exam_category": "执业资格"},
        )
        self.assertEqual(questions.status_code, 200, questions.text)
        self.assertGreaterEqual(len(questions.json()), 2)
        payload = {
            "time_spent": 60,
            "answers": [
                {
                    "question_id": questions.json()[0]["id"],
                    "selected_answer": questions.json()[0]["answer"],
                },
                {
                    "question_id": questions.json()[1]["id"],
                    "selected_answer": None,
                },
            ],
        }
        submitted = await self.client.post(
            "/api/questions/exam/submit", json=payload, headers=self.user_headers
        )
        self.assertEqual(submitted.status_code, 200, submitted.text)
        body = submitted.json()
        self.assertEqual(body["total_questions"], 2)
        self.assertEqual(body["answered_count"], 1)
        self.assertEqual(body["unanswered_count"], 1)
        self.assertEqual(body["wrong_count"], 0)
        self.assertEqual(body["wrong_questions"], [])

        wrongs = await self.client.get("/api/study/wrong", headers=self.user_headers)
        stats = await self.client.get(
            "/api/study/stats/today", headers=self.user_headers
        )
        self.assertEqual(wrongs.status_code, 200, wrongs.text)
        self.assertEqual(stats.status_code, 200, stats.text)
        self.assertEqual(wrongs.json(), [])
        self.assertEqual(stats.json()["total_questions"], 1)
        self.assertEqual(stats.json()["wrong_count"], 0)
        after_task = await self.client.get(
            "/api/study/today",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        self.assertEqual(after_task.status_code, 200, after_task.text)
        self.assertEqual(
            after_task.json()["completed_questions"],
            before_completed + 1,
        )
        unanswered = await self.client.get(
            "/api/questions/practice",
            params={
                "mode": "unanswered",
                "exam_category": "执业资格",
                "limit": 100,
            },
            headers=self.user_headers,
        )
        self.assertEqual(unanswered.status_code, 200, unanswered.text)
        unanswered_ids = {item["id"] for item in unanswered.json()}
        self.assertIn(questions.json()[1]["id"], unanswered_ids)
        self.assertNotIn(questions.json()[0]["id"], unanswered_ids)

    async def test_exam_attempts_filter_by_exam_category(self):
        questions = await self.client.get(
            "/api/questions/exam",
            params={"question_count": 2, "exam_category": "执业资格"},
        )
        payload = {
            "time_spent": 120,
            "answers": [
                {"question_id": item["id"], "selected_answer": item["answer"]}
                for item in questions.json()[:2]
            ],
        }
        submitted = await self.client.post(
            "/api/questions/exam/submit", json=payload, headers=self.user_headers
        )
        self.assertEqual(submitted.status_code, 200, submitted.text)

        licensed = await self.client.get(
            "/api/questions/exam/attempts",
            params={"exam_category": "执业资格"},
            headers=self.user_headers,
        )
        junior = await self.client.get(
            "/api/questions/exam/attempts",
            params={"exam_category": "初级职称"},
            headers=self.user_headers,
        )
        self.assertEqual(licensed.status_code, 200, licensed.text)
        self.assertEqual(junior.status_code, 200, junior.text)
        self.assertTrue(licensed.json())
        self.assertEqual(junior.json(), [])

        invalid = await self.client.get(
            "/api/questions/exam/attempts",
            params={"exam_category": "junior"},
            headers=self.user_headers,
        )
        self.assertEqual(invalid.status_code, 200, invalid.text)
        self.assertEqual(invalid.json(), [])

    async def test_invalid_exam_category_filters_do_not_fallback_to_default(self):
        licensed_alias = await self.client.get(
            "/api/questions/exam", params={"exam_category": "licensed_doctor"}
        )
        chapters = await self.client.get(
            "/api/questions/chapters", params={"exam_category": "junior"}
        )
        practice = await self.client.get(
            "/api/questions/practice", params={"exam_category": "junior"}
        )
        exam = await self.client.get(
            "/api/questions/exam", params={"exam_category": "junior"}
        )
        self.assertEqual(licensed_alias.status_code, 200, licensed_alias.text)
        self.assertTrue(licensed_alias.json())
        self.assertTrue(
            all(item["exam_category"] == "执业资格" for item in licensed_alias.json())
        )
        self.assertEqual(chapters.status_code, 200, chapters.text)
        self.assertEqual(practice.status_code, 200, practice.text)
        self.assertEqual(exam.status_code, 200, exam.text)
        self.assertEqual(chapters.json(), [])
        self.assertEqual(practice.json(), [])
        self.assertEqual(exam.json(), [])

    async def test_exam_submit_rejects_mixed_exam_categories(self):
        licensed = await self.client.get(
            "/api/questions/exam",
            params={"question_count": 1, "exam_category": "执业资格"},
        )
        junior = await self.client.get(
            "/api/questions/exam",
            params={"question_count": 1, "exam_category": "初级职称"},
        )
        self.assertEqual(licensed.status_code, 200, licensed.text)
        self.assertEqual(junior.status_code, 200, junior.text)
        self.assertTrue(licensed.json())
        self.assertTrue(junior.json())

        submitted = await self.client.post(
            "/api/questions/exam/submit",
            json={
                "time_spent": 60,
                "answers": [
                    {
                        "question_id": licensed.json()[0]["id"],
                        "selected_answer": licensed.json()[0]["answer"],
                    },
                    {
                        "question_id": junior.json()[0]["id"],
                        "selected_answer": junior.json()[0]["answer"],
                    },
                ],
            },
            headers=self.user_headers,
        )
        self.assertEqual(submitted.status_code, 400)
        self.assertIn("不同考试分类", submitted.json()["detail"])

    async def test_exam_submit_rejects_invalid_selected_option(self):
        questions = await self.client.get(
            "/api/questions/exam",
            params={"question_count": 1, "exam_category": "执业资格"},
        )
        self.assertEqual(questions.status_code, 200, questions.text)
        self.assertTrue(questions.json())

        submitted = await self.client.post(
            "/api/questions/exam/submit",
            json={
                "time_spent": 30,
                "answers": [
                    {
                        "question_id": questions.json()[0]["id"],
                        "selected_answer": "Z",
                    }
                ],
            },
            headers=self.user_headers,
        )
        self.assertEqual(submitted.status_code, 400)
        self.assertIn("无效选项", submitted.json()["detail"])

    async def test_exam_submit_accepts_multi_answer_in_any_order(self):
        questions = await self.client.get(
            "/api/questions/exam",
            params={"question_count": 1, "exam_category": "执业资格"},
        )
        self.assertEqual(questions.status_code, 200, questions.text)
        self.assertTrue(questions.json())
        question_id = questions.json()[0]["id"]

        async with AsyncSessionLocal() as db:
            question = await db.get(Question, question_id)
            question.question_type = "multi"
            question.answer = "A,B"
            await db.commit()

        submitted = await self.client.post(
            "/api/questions/exam/submit",
            json={
                "time_spent": 30,
                "answers": [
                    {
                        "question_id": question_id,
                        "selected_answer": "B,A",
                    }
                ],
            },
            headers=self.user_headers,
        )
        self.assertEqual(submitted.status_code, 200, submitted.text)
        self.assertEqual(submitted.json()["correct_count"], 1)

    async def test_ai_learning_path_returns_action_steps_and_records_session(self):
        unauthorized = await self.client.post(
            "/api/ai/learning-path",
            json={"exam_category": "执业资格"},
        )
        self.assertEqual(unauthorized.status_code, 401)
        invalid_category = await self.client.post(
            "/api/ai/learning-path",
            json={"exam_category": "junior"},
            headers=self.user_headers,
        )
        self.assertEqual(invalid_category.status_code, 400, invalid_category.text)

        created = await self.client.post(
            "/api/ai/learning-path",
            json={
                "exam_category": "执业资格",
                "today_stats": {
                    "total_questions": 5,
                    "accuracy_rate": 0.6,
                    "time_spent": 600,
                },
                "prescription": {
                    "target_questions": 20,
                    "completed_questions": 5,
                    "accuracy_rate": 0.6,
                    "recommended_mode": "unanswered",
                    "weak_areas": [
                        {
                            "chapter_id": 1,
                            "chapter_name": "基础医学",
                            "accuracy_rate": 0.4,
                        }
                    ],
                },
                "wrong_review": {"due_today": 2, "overdue": 0},
            },
            headers=self.user_headers,
        )
        self.assertEqual(created.status_code, 200, created.text)
        data = created.json()
        self.assertEqual(data["title"], "AI 7 天学习路径")
        self.assertEqual(data["session_id"], "learning-path-执业资格")
        self.assertGreaterEqual(len(data["steps"]), 7)
        self.assertTrue(data["today_challenge"])
        self.assertEqual(data["reward_title"], "错题止血官")
        self.assertEqual(data["micro_tasks"], ["先做错题二刷", "标注真实错因", "补 10 道同类题"])
        self.assertIn(data["steps"][0]["mode"], ["wrong", "unanswered", "chapter", "tag", "random"])
        hot_tag_step = next(item for item in data["steps"] if item["title"] == "高频考点")
        self.assertEqual(hot_tag_step["mode"], "tag")
        self.assertIsNone(hot_tag_step["tag"])

        async with AsyncSessionLocal() as db:
            recorded = await db.scalar(
                select(func.count(AIConversation.id)).where(
                    AIConversation.session_id == "learning-path-执业资格"
                )
            )
            self.assertEqual(recorded, 2)

    async def _create_plan(self, title, start, end):
        return await self.client.post(
            "/api/study/plan",
            json={
                "title": title,
                "plan_type": "daily",
                "target_chapters": [],
                "daily_questions": 20,
                "start_date": start.isoformat(),
                "end_date": end.isoformat(),
            },
            headers=self.user_headers,
        )


if __name__ == "__main__":
    unittest.main()
