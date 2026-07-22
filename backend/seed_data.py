#!/usr/bin/env python3
"""数据库初始化脚本 - 添加测试题目"""
import asyncio
from app.core.database import engine, AsyncSessionLocal
from app.models.question import Chapter, Question
from app.models.study import StudyPlan, DailyTask


async def seed_chapters():
    """添加考试大纲章节"""
    chapters_data = [
        {
            "name": "医学人文综合",
            "subjects": ["医学心理学", "医学伦理学", "卫生法规", "医学人文素养"],
        },
        {
            "name": "基础医学综合",
            "subjects": ["解剖学", "生理学", "生物化学", "病理学", "药理学", "医学微生物学", "医学免疫学"],
        },
        {
            "name": "预防医学综合",
            "subjects": ["预防医学", "流行病学", "卫生统计学", "公共卫生"],
        },
        {
            "name": "临床医学综合",
            "subjects": [
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
        },
        {
            "name": "中医学基础",
            "subjects": ["中医基础理论", "中医诊断基础", "常见中医治法"],
        },
        {
            "name": "实践综合",
            "subjects": ["临床思维", "体格检查", "基本操作", "辅助检查判读"],
        },
    ]

    async with AsyncSessionLocal() as db:
        for i, ch in enumerate(chapters_data):
            chapter = Chapter(
                name=ch["name"],
                exam_category="执业资格",
                subjects=ch["subjects"],
                order=i + 1
            )
            db.add(chapter)
        await db.commit()
        print(f"已添加 {len(chapters_data)} 个章节")


async def seed_questions():
    """添加测试题目"""
    questions_data = [
        {
            "chapter_id": 6,  # 内科学
            "question_type": "single",
            "content": "下列哪项是诊断高血压的标准？",
            "options": {"A": "收缩压≥140mmHg和/或舒张压≥90mmHg", "B": "收缩压≥120mmHg和/或舒张压≥80mmHg", "C": "收缩压≥130mmHg和/或舒张压≥85mmHg", "D": "收缩压≥160mmHg和/或舒张压≥100mmHg"},
            "answer": "A",
            "explanation": "根据WHO标准，高血压诊断标准为收缩压≥140mmHg和/或舒张压≥90mmHg。",
            "difficulty": 2,
            "is_real_exam": True,
            "exam_year": 2023,
            "知识点": ["高血压", "诊断标准"],
        },
        {
            "chapter_id": 6,
            "question_type": "single",
            "content": "下列哪种药物是治疗心力衰竭的一线用药？",
            "options": {"A": "ACEI/ARB", "B": "地高辛", "C": "硝酸酯类", "D": "钙通道阻滞剂"},
            "answer": "A",
            "explanation": "ACEI/ARB是治疗心力衰竭的一线用药，可以改善心室重构，降低死亡率。",
            "difficulty": 3,
            "is_real_exam": True,
            "exam_year": 2023,
            "知识点": ["心力衰竭", "药物治疗"],
        },
        {
            "chapter_id": 7,  # 外科学
            "question_type": "single",
            "content": "阑尾炎最常见的并发症是？",
            "options": {"A": "阑尾穿孔", "B": "腹腔脓肿", "C": "门静脉炎", "D": "肠粘连"},
            "answer": "B",
            "explanation": "阑尾炎最常见的并发症是腹腔脓肿，其次是阑尾穿孔。",
            "difficulty": 2,
            "is_real_exam": True,
            "exam_year": 2023,
            "知识点": ["阑尾炎", "并发症"],
        },
        {
            "chapter_id": 8,  # 妇产科学
            "question_type": "single",
            "content": "妊娠期高血压疾病最基本的病理生理改变是？",
            "options": {"A": "全身小动脉痉挛", "B": "胎盘血管痉挛", "C": "肾小球滤过率下降", "D": "血容量减少"},
            "answer": "A",
            "explanation": "妊娠期高血压疾病最基本的病理生理改变是全身小动脉痉挛，导致血压升高和器官缺血。",
            "difficulty": 3,
            "知识点": ["妊娠期高血压", "病理生理"],
        },
        {
            "chapter_id": 9,  # 儿科学
            "question_type": "single",
            "content": "小儿腹泻时，口服补液盐（ORS）的适用于？",
            "options": {"A": "轻、中度脱水", "B": "重度脱水", "C": "低渗性脱水", "D": "高渗性脱水"},
            "answer": "A",
            "explanation": "口服补液盐适用于轻、中度脱水，对于重度脱水应先静脉补液。",
            "difficulty": 2,
            "知识点": ["小儿腹泻", "补液治疗"],
        },
        {
            "chapter_id": 1,  # 解剖学
            "question_type": "single",
            "content": "右心房的入口包括？",
            "options": {"A": "上腔静脉口、下腔静脉口、冠状窦口", "B": "肺静脉口、上腔静脉口、下腔静脉口", "C": "主动脉口、肺动脉口、左心房口", "D": "下腔静脉口、冠状窦口、肺动脉口"},
            "answer": "A",
            "explanation": "右心房的入口包括上腔静脉口、下腔静脉口和冠状窦口。",
            "difficulty": 2,
            "知识点": ["心脏解剖", "右心房"],
        },
        {
            "chapter_id": 2,  # 生理学
            "question_type": "single",
            "content": "心肌细胞动作电位平台期的形成是由于？",
            "options": {"A": "Ca2+内流和K+外流", "B": "Na+快速内流", "C": "K+快速外流", "D": "Ca2+内流和Na+外流"},
            "answer": "A",
            "explanation": "平台期是由于L型Ca2+通道开放导致的Ca2+内流，同时存在K+外流，两者相互抵消形成平台。",
            "difficulty": 4,
            "知识点": ["心肌细胞", "动作电位"],
        },
        {
            "chapter_id": 3,  # 病理学
            "question_type": "single",
            "content": "恶性肿瘤的转移途径不包括？",
            "options": {"A": "直接蔓延", "B": "淋巴道转移", "C": "血道转移", "D": "种植性转移"},
            "answer": "A",
            "explanation": "直接蔓延不是转移途径，转移包括淋巴道转移、血道转移和种植性转移。",
            "difficulty": 2,
            "知识点": ["肿瘤", "转移途径"],
        },
        {
            "chapter_id": 4,  # 药理学
            "question_type": "single",
            "content": "下列哪种药物属于β受体阻滞剂？",
            "options": {"A": "美托洛尔", "B": "氨氯地平", "C": "卡托普利", "D": "氢氯噻嗪"},
            "answer": "A",
            "explanation": "美托洛尔是选择性β1受体阻滞剂，用于治疗高血压、心绞痛和心力衰竭。",
            "difficulty": 2,
            "知识点": ["β受体阻滞剂", "降压药"],
        },
        {
            "chapter_id": 5,  # 生物化学
            "question_type": "single",
            "content": "糖酵解的关键酶不包括？",
            "options": {"A": "己糖激酶", "B": "磷酸果糖激酶-1", "C": "丙酮酸激酶", "D": "柠檬酸合酶"},
            "answer": "D",
            "explanation": "糖酵解的关键酶包括己糖激酶、磷酸果糖激酶-1和丙酮酸激酶。柠檬酸合酶是三羧酸循环的酶。",
            "difficulty": 3,
            "知识点": ["糖酵解", "关键酶"],
        },
    ]

    async with AsyncSessionLocal() as db:
        for q in questions_data:
            question = Question(
                chapter_id=q["chapter_id"],
                question_type=q["question_type"],
                content=q["content"],
                options=q["options"],
                answer=q["answer"],
                explanation=q["explanation"],
                difficulty=q["difficulty"],
                is_real_exam=q.get("is_real_exam", False),
                exam_year=q.get("exam_year"),
                知识点=q.get("知识点", []),
            )
            db.add(question)
        await db.commit()
        print(f"已添加 {len(questions_data)} 道题目")


async def main():
    print("开始初始化数据库...")
    await seed_chapters()
    await seed_questions()
    print("数据库初始化完成！")

    # 关闭引擎
    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
