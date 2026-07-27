import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers/question_provider.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/app_glass.dart';
import '../practice/practice_screen.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _api = ApiService();
  var _isLoading = true;
  String? _error;
  List<_Course> _liveCourses = [];
  List<_Course> _recordedCourses = [];
  String? _loadedExamCategory;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCourses(context.read<QuestionProvider>().examCategory);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final examCategory = context.watch<QuestionProvider>().examCategory;
    if (_loadedExamCategory != examCategory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadCourses(examCategory);
      });
    }

    return GlassScaffold(
      appBar: AppBar(
        title: const Text('视频课程'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            height: 40,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider.withOpacity(0.8)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: '直播课'),
                Tab(text: '录播课'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _isLoading
            ? const [
                Center(child: CircularProgressIndicator()),
                Center(child: CircularProgressIndicator()),
              ]
            : [
                _CourseList(
                  courses: _liveCourses,
                  emptyText: _error ?? '暂无课程',
                ),
                _CourseList(
                  courses: _recordedCourses,
                  emptyText: _error ?? '暂无课程',
                ),
              ],
      ),
    );
  }

  Future<void> _loadCourses(String examCategory) async {
    final requestId = ++_loadRequestId;
    setState(() {
      _isLoading = true;
      _error = null;
      _loadedExamCategory = examCategory;
    });
    try {
      final responses = await Future.wait([
        _api.getPublishedCourses(
          courseType: 'live',
          examCategory: examCategory,
        ),
        _api.getPublishedCourses(
          courseType: 'recorded',
          examCategory: examCategory,
        ),
      ]);
      if (!mounted || requestId != _loadRequestId) return;
      final liveRes = responses[0];
      final recordedRes = responses[1];
      _liveCourses = List<Map<String, dynamic>>.from(liveRes.data)
          .map(_Course.fromJson)
          .toList();
      _recordedCourses = List<Map<String, dynamic>>.from(recordedRes.data)
          .map(_Course.fromJson)
          .toList();
    } catch (_) {
      if (!mounted || requestId != _loadRequestId) return;
      _error = '课程加载失败，请稍后重试';
      _liveCourses = [];
      _recordedCourses = [];
    } finally {
      if (mounted && requestId == _loadRequestId) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _CourseList extends StatelessWidget {
  final List<_Course> courses;
  final String emptyText;

  const _CourseList({required this.courses, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return Center(
        child: Text(emptyText,
            style: const TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      itemCount: courses.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _CourseCard(course: courses[index]),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final _Course course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _CourseDetailScreen(course: course)),
      ),
      padding: const EdgeInsets.all(16),
      tint: Colors.white.withOpacity(0.82),
      borderColor: AppTheme.divider.withOpacity(0.72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      course.color,
                      course.color.withOpacity(0.62),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(course.icon, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Badge(label: course.typeLabel, color: course.color),
                        const SizedBox(width: 8),
                        Text(
                          course.level,
                          style: const TextStyle(
                            color: AppTheme.textHint,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      course.teacher,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Meta(icon: Icons.schedule_rounded, text: course.time),
              const SizedBox(width: 14),
              _Meta(
                  icon: Icons.play_circle_outline_rounded,
                  text: course.lessons),
              const SizedBox(width: 14),
              _Meta(
                icon: Icons.quiz_rounded,
                text: course.chapterId == null ? '未关联题库' : '已关联题库',
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: course.isLive
                ? ElevatedButton.icon(
                    onPressed: () => _startCoursePractice(context),
                    icon: const Icon(Icons.notifications_active_rounded,
                        size: 18),
                    label: const Text('查看详情'),
                  )
                : OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => _CourseDetailScreen(course: course)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('进入课程'),
                  ),
          ),
        ],
      ),
    );
  }

  void _startCoursePractice(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _CourseDetailScreen(course: course)),
    );
  }
}

class _CourseDetailScreen extends StatelessWidget {
  final _Course course;

  const _CourseDetailScreen({required this.course});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: AppBar(title: const Text('课程详情')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              padding: const EdgeInsets.all(18),
              tint: Colors.white.withOpacity(0.84),
              borderColor: AppTheme.divider.withOpacity(0.72),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: course.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(course.icon, color: course.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _Badge(
                                    label: course.typeLabel,
                                    color: course.color),
                                const SizedBox(width: 8),
                                Text(course.level,
                                    style: const TextStyle(
                                        color: AppTheme.textHint,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              course.title,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 20,
                                height: 1.28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(course.teacher,
                      style: const TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Text(course.time,
                      style: const TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 14),
                  Text(
                    course.description.isEmpty
                        ? '本课程围绕考试大纲重点章节展开，建议先做课前摸底，再学习课程内容，最后完成课后练习。'
                        : course.description,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '学习闭环',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _CourseLoopStep(
              index: '1',
              title: '课前摸底',
              subtitle: course.chapterId == null
                  ? '该课程暂未关联章节，无法生成课前练习'
                  : '先做未做题，快速判断这节课该重点听什么',
              buttonText: '开始课前练习',
              enabled: course.chapterId != null,
              onTap: () =>
                  _startPractice(context, mode: 'unanswered', title: '课前摸底'),
            ),
            const SizedBox(height: 10),
            _CourseLoopStep(
              index: '2',
              title: '学习课程',
              subtitle: course.isLive
                  ? '按直播安排跟学，课后马上做题巩固'
                  : '完成 ${course.lessons}，建议边听边记录错题知识点',
              buttonText: course.isLive ? '查看直播安排' : '开始学习课程',
              enabled: true,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(course.isLive
                        ? '直播安排：${course.time}'
                        : '课程播放功能将在下一阶段接入'),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _CourseLoopStep(
              index: '3',
              title: '课后练习',
              subtitle: course.chapterId == null
                  ? '该课程暂未关联章节题库'
                  : '围绕关联章节刷题，形成“课程 → 练习 → 错题复习”',
              buttonText: '开始课后练习',
              enabled: course.chapterId != null,
              onTap: () =>
                  _startPractice(context, mode: 'chapter', title: '课后练习'),
            ),
            const SizedBox(height: 10),
            _CourseLoopStep(
              index: '4',
              title: '错题复习',
              subtitle: '课后练习答错的题会进入错题本，后续可集中复习',
              buttonText: '复习错题',
              enabled: true,
              onTap: () =>
                  _startPractice(context, mode: 'wrong', title: '课程错题复习'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startPractice(
    BuildContext context, {
    required String mode,
    required String title,
  }) async {
    if (course.chapterId == null && mode != 'wrong') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该课程暂未关联章节题库')),
      );
      return;
    }
    final provider = context.read<QuestionProvider>();
    await provider.loadPracticeQuestions(
      chapterId: mode == 'wrong' ? null : course.chapterId,
      mode: mode,
      title: '${course.title} · $title',
    );
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PracticeScreen()),
    );
  }
}

class _CourseLoopStep extends StatelessWidget {
  final String index;
  final String title;
  final String subtitle;
  final String buttonText;
  final bool enabled;
  final VoidCallback onTap;

  const _CourseLoopStep({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      tint: Colors.white.withOpacity(0.78),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: enabled
                      ? AppTheme.primary.withOpacity(0.12)
                      : AppTheme.textHint.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  index,
                  style: TextStyle(
                    color: enabled ? AppTheme.primary : AppTheme.textHint,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: enabled ? onTap : null,
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textHint),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Course {
  final int id;
  final String title;
  final String teacher;
  final String time;
  final String lessons;
  final String description;
  final String typeLabel;
  final String level;
  final int? chapterId;
  final IconData icon;
  final Color color;
  final bool isLive;

  const _Course({
    required this.id,
    required this.title,
    required this.teacher,
    required this.time,
    required this.lessons,
    required this.description,
    required this.typeLabel,
    required this.level,
    required this.chapterId,
    required this.icon,
    required this.color,
    required this.isLive,
  });

  factory _Course.fromJson(Map<String, dynamic> json) {
    final type = json['course_type'] ?? 'recorded';
    final isLive = type == 'live';
    return _Course(
      id: json['id'],
      title: json['title'] ?? '',
      teacher: '主讲：${json['teacher'] ?? ''}',
      time: json['schedule'] ?? '',
      lessons: isLive ? '直播课' : '${json['lesson_count'] ?? 0} 讲',
      description: json['description'] ?? '',
      typeLabel: isLive ? '直播' : '录播',
      level: json['exam_category'] ?? '',
      chapterId: json['chapter_id'],
      icon: isLive ? Icons.live_tv_rounded : Icons.video_library_rounded,
      color: isLive ? AppTheme.error : AppTheme.primary,
      isLive: isLive,
    );
  }
}
