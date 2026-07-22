class Chapter {
  final int id;
  final String name;
  final String examCategory;
  final int? parentId;
  final int order;
  final List<String> subjects;

  Chapter({
    required this.id,
    required this.name,
    this.examCategory = '执业资格',
    this.parentId,
    required this.order,
    required this.subjects,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'],
      name: json['name'],
      examCategory: json['exam_category'] ?? '执业资格',
      parentId: json['parent_id'],
      order: json['order'] ?? 0,
      subjects: List<String>.from(json['subjects'] ?? []),
    );
  }
}

// 章节树结构（用于 UI 显示）
class ChapterTree {
  final Chapter chapter;
  final List<ChapterTree> children;

  ChapterTree({required this.chapter, required this.children});

  factory ChapterTree.fromChapter(Chapter chapter, List<Chapter> allChapters) {
    final children = allChapters
        .where((c) => c.parentId == chapter.id)
        .map((c) => ChapterTree.fromChapter(c, allChapters))
        .toList();
    return ChapterTree(chapter: chapter, children: children);
  }
}
