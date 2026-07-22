import 'package:flutter/material.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chapter.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/app_glass.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _api = ApiService();
  final _keywordCtl = TextEditingController();
  Map<String, dynamic>? _admin;
  var _isCheckingAuth = true;
  var _tab = 0;
  var _isLoading = false;
  var _selectedExamCategory = AppConstants.examCategories.first;
  int? _selectedChapterId;
  List<Chapter> _chapters = [];
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    _checkAdminAuth();
  }

  @override
  void dispose() {
    _keywordCtl.dispose();
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
    });
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final questionRes = await _api.getAdminQuestions(
        keyword: _keywordCtl.text.trim(),
        examCategory: _selectedExamCategory,
        chapterId: _selectedChapterId,
      );
      final chapterRes = await _api.getChapters();
      final courseRes = await _api.getAdminCourses();
      _chapters = (chapterRes.data as List)
          .map((json) => Chapter.fromJson(json))
          .toList();
      _questions = List<Map<String, dynamic>>.from(questionRes.data);
      _courses = List<Map<String, dynamic>>.from(courseRes.data);
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
        child: Row(
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
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _MetricRow(
                                  questions: _questions.length,
                                  liveCourses: _courses
                                      .where((c) => c['course_type'] == 'live')
                                      .length,
                                  recordedCourses: _courses
                                      .where(
                                          (c) => c['course_type'] == 'recorded')
                                      .length,
                                ),
                                const SizedBox(height: 20),
                                if (_tab == 0)
                                  _QuestionManager(
                                    questions: _questions,
                                    chapters: _chapters,
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
                                      setState(
                                          () => _selectedChapterId = chapterId);
                                      _loadAll();
                                    },
                                    onSearch: _loadAll,
                                    onSave: _saveQuestion,
                                    onDelete: _deleteQuestion,
                                  )
                                else
                                  _CourseManager(
                                    courses: _courses,
                                    onSave: _saveCourse,
                                    onDelete: _deleteCourse,
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveQuestion(Map<String, dynamic> data, {int? id}) async {
    if (id == null) {
      await _api.createAdminQuestion(data);
    } else {
      await _api.updateAdminQuestion(id, data);
    }
    await _loadAll();
  }

  Future<void> _deleteQuestion(int id) async {
    await _api.deleteAdminQuestion(id);
    await _loadAll();
  }

  Future<void> _saveCourse(Map<String, dynamic> data, {int? id}) async {
    if (id == null) {
      await _api.createAdminCourse(data);
    } else {
      await _api.updateAdminCourse(id, data);
    }
    await _loadAll();
  }

  Future<void> _deleteCourse(int id) async {
    await _api.deleteAdminCourse(id);
    await _loadAll();
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
                    onPressed: () {
                      setState(() {
                        _usernameCtl.text = 'admin';
                        _passwordCtl.text = 'admin123';
                        _error = null;
                      });
                    },
                    icon: const Icon(Icons.account_circle_outlined, size: 18),
                    label: const Text('使用演示账号 admin / admin123'),
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
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/'),
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
          const Expanded(
            child: Text(
              '题库与课程管理',
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
  final int liveCourses;
  final int recordedCourses;

  const _MetricRow({
    required this.questions,
    required this.liveCourses,
    required this.recordedCourses,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MetricCard(
            label: '题目总数', value: '$questions', color: AppTheme.primary),
        const SizedBox(width: 12),
        _MetricCard(label: '直播课', value: '$liveCourses', color: AppTheme.error),
        const SizedBox(width: 12),
        _MetricCard(
            label: '录播课', value: '$recordedCourses', color: AppTheme.success),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
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
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text(label,
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionManager extends StatelessWidget {
  final List<Map<String, dynamic>> questions;
  final List<Chapter> chapters;
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
    final categoryChapters = _chaptersForCategory(selectedExamCategory);
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
                width: 170,
                child: DropdownButtonFormField<String>(
                  value: selectedExamCategory,
                  decoration: const InputDecoration(
                    labelText: '考试科目',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: AppConstants.examCategories
                      .map((category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
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
            columns: const ['ID', '考试科目', '题干', '类型', '难度', '答案', '操作'],
            flexes: const [1, 2, 5, 1, 1, 1, 2],
          ),
          ...questions.map(
            (question) => _DataRowCard(
              cells: [
                '${question['id']}',
                _chapterName(question['chapter_id']),
                question['content'] ?? '',
                _questionTypeLabel(question['question_type']),
                '${question['difficulty'] ?? 3}',
                question['answer'] ?? '',
              ],
              flexes: const [1, 2, 5, 1, 1, 1],
              actions: [
                IconButton(
                  tooltip: '编辑',
                  onPressed: () => _showQuestionDialog(context, question),
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: () => onDelete(question['id']),
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

  void _showQuestionDialog(BuildContext context,
      [Map<String, dynamic>? question]) {
    final initialExamCategory = question == null
        ? selectedExamCategory
        : _categoryForChapterId(question?['chapter_id']) ??
            selectedExamCategory;
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(question == null ? '新增题目' : '编辑题目'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: dialogExamCategory,
                          decoration: const InputDecoration(
                            labelText: '考试科目',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: AppConstants.examCategories
                              .map((category) => DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(category),
                                  ))
                              .toList(),
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
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
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
                      ),
                    ],
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
                  '知识点': question?['知识点'] ?? [],
                };
                await onSave(data, id: question?['id']);
                if (ctx.mounted) Navigator.pop(ctx);
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
  final Future<void> Function(Map<String, dynamic> data, {int? id}) onSave;
  final Future<void> Function(int id) onDelete;

  const _CourseManager({
    required this.courses,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              const Text('课程管理',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCourseDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('新增课程'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DataHeader(
            columns: const ['ID', '课程名称', '类型', '考试', '讲师', '课时', '状态', '操作'],
            flexes: const [1, 4, 1, 1, 2, 1, 1, 2],
          ),
          ...courses.map(
            (course) => _DataRowCard(
              cells: [
                '${course['id']}',
                course['title'] ?? '',
                course['course_type'] == 'live' ? '直播' : '录播',
                course['exam_category'] ?? '',
                course['teacher'] ?? '',
                '${course['lesson_count'] ?? 0}',
                course['is_published'] == true ? '已发布' : '未发布',
              ],
              flexes: const [1, 4, 1, 1, 2, 1, 1],
              actions: [
                IconButton(
                  tooltip: '编辑',
                  onPressed: () => _showCourseDialog(context, course),
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: () => onDelete(course['id']),
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

  void _showCourseDialog(BuildContext context, [Map<String, dynamic>? course]) {
    final titleCtl = TextEditingController(text: course?['title'] ?? '');
    final teacherCtl = TextEditingController(text: course?['teacher'] ?? '');
    final scheduleCtl = TextEditingController(text: course?['schedule'] ?? '');
    final lessonCtl =
        TextEditingController(text: '${course?['lesson_count'] ?? 1}');
    final descCtl = TextEditingController(text: course?['description'] ?? '');
    var courseType = course?['course_type'] ?? 'recorded';
    var examCategory = course?['exam_category'] ?? '执业资格';
    var isPublished = course?['is_published'] ?? true;

    showDialog(
      context: context,
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
                        child: DropdownButtonFormField<String>(
                          value: examCategory,
                          decoration: const InputDecoration(labelText: '考试类型'),
                          items: const ['执业资格', '初级职称', '中级职称', '高级职称']
                              .map((item) => DropdownMenuItem(
                                  value: item, child: Text(item)))
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => examCategory = value!),
                        ),
                      ),
                    ],
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
                final data = {
                  'title': titleCtl.text.trim(),
                  'course_type': courseType,
                  'exam_category': examCategory,
                  'teacher': teacherCtl.text.trim(),
                  'schedule': scheduleCtl.text.trim(),
                  'lesson_count': int.tryParse(lessonCtl.text.trim()) ?? 1,
                  'description': descCtl.text.trim(),
                  'is_published': isPublished,
                };
                await onSave(data, id: course?['id']);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
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
    return Container(
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
    return Container(
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
                    color: AppTheme.textPrimary, fontSize: 13, height: 1.35),
              ),
            ),
          Expanded(
            flex: 2,
            child: Row(children: actions),
          ),
        ],
      ),
    );
  }
}
