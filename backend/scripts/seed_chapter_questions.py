"""为当前章节批量生成练习题。

用法：在 backend 目录外层项目根目录执行：
    python3 backend/scripts/seed_chapter_questions.py
"""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path


DB_PATH = Path(__file__).resolve().parents[1] / "medexam.db"

QUESTION_PATTERNS = [
    (
        "关于「{topic}」的备考要求，下列哪项最符合{chapter}的学习重点？",
        "掌握核心概念、适用场景和常见考查方式",
        "只记忆少数孤立名词即可",
        "完全不需要结合临床或岗位情境",
        "只关注罕见争议内容",
        "本题考查{category}「{chapter}」中{topic}的核心学习方法，应围绕概念、适用场景和常见考点建立结构化理解。",
    ),
    (
        "复习「{topic}」时，最优先建立的能力是？",
        "识别关键概念并能在题干情境中应用",
        "只背诵题干中的单个关键词",
        "忽略与其他知识点的联系",
        "只看答案不分析选项",
        "{topic}常以情境化题干出现，优先训练概念识别和应用能力。",
    ),
    (
        "在{chapter}相关题目中，遇到「{topic}」考点时，较合理的答题思路是？",
        "先判断题干核心问题，再对应知识点和选项",
        "先看最长选项并直接选择",
        "只依据个人经验作答",
        "跳过题干限定条件",
        "医学考试题通常依赖题干限定条件，需先明确问题指向，再匹配知识点。",
    ),
    (
        "下列哪项更适合作为「{topic}」章节练习后的复盘内容？",
        "错因、相关知识点、相似题型和再次复习时间",
        "只记录正确答案字母",
        "只统计做题数量",
        "完全不看解析",
        "有效复盘应同时记录错因、知识点和后续复习安排。",
    ),
    (
        "关于{category}考试中「{topic}」的学习，下列说法正确的是？",
        "应结合大纲、题干场景和高频考点进行训练",
        "只需要浏览目录",
        "不需要区分章节层级",
        "不需要进行错题整理",
        "题库训练应服务于考试大纲，并通过错题复盘形成闭环。",
    ),
    (
        "如果考生在「{topic}」相关题目中反复出错，下一步最应该做什么？",
        "回到章节知识点，定位薄弱概念并做同类题巩固",
        "继续随机刷题但不复盘",
        "只背答案",
        "跳过该章节",
        "反复出错通常说明概念或应用链路薄弱，应回到章节知识点进行定向巩固。",
    ),
    (
        "{chapter}中的「{topic}」更适合怎样安排练习？",
        "先理解基础框架，再做分层练习和错题复盘",
        "只做高难度题",
        "只做一遍不回看",
        "完全依赖临场发挥",
        "从基础框架到分层练习更符合医学考试备考规律。",
    ),
    (
        "针对「{topic}」制作题库标签时，最有利于后续检索的是？",
        "同时标注考试科目、章节和具体知识点",
        "只标注题目编号",
        "完全不设置标签",
        "只标注难度不标注内容",
        "考试科目、章节和知识点标签能支持后台管理、前端筛选和错题复盘。",
    ),
    (
        "学习「{topic}」后，判断是否掌握的较好方式是？",
        "能解释关键概念并完成相近题型迁移",
        "只觉得自己看过",
        "只记住页面位置",
        "只完成一次选择",
        "真正掌握应能解释概念，并在相近题型中迁移应用。",
    ),
    (
        "关于「{topic}」题目解析的写法，较规范的是？",
        "说明正确选项理由，并指出其他选项的主要问题",
        "只写“选A”",
        "只复制题干",
        "不说明依据",
        "解析应帮助学习者理解为什么选对、为什么其他选项不合适。",
    ),
]


def main() -> None:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        chapters = conn.execute(
            'SELECT id, exam_category, name, subjects FROM chapters ORDER BY exam_category, "order", id'
        ).fetchall()
        inserted = 0
        for chapter in chapters:
            existing = conn.execute(
                "SELECT COUNT(*) FROM questions WHERE chapter_id = ?",
                (chapter["id"],),
            ).fetchone()[0]
            if existing >= 10:
                continue

            subjects = json.loads(chapter["subjects"] or "[]")
            if not subjects:
                subjects = [chapter["name"]]

            for offset, pattern in enumerate(QUESTION_PATTERNS[existing:10], start=existing + 1):
                topic = subjects[(offset - 1) % len(subjects)]
                content, a, b, c, d, explanation = pattern
                knowledge = [chapter["exam_category"], chapter["name"], topic]
                conn.execute(
                    """
                    INSERT INTO questions (
                        chapter_id, question_type, content, options, answer,
                        explanation, difficulty, is_real_exam, exam_year, 知识点
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        chapter["id"],
                        "single",
                        content.format(
                            category=chapter["exam_category"],
                            chapter=chapter["name"],
                            topic=topic,
                        ),
                        json.dumps(
                            {
                                "A": a,
                                "B": b,
                                "C": c,
                                "D": d,
                            },
                            ensure_ascii=False,
                        ),
                        "A",
                        explanation.format(
                            category=chapter["exam_category"],
                            chapter=chapter["name"],
                            topic=topic,
                        ),
                        min(5, 1 + ((offset - 1) % 5)),
                        0,
                        None,
                        json.dumps(knowledge, ensure_ascii=False),
                    ),
                )
                inserted += 1
        conn.commit()
        print(f"inserted={inserted}")
        for row in conn.execute(
            """
            SELECT c.exam_category, COUNT(q.id) AS question_count
            FROM chapters c
            LEFT JOIN questions q ON q.chapter_id = c.id
            GROUP BY c.exam_category
            ORDER BY c.exam_category
            """
        ):
            print(f"{row['exam_category']}|{row['question_count']}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
