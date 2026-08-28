import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chapter.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/app_glass.dart';

String _adminErrorMessage(Object error, String fallback) {
  if (error is DioException) {
    final detail = error.response?.data;
    if (detail is Map && detail['detail'] != null) {
      final message = detail['detail'];
      if (message is String && message.isNotEmpty) return message;
      if (message is List && message.isNotEmpty) {
        final first = message.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'].toString();
        }
      }
    }
  }
  return fallback;
}

class _ExamCategoryNode {
  final int? id;
  final String name;
  final int level;
  final int? parentId;

  const _ExamCategoryNode({
    required this.id,
    required this.name,
    required this.level,
    required this.parentId,
  });

  factory _ExamCategoryNode.fromMap(Map<String, dynamic> item) {
    return _ExamCategoryNode(
      id: item['id'] is int ? item['id'] : int.tryParse('${item['id']}'),
      name: '${item['name'] ?? ''}'.trim(),
      level: item['level'] is int
          ? item['level']
          : int.tryParse('${item['level']}') ?? 1,
      parentId: item['parent_id'] is int
          ? item['parent_id']
          : int.tryParse('${item['parent_id']}'),
    );
  }
}

class _ExamCategoryTreeSelect extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String? value;
  final String allLabel;
  final ValueChanged<String?> onChanged;

  const _ExamCategoryTreeSelect({
    required this.categories,
    required this.value,
    required this.allLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final nodes = _activeNodes;
    if (nodes.isEmpty) {
      return DropdownButtonFormField<String?>(
        initialValue: value,
        decoration: const InputDecoration(
          labelText: '考试类别',
          prefixIcon: Icon(Icons.account_tree_outlined),
        ),
        items: [
          if (allLabel.isNotEmpty)
            DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
          ...AppConstants.examCategories.map(
            (item) => DropdownMenuItem<String?>(value: item, child: Text(item)),
          ),
        ],
        onChanged: onChanged,
      );
    }

    final selected = _firstWhereOrNull(nodes, (node) => node.name == value);
    final selectedPath = _pathFor(selected, nodes);
    final level1 = _level1Nodes(nodes);
    final selectedLevel1 = selectedPath.isNotEmpty ? selectedPath[0] : null;
    final level2 = _childrenOf(selectedLevel1?.id, nodes, level: 2);
    final selectedLevel2 = selectedPath.length > 1 ? selectedPath[1] : null;
    final level3 = _childrenOf(selectedLevel2?.id, nodes, level: 3);
    final selectedLevel3 = selectedPath.length > 2 ? selectedPath[2] : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final actionWidth = allLabel.isEmpty ? 0.0 : 96.0;
        final fieldWidth = compact
            ? constraints.maxWidth
            : (constraints.maxWidth - actionWidth - 30) / 3;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (allLabel.isNotEmpty)
              SizedBox(
                width: compact ? constraints.maxWidth : actionWidth,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                  label: Text(allLabel),
                ),
              ),
            SizedBox(
              width: compact ? constraints.maxWidth : fieldWidth,
              child: DropdownButtonFormField<int?>(
                initialValue: selectedLevel1?.id,
                decoration: const InputDecoration(
                  labelText: '一级大类',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
                items: [
                  ...level1.map(
                    (item) => DropdownMenuItem<int?>(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (id) => onChanged(_selectableName(id, nodes)),
              ),
            ),
            SizedBox(
              width: compact ? constraints.maxWidth : fieldWidth,
              child: DropdownButtonFormField<int?>(
                initialValue: selectedLevel2?.id,
                decoration: const InputDecoration(labelText: '二级分组'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('全部分组'),
                  ),
                  ...level2.map(
                    (item) => DropdownMenuItem<int?>(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: level2.isEmpty
                    ? null
                    : (id) => onChanged(
                          id == null
                              ? selectedLevel1?.name
                              : _selectableName(id, nodes),
                        ),
              ),
            ),
            SizedBox(
              width: compact ? constraints.maxWidth : fieldWidth,
              child: DropdownButtonFormField<int?>(
                initialValue: selectedLevel3?.id,
                decoration: const InputDecoration(labelText: '三级项目'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('全部项目'),
                  ),
                  ...level3.map(
                    (item) => DropdownMenuItem<int?>(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: level3.isEmpty
                    ? null
                    : (id) => onChanged(
                          id == null
                              ? selectedLevel2?.name ?? selectedLevel1?.name
                              : _selectableName(id, nodes),
                        ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<_ExamCategoryNode> get _activeNodes {
    return categories
        .where((item) => item['is_active'] != false)
        .map(_ExamCategoryNode.fromMap)
        .where((item) => item.name.isNotEmpty)
        .toList()
      ..sort((a, b) {
        final orderA = _sortOrderFor(a.id);
        final orderB = _sortOrderFor(b.id);
        final orderCompare = orderA.compareTo(orderB);
        if (orderCompare != 0) return orderCompare;
        final levelCompare = a.level.compareTo(b.level);
        if (levelCompare != 0) return levelCompare;
        return a.name.compareTo(b.name);
      });
  }

  List<_ExamCategoryNode> _level1Nodes(List<_ExamCategoryNode> nodes) {
    return nodes
        .where((item) => item.level == 1 && item.parentId == null)
        .toList();
  }

  List<_ExamCategoryNode> _childrenOf(
    int? parentId,
    List<_ExamCategoryNode> nodes, {
    required int level,
  }) {
    return nodes
        .where((item) => item.level == level && item.parentId == parentId)
        .toList();
  }

  List<_ExamCategoryNode> _pathFor(
    _ExamCategoryNode? selected,
    List<_ExamCategoryNode> nodes,
  ) {
    if (selected == null) return const [];
    final path = <_ExamCategoryNode>[selected];
    var parentId = selected.parentId;
    while (parentId != null) {
      final parent = _firstWhereOrNull(nodes, (item) => item.id == parentId);
      if (parent == null) break;
      path.insert(0, parent);
      parentId = parent.parentId;
    }
    return path;
  }

  String? _selectableName(int? id, List<_ExamCategoryNode> nodes) {
    if (id == null) return null;
    final node = _firstWhereOrNull(nodes, (item) => item.id == id);
    if (node == null) return null;
    return node.name;
  }

  int _sortOrderFor(int? id) {
    for (final item in categories) {
      if (item['id'] == id) {
        final raw = item['sort_order'];
        return raw is int ? raw : int.tryParse('$raw') ?? 0;
      }
    }
    return 0;
  }

  T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _api = ApiService();
  final _keywordCtl = TextEditingController();
  final _userKeywordCtl = TextEditingController();
  Map<String, dynamic>? _admin;
  var _isCheckingAuth = true;
  var _tab = 0;
  var _isLoading = false;
  var _selectedExamCategory = AppConstants.examCategories.first;
  int? _selectedChapterId;
  List<Chapter> _chapters = [];
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _examCategories = [];
  Map<String, dynamic>? _dashboard;
  String? _selectedCourseExamCategory;
  bool _courseUnlinkedOnly = false;
  String? _dashboardExamCategory;
  String _dashboardDate = DateTime.now().toIso8601String().substring(0, 10);
  String? _selectedUserExamCategory;
  bool? _selectedUserActive;
  String? _loadError;

  List<String> get _activeExamCategoryNames {
    final names = _examCategories
        .where((item) => item['is_active'] != false)
        .map((item) => '${item['name'] ?? ''}'.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    return names.isEmpty ? AppConstants.examCategories : names;
  }

  @override
  void initState() {
    super.initState();
    _checkAdminAuth();
  }

  @override
  void dispose() {
    _keywordCtl.dispose();
    _userKeywordCtl.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAuth() async {
    await _api.loadAdminToken();
    if (!_api.hasAdminToken) {
      setState(() => _isCheckingAuth = false);
      return;
    }
    try {
      final res = await _api.getAdminMe();
      _admin = Map<String, dynamic>.from(res.data);
      await _loadAll();
    } catch (_) {
      await _api.clearAdminToken();
    } finally {
      if (mounted) setState(() => _isCheckingAuth = false);
    }
  }

  Future<void> _loginAdmin(String username, String password) async {
    final res = await _api.adminLogin(username, password);
    await _api.setAdminToken(res.data['access_token']);
    final me = await _api.getAdminMe();
    _admin = Map<String, dynamic>.from(me.data);
    await _loadAll();
    if (mounted) setState(() {});
  }

  Future<void> _logoutAdmin() async {
    await _api.clearAdminToken();
    setState(() {
      _admin = null;
      _questions = [];
      _courses = [];
      _users = [];
    });
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        _api.getAdminQuestions(
          keyword: _keywordCtl.text.trim(),
          examCategory: _selectedExamCategory,
          chapterId: _selectedChapterId,
        ),
        _api.getChapters(),
        _api.getAdminCourses(
          examCategory: _selectedCourseExamCategory,
          unlinkedOnly: _courseUnlinkedOnly,
        ),
        _api.getAdminDashboard(
          examCategory: _dashboardExamCategory,
          date: _dashboardDate,
        ),
        _api.getAdminUsers(
          keyword: _userKeywordCtl.text.trim(),
          examCategory: _selectedUserExamCategory,
          isActive: _selectedUserActive,
        ),
        _api.getAdminExamCategories(),
      ]);
      final questionRes = responses[0];
      final chapterRes = responses[1];
      final courseRes = responses[2];
      final dashboardRes = responses[3];
      final userRes = responses[4];
      final examCategoryRes = responses[5];
      _chapters = (chapterRes.data as List)
          .map((json) => Chapter.fromJson(json))
          .toList();
      _questions = List<Map<String, dynamic>>.from(questionRes.data);
      _courses = List<Map<String, dynamic>>.from(courseRes.data);
      _users = List<Map<String, dynamic>>.from(userRes.data);
      _examCategories = List<Map<String, dynamic>>.from(examCategoryRes.data);
      _dashboard = Map<String, dynamic>.from(dashboardRes.data);
      final names = _activeExamCategoryNames;
      if (!names.contains(_selectedExamCategory)) {
        _selectedExamCategory = names.first;
        _selectedChapterId = null;
      }
      if (_selectedCourseExamCategory != null &&
          !names.contains(_selectedCourseExamCategory)) {
        _selectedCourseExamCategory = null;
      }
      if (_selectedUserExamCategory != null &&
          !names.contains(_selectedUserExamCategory)) {
        _selectedUserExamCategory = null;
      }
      if (_dashboardExamCategory != null &&
          !names.contains(_dashboardExamCategory)) {
        _dashboardExamCategory = null;
      }
      _loadError = null;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        await _api.clearAdminToken();
        if (!mounted) return;
        setState(() {
          _admin = null;
          _questions = [];
          _courses = [];
          _users = [];
          _dashboard = null;
          _loadError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('后台登录已过期，请重新登录'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
      _loadError = _adminErrorMessage(e, '后台数据加载失败，请稍后重试');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_loadError!),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const GlassScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_admin == null) {
      return _AdminLoginScreen(onLogin: _loginAdmin);
    }

    return GlassScaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            if (compact) {
              return Column(
                children: [
                  _AdminCompactNav(
                    selected: _tab,
                    admin: _admin!,
                    onSelected: (value) => setState(() => _tab = value),
                    onLogout: _logoutAdmin,
                    onRefresh: _loadAll,
                  ),
                  Expanded(child: _buildAdminContent(compact: true)),
                ],
              );
            }
            return Row(
              children: [
                _AdminSidebar(
                  selected: _tab,
                  admin: _admin!,
                  onSelected: (value) => setState(() => _tab = value),
                  onLogout: _logoutAdmin,
                ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(admin: _admin!, onRefresh: _loadAll),
                      Expanded(child: _buildAdminContent()),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdminContent({bool compact = false}) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetricRow(
            questions: _dashboard?['question_count'] ?? _questions.length,
            users: _dashboard?['user_count'] ?? _users.length,
            liveCourses:
                _courses.where((c) => c['course_type'] == 'live').length,
            recordedCourses:
                _courses.where((c) => c['course_type'] == 'recorded').length,
          ),
          if (_loadError != null) ...[
            const SizedBox(height: 12),
            _AdminInlineError(
              message: _loadError!,
              onRetry: _loadAll,
            ),
          ],
          const SizedBox(height: 20),
          if (_tab == 0)
            _QuestionManager(
              questions: _questions,
              chapters: _chapters,
              examCategories: _activeExamCategoryNames,
              examCategoryTree: _examCategories,
              selectedExamCategory: _selectedExamCategory,
              selectedChapterId: _selectedChapterId,
              keywordCtl: _keywordCtl,
              onExamCategoryChanged: (category) {
                setState(() {
                  _selectedExamCategory = category;
                  _selectedChapterId = null;
                });
                _loadAll();
              },
              onChapterChanged: (chapterId) {
                setState(() => _selectedChapterId = chapterId);
                _loadAll();
              },
              onSearch: _loadAll,
              onSave: _saveQuestion,
              onDelete: _deleteQuestion,
            )
          else if (_tab == 1)
            _CourseManager(
              courses: _courses,
              chapters: _chapters,
              examCategories: _activeExamCategoryNames,
              examCategoryTree: _examCategories,
              selectedExamCategory: _selectedCourseExamCategory,
              unlinkedOnly: _courseUnlinkedOnly,
              onExamCategoryChanged: (category) {
                setState(() => _selectedCourseExamCategory = category);
                _loadAll();
              },
              onUnlinkedOnlyChanged: (value) {
                setState(() => _courseUnlinkedOnly = value);
                _loadAll();
              },
              onSave: _saveCourse,
              onDelete: _deleteCourse,
            )
          else if (_tab == 2)
            _UserManager(
              users: _users,
              examCategories: _activeExamCategoryNames,
              examCategoryTree: _examCategories,
              keywordCtl: _userKeywordCtl,
              selectedExamCategory: _selectedUserExamCategory,
              selectedActive: _selectedUserActive,
              onExamCategoryChanged: (category) {
                setState(() => _selectedUserExamCategory = category);
                _loadAll();
              },
              onActiveChanged: (active) {
                setState(() => _selectedUserActive = active);
                _loadAll();
              },
              onSearch: _loadAll,
              onSave: _saveUser,
              onDelete: _deleteUser,
              onAnalyze: _loadUserLearningAnalysis,
            )
          else if (_tab == 3)
            _DashboardManager(
              data: _dashboard ?? {},
              examCategories: _activeExamCategoryNames,
              selectedExamCategory: _dashboardExamCategory,
              selectedDate: _dashboardDate,
              onExamCategoryChanged: (category) {
                setState(() => _dashboardExamCategory = category);
                _loadAll();
              },
              onDateChanged: (date) {
                setState(() => _dashboardDate = date);
                _loadAll();
              },
            )
          else
            _ExamCategoryManager(
              categories: _examCategories,
              onSave: _saveExamCategory,
              onDelete: _deleteExamCategory,
            ),
        ],
      ),
    );
  }

  Future<void> _saveQuestion(Map<String, dynamic> data, {int? id}) async {
    final isCreate = id == null;
    if (id == null) {
      await _api.createAdminQuestion(data);
    } else {
      await _api.updateAdminQuestion(id, data);
    }
    await _loadAll();
    _showAdminSnack(isCreate ? '题目已新增' : '题目已更新');
  }

  Future<void> _deleteQuestion(int id) async {
    await _api.deleteAdminQuestion(id);
    await _loadAll();
    _showAdminSnack('题目已删除');
  }

  Future<void> _saveCourse(Map<String, dynamic> data, {int? id}) async {
    final isCreate = id == null;
    if (id == null) {
      await _api.createAdminCourse(data);
    } else {
      await _api.updateAdminCourse(id, data);
    }
    await _loadAll();
    _showAdminSnack(isCreate ? '课程已新增' : '课程已更新');
  }

  Future<void> _deleteCourse(int id) async {
    await _api.deleteAdminCourse(id);
    await _loadAll();
    _showAdminSnack('课程已删除');
  }

  Future<void> _saveUser(Map<String, dynamic> data, {int? id}) async {
    final isCreate = id == null;
    if (id == null) {
      await _api.createAdminUser(data);
    } else {
      await _api.updateAdminUser(id, data);
    }
    await _loadAll();
    _showAdminSnack(isCreate ? '用户已新增' : '用户已更新');
  }

  Future<void> _deleteUser(int id) async {
    await _api.deleteAdminUser(id);
    await _loadAll();
    _showAdminSnack('用户已删除');
  }

  Future<Map<String, dynamic>> _loadUserLearningAnalysis(
    int userId, {
    String? examCategory,
    int days = 30,
  }) async {
    final res = await _api.getAdminUserLearningAnalysis(
      userId,
      examCategory: examCategory,
      days: days,
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> _saveExamCategory(Map<String, dynamic> data, {int? id}) async {
    final isCreate = id == null;
    if (isCreate) {
      await _api.createAdminExamCategory(data);
    } else {
      await _api.updateAdminExamCategory(id, data);
    }
    await _loadAll();
    _showAdminSnack(isCreate ? '考试类别已新增' : '考试类别已更新');
  }

  Future<void> _deleteExamCategory(int id) async {
    await _api.deleteAdminExamCategory(id);
    await _loadAll();
    _showAdminSnack('考试类别已删除');
  }

  void _showAdminSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.success,
      ),
    );
  }
}

class _AdminLoginScreen extends StatefulWidget {
  final Future<void> Function(String username, String password) onLogin;

  const _AdminLoginScreen({required this.onLogin});

  @override
  State<_AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<_AdminLoginScreen> {
  final _usernameCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  var _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await widget.onLogin(_usernameCtl.text.trim(), _passwordCtl.text);
    } catch (_) {
      setState(() => _error = '后台账号或密码错误');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: Center(
        child: SizedBox(
          width: 420,
          child: GlassCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: AppTheme.primary, size: 28),
                ),
                const SizedBox(height: 18),
                const Text(
                  '管理后台登录',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '后台为独立系统，请使用管理员账号登录',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameCtl,
                  decoration: const InputDecoration(
                    labelText: '管理员账号',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordCtl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppTheme.error)),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login_rounded),
                    label: const Text('登录后台'),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setState(() {
                              _usernameCtl.text = 'admin';
                              _passwordCtl.text = 'admin123';
                              _error = null;
                            });
                            await _submit();
                          },
                    icon: const Icon(Icons.account_circle_outlined, size: 18),
                    label: const Text('一键登录演示账号 admin / admin123'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  final int selected;
  final Map<String, dynamic> admin;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  const _AdminSidebar({
    required this.selected,
    required this.admin,
    required this.onSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.all(16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MedExam Admin',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text('内容管理后台',
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded,
                      color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          admin['full_name'] ?? admin['username'] ?? '管理员',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          admin['role'] ?? 'admin',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _NavItem(
              icon: Icons.quiz_rounded,
              label: '题库管理',
              selected: selected == 0,
              onTap: () => onSelected(0),
            ),
            const SizedBox(height: 8),
            _NavItem(
              icon: Icons.video_library_rounded,
              label: '课程管理',
              selected: selected == 1,
              onTap: () => onSelected(1),
            ),
            const SizedBox(height: 8),
            _NavItem(
              icon: Icons.groups_rounded,
              label: '用户管理',
              selected: selected == 2,
              onTap: () => onSelected(2),
            ),
            const SizedBox(height: 8),
            _NavItem(
              icon: Icons.dashboard_rounded,
              label: '数据看板',
              selected: selected == 3,
              onTap: () => onSelected(3),
            ),
            const SizedBox(height: 8),
            _NavItem(
              icon: Icons.category_rounded,
              label: '考试类别',
              selected: selected == 4,
              onTap: () => onSelected(4),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
              icon: const Icon(Icons.phone_iphone_rounded),
              label: const Text('返回学员端'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('退出后台'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCompactNav extends StatelessWidget {
  final int selected;
  final Map<String, dynamic> admin;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  final Future<void> Function() onRefresh;

  const _AdminCompactNav({
    required this.selected,
    required this.admin,
    required this.onSelected,
    required this.onLogout,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final name = admin['full_name'] ?? admin['username'] ?? '管理员';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings_rounded,
                    color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MedExam Admin',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$name · ${admin['role'] ?? 'admin'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '刷新',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: '退出后台',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                ),
                IconButton(
                  tooltip: '返回学员端',
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context, '/', (_) => false),
                  icon: const Icon(Icons.phone_iphone_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CompactNavChip(
                    icon: Icons.quiz_rounded,
                    label: '题库',
                    selected: selected == 0,
                    onTap: () => onSelected(0),
                  ),
                  _CompactNavChip(
                    icon: Icons.video_library_rounded,
                    label: '课程',
                    selected: selected == 1,
                    onTap: () => onSelected(1),
                  ),
                  _CompactNavChip(
                    icon: Icons.groups_rounded,
                    label: '用户',
                    selected: selected == 2,
                    onTap: () => onSelected(2),
                  ),
                  _CompactNavChip(
                    icon: Icons.dashboard_rounded,
                    label: '看板',
                    selected: selected == 3,
                    onTap: () => onSelected(3),
                  ),
                  _CompactNavChip(
                    icon: Icons.category_rounded,
                    label: '类别',
                    selected: selected == 4,
                    onTap: () => onSelected(4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactNavChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CompactNavChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        avatar: Icon(
          icon,
          size: 16,
          color: selected ? Colors.white : AppTheme.primary,
        ),
        label: SizedBox(
          width: 34,
          child: Text(label, textAlign: TextAlign.center),
        ),
        selectedColor: AppTheme.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        backgroundColor: Colors.white.withOpacity(0.72),
        side: BorderSide(color: AppTheme.divider.withOpacity(0.8)),
      ),
    );
  }
}

class _AdminInlineError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _AdminInlineError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.error.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? Colors.white : AppTheme.textSecondary,
                size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final Map<String, dynamic> admin;
  final Future<void> Function() onRefresh;

  const _TopBar({required this.admin, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 24, 8),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '题库、课程与用户管理',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final int questions;
  final int users;
  final int liveCourses;
  final int recordedCourses;

  const _MetricRow({
    required this.questions,
    required this.users,
    required this.liveCourses,
    required this.recordedCourses,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard.compact(
                  label: '题目总数', value: '$questions', color: AppTheme.primary),
              _MetricCard.compact(
                  label: '用户数', value: '$users', color: AppTheme.accent),
              _MetricCard.compact(
                  label: '直播课', value: '$liveCourses', color: AppTheme.error),
              _MetricCard.compact(
                  label: '录播课',
                  value: '$recordedCourses',
                  color: AppTheme.success),
            ],
          );
        }
        return Row(
          children: [
            _MetricCard(
                label: '题目总数', value: '$questions', color: AppTheme.primary),
            const SizedBox(width: 12),
            _MetricCard(label: '用户数', value: '$users', color: AppTheme.accent),
            const SizedBox(width: 12),
            _MetricCard(
                label: '直播课', value: '$liveCourses', color: AppTheme.error),
            const SizedBox(width: 12),
            _MetricCard(
                label: '录播课',
                value: '$recordedCourses',
                color: AppTheme.success),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool compact;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  }) : compact = false;

  const _MetricCard.compact({
    required this.label,
    required this.value,
    required this.color,
  }) : compact = true;

  @override
  Widget build(BuildContext context) {
    final card = GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.analytics_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              Text(label,
                  style: const TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
    if (compact) {
      return SizedBox(width: 210, child: card);
    }
    return Expanded(child: card);
  }
}

class _QuestionManager extends StatelessWidget {
  final List<Map<String, dynamic>> questions;
  final List<Chapter> chapters;
  final List<String> examCategories;
  final List<Map<String, dynamic>> examCategoryTree;
  final String selectedExamCategory;
  final int? selectedChapterId;
  final TextEditingController keywordCtl;
  final ValueChanged<String> onExamCategoryChanged;
  final ValueChanged<int?> onChapterChanged;
  final Future<void> Function() onSearch;
  final Future<void> Function(Map<String, dynamic> data, {int? id}) onSave;
  final Future<void> Function(int id) onDelete;

  const _QuestionManager({
    required this.questions,
    required this.chapters,
    required this.examCategories,
    required this.examCategoryTree,
    required this.selectedExamCategory,
    required this.selectedChapterId,
    required this.keywordCtl,
    required this.onExamCategoryChanged,
    required this.onChapterChanged,
    required this.onSearch,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveExamCategory = examCategories.contains(selectedExamCategory)
        ? selectedExamCategory
        : examCategories.first;
    final categoryChapters = _chaptersForCategory(effectiveExamCategory);
    final effectiveSelectedChapterId =
        categoryChapters.any((chapter) => chapter.id == selectedChapterId)
            ? selectedChapterId
            : null;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('题库管理',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              SizedBox(
                width: 560,
                child: _ExamCategoryTreeSelect(
                  categories: examCategoryTree,
                  value: effectiveExamCategory,
                  allLabel: '',
                  onChanged: (value) {
                    if (value != null) onExamCategoryChanged(value);
                  },
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<int?>(
                  value: effectiveSelectedChapterId,
                  decoration: const InputDecoration(
                    labelText: '章节/学科',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('全部章节'),
                    ),
                    ...categoryChapters.map(
                      (chapter) => DropdownMenuItem<int?>(
                        value: chapter.id,
                        child: Text(chapter.name),
                      ),
                    ),
                  ],
                  onChanged: onChapterChanged,
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: keywordCtl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: '搜索题干',
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded),
                label: const Text('查询'),
              ),
              ElevatedButton.icon(
                onPressed: () => _showQuestionDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('新增题目'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DataHeader(
            columns: const ['ID', '考试分类', '章节', '题干', '类型', '难度', '答案', '操作'],
            flexes: const [1, 2, 2, 5, 1, 1, 1, 2],
          ),
          if (questions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: Center(
                child: Text(
                  '暂无题目',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ...questions.map(
            (question) => _DataRowCard(
              cells: [
                '${question['id']}',
                _categoryForChapterId(question['chapter_id']) ?? '-',
                _chapterName(question['chapter_id']),
                question['content'] ?? '',
                _questionTypeLabel(question['question_type']),
                '${question['difficulty'] ?? 3}',
                question['answer'] ?? '',
              ],
              flexes: const [1, 2, 2, 5, 1, 1, 1],
              actions: [
                IconButton(
                  tooltip: '编辑',
                  onPressed: () => _showQuestionDialog(context, question),
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: () => _confirmDeleteQuestion(context, question),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteQuestion(
    BuildContext context,
    Map<String, dynamic> question,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除题目'),
        content: Text(
          '确定删除这道题吗？\n\n${question['content'] ?? '题目 #${question['id']}'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await onDelete(question['id']);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_adminErrorMessage(e, '删除题目失败'))),
        );
      }
    }
  }

  void _showQuestionDialog(BuildContext context,
      [Map<String, dynamic>? question]) {
    final initialExamCategory = question == null
        ? (examCategories.contains(selectedExamCategory)
            ? selectedExamCategory
            : examCategories.first)
        : _categoryForChapterId(question['chapter_id']) ??
            (examCategories.contains(selectedExamCategory)
                ? selectedExamCategory
                : examCategories.first);
    final categoryChapters = _chaptersForCategory(initialExamCategory);
    if (categoryChapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$initialExamCategory 暂无章节，请先初始化章节数据')),
      );
      return;
    }
    final contentCtl = TextEditingController(text: question?['content'] ?? '');
    final optionACtl =
        TextEditingController(text: question?['options']?['A'] ?? '');
    final optionBCtl =
        TextEditingController(text: question?['options']?['B'] ?? '');
    final optionCCtl =
        TextEditingController(text: question?['options']?['C'] ?? '');
    final optionDCtl =
        TextEditingController(text: question?['options']?['D'] ?? '');
    final answerCtl = TextEditingController(text: question?['answer'] ?? 'A');
    final explanationCtl =
        TextEditingController(text: question?['explanation'] ?? '');
    final tagsCtl = TextEditingController(
      text: List<String>.from(
        question?['tags'] ?? question?['知识点'] ?? const [],
      ).join('、'),
    );
    var questionType = question?['question_type'] ?? 'single';
    var dialogExamCategory = initialExamCategory;
    final questionChapterId = question?['chapter_id'];
    final effectiveSelectedChapterId =
        categoryChapters.any((chapter) => chapter.id == selectedChapterId)
            ? selectedChapterId
            : null;
    var chapterId =
        categoryChapters.any((chapter) => chapter.id == questionChapterId)
            ? questionChapterId
            : effectiveSelectedChapterId ?? categoryChapters.first.id;
    var difficulty = question?['difficulty'] ?? 3;
    var isRealExam = question?['is_real_exam'] ?? false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(question == null ? '新增题目' : '编辑题目'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _ExamCategoryTreeSelect(
                    categories: examCategoryTree,
                    value: dialogExamCategory,
                    allLabel: '',
                    onChanged: (value) {
                      if (value == null) return;
                      final nextChapters = _chaptersForCategory(value);
                      if (nextChapters.isEmpty) return;
                      setDialogState(() {
                        dialogExamCategory = value;
                        chapterId = nextChapters.first.id;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: chapterId,
                    decoration: const InputDecoration(
                      labelText: '章节/学科',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                    items: _chaptersForCategory(dialogExamCategory)
                        .map((chapter) => DropdownMenuItem<int>(
                              value: chapter.id,
                              child: Text(
                                chapter.subjects.isEmpty
                                    ? chapter.name
                                    : '${chapter.name} · ${chapter.subjects.join("、")}',
                              ),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => chapterId = value!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '题干'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _optionField('A', optionACtl)),
                      const SizedBox(width: 10),
                      Expanded(child: _optionField('B', optionBCtl)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _optionField('C', optionCCtl)),
                      const SizedBox(width: 10),
                      Expanded(child: _optionField('D', optionDCtl)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: questionType,
                          decoration: const InputDecoration(labelText: '题型'),
                          items: const [
                            DropdownMenuItem(
                                value: 'single', child: Text('单选')),
                            DropdownMenuItem(value: 'multi', child: Text('多选')),
                            DropdownMenuItem(value: 'case', child: Text('病例题')),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => questionType = value!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: answerCtl,
                          decoration: const InputDecoration(labelText: '答案'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: difficulty,
                          decoration: const InputDecoration(labelText: '难度'),
                          items: [1, 2, 3, 4, 5]
                              .map((i) =>
                                  DropdownMenuItem(value: i, child: Text('$i')))
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => difficulty = value!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: explanationCtl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: '解析'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsCtl,
                    decoration: const InputDecoration(
                      labelText: '知识点标签',
                      hintText: '多个标签用顿号、逗号或空格分隔，如：内科学、高血压',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                  ),
                  CheckboxListTile(
                    value: isRealExam,
                    onChanged: (value) =>
                        setDialogState(() => isRealExam = value ?? false),
                    title: const Text('标记为真题'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'chapter_id': chapterId,
                  'question_type': questionType,
                  'content': contentCtl.text.trim(),
                  'options': {
                    'A': optionACtl.text.trim(),
                    'B': optionBCtl.text.trim(),
                    'C': optionCCtl.text.trim(),
                    'D': optionDCtl.text.trim(),
                  },
                  'answer': answerCtl.text.trim().toUpperCase(),
                  'explanation': explanationCtl.text.trim(),
                  'difficulty': difficulty,
                  'is_real_exam': isRealExam,
                  'tags': _parseTags(tagsCtl.text),
                };
                try {
                  await onSave(data, id: question?['id']);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(_adminErrorMessage(e, '保存题目失败'))),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: '$label 选项'),
    );
  }

  List<String> _parseTags(String raw) {
    return raw
        .split(RegExp(r'[、,，\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  String _questionTypeLabel(dynamic value) {
    switch (value) {
      case 'multi':
        return '多选';
      case 'case':
        return '病例';
      default:
        return '单选';
    }
  }

  String _chapterName(dynamic chapterId) {
    for (final chapter in chapters) {
      if (chapter.id == chapterId) return chapter.name;
    }
    return '未分类';
  }

  List<Chapter> _chaptersForCategory(String category) {
    return chapters
        .where((chapter) => chapter.examCategory == category)
        .toList();
  }

  String? _categoryForChapterId(dynamic chapterId) {
    if (chapterId is! int) return null;
    for (final chapter in chapters) {
      if (chapter.id == chapterId) return chapter.examCategory;
    }
    return null;
  }
}

class _CourseManager extends StatelessWidget {
  final List<Map<String, dynamic>> courses;
  final List<Chapter> chapters;
  final List<String> examCategories;
  final List<Map<String, dynamic>> examCategoryTree;
  final String? selectedExamCategory;
  final bool unlinkedOnly;
  final ValueChanged<String?> onExamCategoryChanged;
  final ValueChanged<bool> onUnlinkedOnlyChanged;
  final Future<void> Function(Map<String, dynamic> data, {int? id}) onSave;
  final Future<void> Function(int id) onDelete;

  const _CourseManager({
    required this.courses,
    required this.chapters,
    required this.examCategories,
    required this.examCategoryTree,
    required this.selectedExamCategory,
    required this.unlinkedOnly,
    required this.onExamCategoryChanged,
    required this.onUnlinkedOnlyChanged,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '课程管理',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '共 ${courses.length} 门课程',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              SizedBox(
                width: 560,
                child: _ExamCategoryTreeSelect(
                  categories: examCategoryTree,
                  value: selectedExamCategory,
                  allLabel: '全部考试',
                  onChanged: onExamCategoryChanged,
                ),
              ),
              FilterChip(
                selected: unlinkedOnly,
                avatar: Icon(
                  unlinkedOnly
                      ? Icons.link_off_rounded
                      : Icons.link_off_outlined,
                  size: 18,
                ),
                label: const Text('只看未关联题库'),
                onSelected: onUnlinkedOnlyChanged,
              ),
              ElevatedButton.icon(
                onPressed: () => _showCourseDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('新增课程'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DataHeader(
            columns: const ['ID', '课程名称', '类型', '考试', '关联章节', '讲师', '状态', '操作'],
            flexes: const [1, 4, 1, 1, 2, 2, 1, 2],
          ),
          if (courses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: Center(
                child: Text(
                  '暂无课程',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ...courses.map(
            (course) => _DataRowCard(
              cells: [
                '${course['id']}',
                course['title'] ?? '',
                course['course_type'] == 'live' ? '直播' : '录播',
                course['exam_category'] ?? '',
                _courseChapterText(course),
                course['teacher'] ?? '',
                course['is_published'] == true ? '已发布' : '未发布',
              ],
              flexes: const [1, 4, 1, 1, 2, 2, 1],
              actions: [
                IconButton(
                  tooltip: '编辑',
                  onPressed: () => _showCourseDialog(context, course),
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: () => _confirmDeleteCourse(context, course),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCourse(
    BuildContext context,
    Map<String, dynamic> course,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课程'),
        content: Text(
          '确定删除课程「${course['title'] ?? course['id']}」吗？客户端将不再展示该课程。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await onDelete(course['id']);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_adminErrorMessage(e, '删除课程失败'))),
        );
      }
    }
  }

  void _showCourseDialog(BuildContext context, [Map<String, dynamic>? course]) {
    final titleCtl = TextEditingController(text: course?['title'] ?? '');
    final teacherCtl = TextEditingController(text: course?['teacher'] ?? '');
    final scheduleCtl = TextEditingController(text: course?['schedule'] ?? '');
    final lessonCtl =
        TextEditingController(text: '${course?['lesson_count'] ?? 1}');
    final descCtl = TextEditingController(text: course?['description'] ?? '');
    var courseType = course?['course_type'] ?? 'recorded';
    var examCategory =
        (course?['exam_category'] ?? examCategories.first).toString();
    if (!examCategories.contains(examCategory)) {
      examCategory = examCategories.first;
    }
    int? chapterId = course?['chapter_id'];
    var isPublished = course?['is_published'] ?? true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(course == null ? '新增课程' : '编辑课程'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(labelText: '课程名称'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: courseType,
                          decoration: const InputDecoration(labelText: '课程类型'),
                          items: const [
                            DropdownMenuItem(value: 'live', child: Text('直播课')),
                            DropdownMenuItem(
                                value: 'recorded', child: Text('录播课')),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => courseType = value!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _ExamCategoryTreeSelect(
                          categories: examCategoryTree,
                          value: examCategory,
                          allLabel: '',
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              examCategory = value;
                              chapterId = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _chaptersForCategory(examCategory)
                            .any((chapter) => chapter.id == chapterId)
                        ? chapterId
                        : null,
                    decoration: const InputDecoration(labelText: '关联章节题库'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('暂不关联'),
                      ),
                      ..._chaptersForCategory(examCategory).map(
                        (chapter) => DropdownMenuItem<int?>(
                          value: chapter.id,
                          child: Text(chapter.name),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => chapterId = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: teacherCtl,
                          decoration: const InputDecoration(labelText: '讲师'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: lessonCtl,
                          decoration: const InputDecoration(labelText: '课时数'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scheduleCtl,
                    decoration: const InputDecoration(labelText: '直播时间/学习方式'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: '课程简介'),
                  ),
                  CheckboxListTile(
                    value: isPublished,
                    onChanged: (value) =>
                        setDialogState(() => isPublished = value ?? true),
                    title: const Text('发布课程'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                final lessonText = lessonCtl.text.trim();
                final lessonCount = int.tryParse(lessonText);
                if (lessonCount == null || lessonCount < 1) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('课时数必须是大于 0 的整数')),
                  );
                  return;
                }
                final data = {
                  'title': titleCtl.text.trim(),
                  'course_type': courseType,
                  'exam_category': examCategory,
                  'chapter_id': chapterId,
                  'teacher': teacherCtl.text.trim(),
                  'schedule': scheduleCtl.text.trim(),
                  'lesson_count': lessonCount,
                  'description': descCtl.text.trim(),
                  'is_published': isPublished,
                };
                try {
                  await onSave(data, id: course?['id']);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(_adminErrorMessage(e, '保存课程失败'))),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  List<Chapter> _chaptersForCategory(String category) {
    return chapters
        .where((chapter) => chapter.examCategory == category)
        .toList();
  }

  String _chapterName(dynamic id) {
    if (id == null) return '未关联';
    for (final chapter in chapters) {
      if (chapter.id == id) return chapter.name;
    }
    return '未关联';
  }

  String _courseChapterText(Map<String, dynamic> course) {
    if (course['chapter_id'] == null) return '未关联';
    final name = (course['chapter_name'] ?? '').toString().trim();
    final count = course['chapter_question_count'] ?? 0;
    final label = name.isNotEmpty ? name : _chapterName(course['chapter_id']);
    return '$label · $count题';
  }
}

class _UserManager extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final List<String> examCategories;
  final List<Map<String, dynamic>> examCategoryTree;
  final TextEditingController keywordCtl;
  final String? selectedExamCategory;
  final bool? selectedActive;
  final ValueChanged<String?> onExamCategoryChanged;
  final ValueChanged<bool?> onActiveChanged;
  final Future<void> Function() onSearch;
  final Future<void> Function(Map<String, dynamic> data, {int? id}) onSave;
  final Future<void> Function(int id) onDelete;
  final Future<Map<String, dynamic>> Function(
    int userId, {
    String? examCategory,
    int days,
  }) onAnalyze;

  const _UserManager({
    required this.users,
    required this.examCategories,
    required this.examCategoryTree,
    required this.keywordCtl,
    required this.selectedExamCategory,
    required this.selectedActive,
    required this.onExamCategoryChanged,
    required this.onActiveChanged,
    required this.onSearch,
    required this.onSave,
    required this.onDelete,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '用户管理',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              Text(
                '共 ${users.length} 个用户',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              ElevatedButton.icon(
                onPressed: () => _showUserDialog(context),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('新增用户'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final fieldWidth =
                  compact ? constraints.maxWidth : constraints.maxWidth * 0.28;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: fieldWidth.clamp(220.0, 300.0),
                    child: TextField(
                      controller: keywordCtl,
                      decoration: const InputDecoration(
                        labelText: '搜索手机号 / 姓名',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onSubmitted: (_) => onSearch(),
                    ),
                  ),
                  SizedBox(
                    width: compact ? constraints.maxWidth : 560,
                    child: _ExamCategoryTreeSelect(
                      categories: examCategoryTree,
                      value: selectedExamCategory,
                      allLabel: '全部考试',
                      onChanged: onExamCategoryChanged,
                    ),
                  ),
                  SizedBox(
                    width: compact ? constraints.maxWidth : 150,
                    child: DropdownButtonFormField<bool?>(
                      value: selectedActive,
                      decoration: const InputDecoration(labelText: '账号状态'),
                      items: const [
                        DropdownMenuItem<bool?>(
                            value: null, child: Text('全部状态')),
                        DropdownMenuItem<bool?>(value: true, child: Text('启用')),
                        DropdownMenuItem<bool?>(
                            value: false, child: Text('停用')),
                      ],
                      onChanged: onActiveChanged,
                    ),
                  ),
                  SizedBox(
                    width: compact ? constraints.maxWidth : null,
                    child: ElevatedButton.icon(
                      onPressed: onSearch,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('查询'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (users.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: Center(
                child: Text(
                  '暂无用户',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else ...[
            const _DataHeader(
              columns: ['ID', '手机号', '姓名', '考试类别', '状态', '注册时间', '操作'],
              flexes: [1, 2, 2, 2, 1, 2, 2],
            ),
            ...users.map((user) {
              final active = user['is_active'] == true;
              return _DataRowCard(
                cells: [
                  '${user['id'] ?? ''}',
                  '${user['phone'] ?? user['username'] ?? '-'}',
                  '${user['full_name'] ?? '-'}',
                  '${user['target_exam'] ?? '-'}',
                  active ? '启用' : '停用',
                  _formatDate(user['created_at']),
                ],
                flexes: const [1, 2, 2, 2, 1, 2],
                actions: [
                  Switch(
                    value: active,
                    activeColor: AppTheme.success,
                    onChanged: (value) async {
                      try {
                        await onSave({'is_active': value}, id: user['id']);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_adminErrorMessage(e, '更新用户状态失败')),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    tooltip: '学习分析',
                    onPressed: () => _showLearningAnalysis(context, user),
                    icon: const Icon(Icons.insights_rounded,
                        color: AppTheme.primary),
                  ),
                  IconButton(
                    tooltip: '编辑用户',
                    onPressed: () => _showUserDialog(context, user),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                  IconButton(
                    tooltip: '删除用户',
                    onPressed: () => _confirmDelete(context, user),
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.error),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '-';
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  void _showLearningAnalysis(BuildContext context, Map<String, dynamic> user) {
    var days = 30;
    var category = (user['target_exam'] ?? '').toString();
    Future<Map<String, dynamic>> load() => onAnalyze(
          user['id'],
          examCategory: category.isEmpty ? null : category,
          days: days,
        );
    var future = load();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(22, 18, 14, 0),
          contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '学习分析 · ${user['full_name'] ?? user['phone'] ?? user['id']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          content: SizedBox(
            width: 920,
            height: MediaQuery.of(ctx).size.height * 0.78,
            child: Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 360,
                      child: DropdownButtonFormField<String>(
                        value: examCategories.contains(category)
                            ? category
                            : examCategories.first,
                        decoration: const InputDecoration(labelText: '分析考试类别'),
                        items: examCategories
                            .map((item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            category = value;
                            future = load();
                          });
                        },
                      ),
                    ),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 7, label: Text('7 天')),
                        ButtonSegment(value: 30, label: Text('30 天')),
                        ButtonSegment(value: 90, label: Text('90 天')),
                      ],
                      selected: {days},
                      onSelectionChanged: (value) {
                        setDialogState(() {
                          days = value.first;
                          future = load();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _AdminInlineError(
                          message:
                              _adminErrorMessage(snapshot.error!, '学习分析加载失败'),
                          onRetry: () async {
                            setDialogState(() => future = load());
                          },
                        );
                      }
                      return _LearningAnalysisPanel(
                        data: snapshot.data ?? const {},
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserDialog(BuildContext context, [Map<String, dynamic>? user]) {
    final isCreate = user == null;
    final phoneCtl = TextEditingController(
        text: '${user?['phone'] ?? user?['username'] ?? ''}');
    final nameCtl = TextEditingController(text: '${user?['full_name'] ?? ''}');
    final passwordCtl = TextEditingController();
    var targetExam = (user?['target_exam'] ?? examCategories.first).toString();
    if (!examCategories.contains(targetExam)) {
      targetExam = examCategories.first;
    }
    var isActive = user?['is_active'] != false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isCreate ? '新增用户' : '编辑用户'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: phoneCtl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: '手机号',
                      prefixIcon: Icon(Icons.phone_iphone_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtl,
                    decoration: const InputDecoration(
                      labelText: '姓名',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: isCreate ? '初始密码' : '新密码（留空不修改）',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ExamCategoryTreeSelect(
                    categories: examCategoryTree,
                    value: targetExam,
                    allLabel: '',
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => targetExam = value);
                    },
                  ),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (value) =>
                        setDialogState(() => isActive = value),
                    title: const Text('启用账号'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final phone = phoneCtl.text.trim();
                if (phone.length != 11 || int.tryParse(phone) == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('请输入正确的 11 位手机号')),
                  );
                  return;
                }
                final password = passwordCtl.text;
                if (isCreate && password.length < 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('初始密码至少 6 位')),
                  );
                  return;
                }
                final data = {
                  'phone': phone,
                  'full_name': nameCtl.text.trim(),
                  'target_exam': targetExam,
                  'is_active': isActive,
                  if (password.isNotEmpty) 'password': password,
                };
                try {
                  await onSave(data, id: user?['id']);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(_adminErrorMessage(e, '保存用户失败'))),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除用户'),
        content: Text(
          '确定删除用户「${user['phone'] ?? user['username'] ?? user['id']}」吗？删除后该用户的登录账号将不可用。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await onDelete(user['id']);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_adminErrorMessage(e, '删除用户失败'))),
        );
      }
    }
  }
}

class _LearningAnalysisPanel extends StatelessWidget {
  final Map<String, dynamic> data;

  const _LearningAnalysisPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from(data['user'] ?? const {});
    final overview = Map<String, dynamic>.from(data['overview'] ?? const {});
    final today = Map<String, dynamic>.from(data['today'] ?? const {});
    final wrong = Map<String, dynamic>.from(data['wrong'] ?? const {});
    final exam = Map<String, dynamic>.from(data['exam'] ?? const {});
    final ai = Map<String, dynamic>.from(data['ai'] ?? const {});
    final weakChapters =
        List<Map<String, dynamic>>.from(data['weak_chapters'] ?? const []);
    final trend = List<Map<String, dynamic>>.from(data['trend'] ?? const []);
    final recentExams =
        List<Map<String, dynamic>>.from(exam['recent'] ?? const []);
    final advice = List<String>.from(data['advice'] ?? const []);
    final hasLearningData = (overview['total_questions'] ?? 0) > 0 ||
        (overview['period_questions'] ?? 0) > 0 ||
        (overview['period_study_time'] ?? 0) > 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withOpacity(0.10)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary.withOpacity(0.12),
                  child:
                      const Icon(Icons.person_rounded, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user['full_name'] ?? '未填写姓名'} · ${user['phone'] ?? user['username'] ?? '-'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${data['exam_category'] ?? user['target_exam'] ?? '-'} · ${user['is_active'] == false ? '停用' : '启用'} · 注册 ${_shortDate(user['created_at'])}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard.compact(
                  label: '累计做题',
                  value: '${overview['total_questions'] ?? 0}',
                  color: AppTheme.primary),
              _MetricCard.compact(
                  label: '综合正确率',
                  value: _percent(overview['accuracy_rate']),
                  color: AppTheme.success),
              _MetricCard.compact(
                  label: '活跃天数',
                  value: '${overview['active_days'] ?? 0}',
                  color: AppTheme.accent),
              _MetricCard.compact(
                  label: '待复习错题',
                  value: '${wrong['pending'] ?? 0}',
                  color: Colors.orange),
              _MetricCard.compact(
                  label: '模考次数',
                  value: '${exam['count'] ?? 0}',
                  color: Colors.indigo),
              _MetricCard.compact(
                  label: 'AI 提问',
                  value: '${ai['question_count'] ?? 0}',
                  color: Colors.purple),
            ],
          ),
          const SizedBox(height: 18),
          _SectionTitle(
            title: '今日学习',
            subtitle:
                '${today['total_questions'] ?? 0} 题 · 正确率 ${_percent(today['accuracy_rate'])} · 学习 ${_minutes(today['time_spent'])} 分钟 · AI ${today['ai_questions'] ?? 0} 次',
          ),
          if (!hasLearningData) const _EmptyHint(text: '该学员暂无学习记录'),
          const SizedBox(height: 16),
          _SectionTitle(
            title: '近 ${data['days'] ?? 30} 天学习趋势',
            subtitle:
                '周期内 ${overview['period_questions'] ?? 0} 题 · 正确率 ${_percent(overview['period_accuracy'])} · 学习 ${_minutes(overview['period_study_time'])} 分钟',
          ),
          const SizedBox(height: 8),
          if (trend.isEmpty)
            const _EmptyHint(text: '该学员暂无学习记录')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: trend
                  .where((item) =>
                      (item['total_questions'] ?? 0) > 0 ||
                      (item['time_spent'] ?? 0) > 0)
                  .take(14)
                  .map(
                    (item) => Chip(
                      label: Text(
                        '${_shortDate(item['date'])}：${item['total_questions'] ?? 0}题 / ${_percent(item['accuracy_rate'])}',
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 18),
          const _SectionTitle(title: '薄弱章节排行'),
          const SizedBox(height: 8),
          if (weakChapters.isEmpty)
            const _EmptyHint(text: '该学员暂无章节练习记录')
          else
            ...weakChapters.map(
              (item) => _AnalysisListTile(
                icon: Icons.warning_amber_rounded,
                title: '${item['chapter_name'] ?? '-'}',
                subtitle:
                    '${item['total_questions'] ?? 0} 题 · 错 ${item['wrong_count'] ?? 0} 题',
                trailing: _percent(item['accuracy_rate']),
                color: AppTheme.error,
              ),
            ),
          const SizedBox(height: 18),
          const _SectionTitle(title: '错题与模考'),
          const SizedBox(height: 8),
          _AnalysisListTile(
            icon: Icons.assignment_late_rounded,
            title: '错题本',
            subtitle:
                '总错题 ${wrong['total'] ?? 0} · 已掌握 ${wrong['mastered'] ?? 0} · 复习 ${wrong['review_count'] ?? 0} 次',
            trailing: '${wrong['pending'] ?? 0} 待复习',
            color: Colors.orange,
          ),
          if (recentExams.isEmpty)
            const _EmptyHint(text: '该学员暂无模考记录')
          else
            ...recentExams.map(
              (item) => _AnalysisListTile(
                icon: Icons.fact_check_rounded,
                title: '模考 ${_shortDate(item['created_at'])}',
                subtitle:
                    '${item['total_questions'] ?? 0} 题 · 对 ${item['correct_count'] ?? 0} · 错 ${item['wrong_count'] ?? 0}',
                trailing:
                    '${item['score'] ?? 0} 分 / ${_percent(item['accuracy_rate'])}',
                color: Colors.indigo,
              ),
            ),
          const SizedBox(height: 18),
          const _SectionTitle(title: 'AI 学习使用'),
          const SizedBox(height: 8),
          _AnalysisListTile(
            icon: Icons.auto_awesome_rounded,
            title: 'AI 辅助学习',
            subtitle:
                '会话 ${ai['session_count'] ?? 0} · 收藏 ${ai['collection_count'] ?? 0} · 知识卡 ${ai['knowledge_card_count'] ?? 0}',
            trailing: '${ai['question_count'] ?? 0} 提问',
            color: Colors.purple,
          ),
          const SizedBox(height: 18),
          const _SectionTitle(title: '运营跟进建议'),
          const SizedBox(height: 8),
          if (advice.isEmpty)
            const _EmptyHint(text: '暂无建议')
          else
            ...advice.map(
              (item) => _AnalysisListTile(
                icon: Icons.lightbulb_outline_rounded,
                title: item,
                subtitle: '基于学习活跃、正确率、错题、模考和 AI 使用自动判断',
                color: AppTheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  static String _percent(dynamic value) {
    final number = value is num ? value.toDouble() : 0.0;
    return '${(number * 100).round()}%';
  }

  static int _minutes(dynamic value) {
    final seconds = value is num ? value.toInt() : 0;
    return (seconds / 60).round();
  }

  static String _shortDate(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '-';
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Text(text, style: const TextStyle(color: AppTheme.textSecondary)),
    );
  }
}

class _AnalysisListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;
  final Color color;

  const _AnalysisListTile({
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.trailing,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      )),
                ],
              ],
            ),
          ),
          if (trailing != null)
            Text(trailing!,
                style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ExamCategoryManager extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final Future<void> Function(Map<String, dynamic> data, {int? id}) onSave;
  final Future<void> Function(int id) onDelete;

  const _ExamCategoryManager({
    required this.categories,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '考试类别管理',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              Text(
                '共 ${categories.length} 个类别',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('新增考试类别'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42),
              child: Center(
                child: Text(
                  '暂无考试类别',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else ...[
            const _DataHeader(
              columns: ['ID', '层级', '考试类别', '上级', '排序', '状态', '操作'],
              flexes: [1, 1, 3, 2, 1, 1, 2],
            ),
            ...categories.map(
              (category) {
                final active = category['is_active'] != false;
                final name = '${category['name'] ?? ''}';
                final level = category['level'] ?? 1;
                return _DataRowCard(
                  cells: [
                    '${category['id'] ?? ''}',
                    _levelLabel(level),
                    name,
                    _parentName(category['parent_id']),
                    '${category['sort_order'] ?? 0}',
                    active ? '启用' : '停用',
                  ],
                  flexes: const [1, 1, 3, 2, 1, 1],
                  actions: [
                    IconButton(
                      tooltip: '编辑类别',
                      onPressed: () => _showCategoryDialog(context, category),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    IconButton(
                      tooltip: name == '执业资格' ? '默认类别不可删除' : '删除类别',
                      onPressed: name == '执业资格'
                          ? null
                          : () => _confirmDeleteCategory(context, category),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: name == '执业资格'
                            ? AppTheme.textSecondary
                            : AppTheme.error,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showCategoryDialog(
    BuildContext context, [
    Map<String, dynamic>? category,
  ]) {
    final nameCtl = TextEditingController(text: '${category?['name'] ?? ''}');
    final descCtl =
        TextEditingController(text: '${category?['description'] ?? ''}');
    final sortCtl =
        TextEditingController(text: '${category?['sort_order'] ?? 0}');
    var level = category?['level'] ?? 1;
    int? parentId = category?['parent_id'];
    var isActive = category?['is_active'] != false;
    final isDefault =
        category?['name'] == '执业资格' || category?['name'] == '临床执业医师';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(category == null ? '新增考试类别' : '编辑考试类别'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtl,
                    decoration: const InputDecoration(
                      labelText: '考试类别名称',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '描述',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: level,
                    decoration: const InputDecoration(
                      labelText: '层级',
                      prefixIcon: Icon(Icons.account_tree_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('一级大类')),
                      DropdownMenuItem(value: 2, child: Text('二级分组')),
                      DropdownMenuItem(value: 3, child: Text('三级考试项目')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        level = value;
                        parentId = null;
                      });
                    },
                  ),
                  if (level > 1) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: categories.any((item) => item['id'] == parentId)
                          ? parentId
                          : null,
                      decoration: const InputDecoration(
                        labelText: '上级类别',
                        prefixIcon:
                            Icon(Icons.subdirectory_arrow_right_rounded),
                      ),
                      items: categories
                          .where((item) => item['level'] == level - 1)
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item['id'],
                              child: Text('${item['name']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => parentId = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: sortCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '排序',
                      prefixIcon: Icon(Icons.sort_rounded),
                    ),
                  ),
                  SwitchListTile(
                    value: isActive,
                    onChanged: isDefault
                        ? null
                        : (value) => setDialogState(() => isActive = value),
                    title: Text(isDefault ? '默认类别必须启用' : '启用类别'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtl.text.trim();
                final sortOrder = int.tryParse(sortCtl.text.trim());
                if (name.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('请输入考试类别名称')),
                  );
                  return;
                }
                if (sortOrder == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('排序必须是整数')),
                  );
                  return;
                }
                if (level > 1 && parentId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('请选择上级类别')),
                  );
                  return;
                }
                try {
                  await onSave(
                    {
                      'name': name,
                      'parent_id': level == 1 ? null : parentId,
                      'level': level,
                      'description': descCtl.text.trim(),
                      'sort_order': sortOrder,
                      'is_active': isDefault ? true : isActive,
                    },
                    id: category?['id'],
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(_adminErrorMessage(e, '保存考试类别失败')),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCategory(
    BuildContext context,
    Map<String, dynamic> category,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除考试类别'),
        content: Text(
          '确定删除考试类别「${category['name'] ?? category['id']}」吗？已有用户、课程、题目或学习记录的类别不能删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await onDelete(category['id']);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_adminErrorMessage(e, '删除考试类别失败')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  String _levelLabel(dynamic level) {
    if (level == 3) return '三级';
    if (level == 2) return '二级';
    return '一级';
  }

  String _parentName(dynamic parentId) {
    if (parentId == null) return '-';
    for (final item in categories) {
      if (item['id'] == parentId) return '${item['name'] ?? '-'}';
    }
    return '-';
  }
}

class _DashboardManager extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<String> examCategories;
  final String? selectedExamCategory;
  final String selectedDate;
  final ValueChanged<String?> onExamCategoryChanged;
  final ValueChanged<String> onDateChanged;

  const _DashboardManager({
    required this.data,
    required this.examCategories,
    required this.selectedExamCategory,
    required this.selectedDate,
    required this.onExamCategoryChanged,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categories =
        List<Map<String, dynamic>>.from(data['user_categories'] ?? const []);
    final chapters =
        List<Map<String, dynamic>>.from(data['chapter_activity'] ?? const []);
    final accuracy = ((data['today_accuracy'] ?? 0) * 100).round();
    final metrics = [
      _MetricCard.compact(
          label: '用户总数',
          value: '${data['user_count'] ?? 0}',
          color: AppTheme.primary),
      _MetricCard.compact(
          label: '今日活跃',
          value: '${data['today_active_users'] ?? 0}',
          color: AppTheme.accent),
      _MetricCard.compact(
          label: '今日做题',
          value: '${data['today_questions'] ?? 0}',
          color: AppTheme.success),
      _MetricCard.compact(
          label: '今日正确率', value: '$accuracy%', color: AppTheme.error),
      _MetricCard.compact(
          label: '错题复习',
          value: '${data['wrong_review_count'] ?? 0}',
          color: Colors.orange),
      _MetricCard.compact(
          label: '课程数量',
          value: '${data['course_count'] ?? 0}',
          color: AppTheme.primaryLight),
      _MetricCard.compact(
          label: '今日 AI 提问',
          value: '${data['today_ai_questions'] ?? 0}',
          color: Colors.purple),
      _MetricCard.compact(
          label: 'AI 会话数',
          value: '${data['ai_session_count'] ?? 0}',
          color: Colors.indigo),
      _MetricCard.compact(
          label: 'AI 收藏数',
          value: '${data['ai_collection_count'] ?? 0}',
          color: Colors.teal),
    ];
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '运营数据看板',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  value: selectedExamCategory,
                  decoration: const InputDecoration(labelText: '考试分类'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('全部考试'),
                    ),
                    ...examCategories.map(
                      (item) => DropdownMenuItem<String?>(
                        value: item,
                        child: Text(item),
                      ),
                    ),
                  ],
                  onChanged: onExamCategoryChanged,
                ),
              ),
              SizedBox(
                width: 170,
                child: TextFormField(
                  initialValue: selectedDate,
                  decoration: const InputDecoration(
                    labelText: '统计日期',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: Icon(Icons.today_rounded, size: 18),
                  ),
                  onFieldSubmitted: (value) {
                    final date = value.trim();
                    if (date.isNotEmpty) onDateChanged(date);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: metrics),
          const SizedBox(height: 22),
          const Text('考试分类用户分布',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (categories.isEmpty)
            const Text('暂无用户分布数据',
                style: TextStyle(color: AppTheme.textSecondary))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categories
                  .map((item) => Chip(
                        label: Text('${item['name']}：${item['count']} 人'),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 22),
          const Text('章节题量 / 练习热度',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (chapters.isEmpty)
            const Text('暂无章节数据',
                style: TextStyle(color: AppTheme.textSecondary))
          else ...[
            const _DataHeader(
              columns: ['章节', '考试类别', '题量', '练习次数'],
              flexes: [3, 2, 1, 1],
            ),
            ...chapters.map(
              (row) => _DataRowCard(
                cells: [
                  '${row['name'] ?? '-'}',
                  '${row['exam_category'] ?? '-'}',
                  '${row['question_count'] ?? 0}',
                  '${row['practice_count'] ?? 0}',
                ],
                flexes: const [3, 2, 1, 1],
                actions: const [],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DataHeader extends StatelessWidget {
  final List<String> columns;
  final List<int> flexes;

  const _DataHeader({required this.columns, required this.flexes});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 820 ? 820.0 : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < columns.length; i++)
                    Expanded(
                      flex: flexes[i],
                      child: Text(
                        columns[i],
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DataRowCard extends StatelessWidget {
  final List<String> cells;
  final List<int> flexes;
  final List<Widget> actions;

  const _DataRowCard({
    required this.cells,
    required this.flexes,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 820 ? 820.0 : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.divider)),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < cells.length; i++)
                    Expanded(
                      flex: flexes[i],
                      child: Text(
                        cells[i],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            height: 1.35),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: Row(children: actions),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
