import os
import tempfile
import unittest
from datetime import datetime, timedelta


_db_file = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
_db_file.close()
os.environ["DATABASE_URL"] = f"sqlite+aiosqlite:///{_db_file.name}"
os.environ["DEBUG"] = "false"

import httpx
from sqlalchemy import select

from app.core.database import AsyncSessionLocal
from app.core.init_db import init_database
from app.main import app
from app.models.study import StudyPlan, StudyStats, WrongQuestion


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
            "/api/auth/login", data={"username": "demo", "password": "demo123"}
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
            for model in (WrongQuestion, StudyStats, StudyPlan):
                rows = (await db.execute(select(model))).scalars().all()
                for row in rows:
                    await db.delete(row)
            await db.commit()

    async def asyncTearDown(self):
        await self.client.aclose()

    async def test_public_courses_hide_unpublished_but_admin_sees_all(self):
        public = await self.client.get("/api/admin/courses")
        admin = await self.client.get(
            "/api/admin/courses", headers=self.admin_headers
        )
        self.assertEqual(public.status_code, 200, public.text)
        self.assertTrue(public.json())
        self.assertTrue(all(course["is_published"] for course in public.json()))
        self.assertGreater(len(admin.json()), len(public.json()))

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
                "知识点": ["高级职称", "分类过滤"],
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
            all("高级职称" in question["知识点"] for question in senior.json())
        )

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
                "知识点": ["高级职称", "客户端过滤"],
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
            all("高级职称" in question["知识点"] for question in senior_questions.json())
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
