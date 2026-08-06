import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../services/api_service.dart';

class ExamCategoryNode {
  final int id;
  final String name;
  final int? parentId;
  final int level;
  final int sortOrder;
  final bool isActive;

  const ExamCategoryNode({
    required this.id,
    required this.name,
    required this.level,
    this.parentId,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory ExamCategoryNode.fromJson(Map<String, dynamic> json) {
    return ExamCategoryNode(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: '${json['name'] ?? ''}'.trim(),
      parentId: json['parent_id'] == null
          ? null
          : (json['parent_id'] is int
              ? json['parent_id']
              : int.tryParse('${json['parent_id']}')),
      level: json['level'] is int
          ? json['level']
          : int.tryParse('${json['level']}') ?? 1,
      sortOrder: json['sort_order'] is int
          ? json['sort_order']
          : int.tryParse('${json['sort_order']}') ?? 0,
      isActive: json['is_active'] != false,
    );
  }
}

class ExamCategoryProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<String> _leafCategories = AppConstants.examCategories;
  List<ExamCategoryNode> _categories = _fallbackCategoryTree();
  bool _isLoading = false;
  String? _error;

  List<String> get leafCategories => _leafCategories;
  List<ExamCategoryNode> get categories => _categories;
  List<ExamCategoryNode> get level1Categories =>
      _categories.where((item) => item.level == 1 && item.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadExamCategories() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final res = await _api.getExamCategories();
      final items = List<Map<String, dynamic>>.from(res.data);
      final nodes = items
          .map(ExamCategoryNode.fromJson)
          .where((item) => item.name.isNotEmpty)
          .toList()
        ..sort((a, b) {
          final order = a.sortOrder.compareTo(b.sortOrder);
          return order != 0 ? order : a.id.compareTo(b.id);
        });
      final leafCategories = items
          .where((item) => item['is_active'] != false)
          .where((item) => item['level'] == 3)
          .map((item) => '${item['name'] ?? ''}'.trim())
          .where((name) => name.isNotEmpty)
          .toList();
      if (leafCategories.isNotEmpty) {
        _leafCategories = leafCategories;
      }
      if (nodes.isNotEmpty) {
        _categories = nodes;
      }
    } catch (_) {
      _error = '考试科目加载失败，已使用默认科目';
      _leafCategories = AppConstants.examCategories;
      _categories = _fallbackCategoryTree();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<ExamCategoryNode> childrenOf(int? parentId) {
    return _categories
        .where((item) => item.isActive && item.parentId == parentId)
        .toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.id.compareTo(b.id);
      });
  }

  ExamCategoryNode? parentOf(ExamCategoryNode node) {
    final parentId = node.parentId;
    if (parentId == null) return null;
    for (final item in _categories) {
      if (item.id == parentId) return item;
    }
    return null;
  }

  static List<ExamCategoryNode> _fallbackCategoryTree() {
    const roots = [
      ExamCategoryNode(id: 1, name: '执业资格', level: 1, sortOrder: 1),
      ExamCategoryNode(id: 2, name: '初级职称', level: 1, sortOrder: 2),
      ExamCategoryNode(id: 3, name: '中级职称', level: 1, sortOrder: 3),
      ExamCategoryNode(id: 4, name: '高级职称', level: 1, sortOrder: 4),
      ExamCategoryNode(id: 5, name: '医师', parentId: 1, level: 2, sortOrder: 1),
      ExamCategoryNode(id: 6, name: '药师', parentId: 1, level: 2, sortOrder: 2),
      ExamCategoryNode(id: 7, name: '护士', parentId: 1, level: 2, sortOrder: 3),
    ];
    return [
      ...roots,
      for (var i = 0; i < AppConstants.examCategories.length; i++)
        ExamCategoryNode(
          id: 100 + i,
          name: AppConstants.examCategories[i],
          parentId: i < 13
              ? 5
              : i < 15
                  ? 6
                  : 7,
          level: 3,
          sortOrder: i + 1,
        ),
    ];
  }
}
