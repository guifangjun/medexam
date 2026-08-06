from typing import Optional


DEFAULT_EXAM_CATEGORY_TREE = [
    {
        "name": "执业资格",
        "description": "执业资格考试大类",
        "children": [
            {
                "name": "医师",
                "children": [
                    "中医执业医师",
                    "中医助理医师",
                    "口腔执业医师",
                    "口腔助理医师",
                    "临床执业医师",
                    "临床助理医师",
                    "中西医执业医师",
                    "中西医助理医师",
                    "乡村全科助理医师",
                    "师承和确有专长",
                    "中医医术确有专长",
                    "公卫执业",
                    "公卫助理",
                ],
            },
            {
                "name": "药师",
                "children": ["执业西药师", "执业中药师"],
            },
            {
                "name": "护士",
                "children": ["护士执业资格", "国际护士（ISPN）"],
            },
        ],
    },
    {"name": "初级职称", "description": "初级职称考试大类", "children": []},
    {"name": "中级职称", "description": "中级职称考试大类", "children": []},
    {"name": "高级职称", "description": "高级职称考试大类", "children": []},
]

DEFAULT_EXAM_CATEGORIES = ["执业资格", "初级职称", "中级职称", "高级职称"]
DEFAULT_LEAF_EXAM_CATEGORIES = [
    child
    for group in DEFAULT_EXAM_CATEGORY_TREE
    for section in group.get("children", [])
    for child in section.get("children", [])
]
EXAM_CATEGORIES = list(dict.fromkeys(DEFAULT_LEAF_EXAM_CATEGORIES + DEFAULT_EXAM_CATEGORIES))

EXAM_CATEGORY_ALIASES = {
    "执业医师": "临床执业医师",
    "助理医师": "临床助理医师",
    "licensed_doctor": "临床执业医师",
    "assistant_doctor": "临床助理医师",
    "junior_title": "初级职称",
    "intermediate_title": "中级职称",
    "senior_title": "高级职称",
}


def normalize_exam_category(value: Optional[str]) -> str:
    if not value:
        return "临床执业医师"
    category = value.strip()
    category = EXAM_CATEGORY_ALIASES.get(category, category)
    return category if category in EXAM_CATEGORIES else "临床执业医师"


def try_normalize_exam_category(value: Optional[str]) -> Optional[str]:
    if not value:
        return None
    category = value.strip()
    category = EXAM_CATEGORY_ALIASES.get(category, category)
    return category if category in EXAM_CATEGORIES else None


def set_active_exam_categories(categories: list[str]) -> None:
    """同步数据库里的启用考试类别到运行时校验列表。"""
    normalized = []
    for item in categories:
        name = (item or "").strip()
        if name and name not in normalized:
            normalized.append(name)
    if "临床执业医师" not in normalized:
        normalized.insert(0, "临床执业医师")
    for legacy in DEFAULT_EXAM_CATEGORIES:
        if legacy not in normalized:
            normalized.append(legacy)
    EXAM_CATEGORIES[:] = normalized
