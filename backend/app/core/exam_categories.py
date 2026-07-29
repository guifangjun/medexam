from typing import Optional


EXAM_CATEGORIES = ["执业资格", "初级职称", "中级职称", "高级职称"]

EXAM_CATEGORY_ALIASES = {
    "执业医师": "执业资格",
    "助理医师": "执业资格",
    "临床执业医师": "执业资格",
    "临床助理医师": "执业资格",
    "licensed_doctor": "执业资格",
    "assistant_doctor": "执业资格",
    "junior_title": "初级职称",
    "intermediate_title": "中级职称",
    "senior_title": "高级职称",
}


def normalize_exam_category(value: Optional[str]) -> str:
    if not value:
        return "执业资格"
    category = value.strip()
    category = EXAM_CATEGORY_ALIASES.get(category, category)
    return category if category in EXAM_CATEGORIES else "执业资格"


def try_normalize_exam_category(value: Optional[str]) -> Optional[str]:
    if not value:
        return None
    category = value.strip()
    category = EXAM_CATEGORY_ALIASES.get(category, category)
    return category if category in EXAM_CATEGORIES else None
