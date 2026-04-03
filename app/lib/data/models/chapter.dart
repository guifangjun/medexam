class Chapter {
  final int id;
  final String name;
  final int? parentId;
  final int order;
  final List<String> subjects;

  Chapter({
    required this.id,
    required this.name,
    this.parentId,
    required this.order,
    required this.subjects,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'],
      name: json['name'],
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
