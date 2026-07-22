import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers/question_provider.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/app_glass.dart';

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
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: course.isLive
                ? ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_active_rounded,
                        size: 18),
                    label: const Text('预约直播'),
                  )
                : OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('开始学习'),
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
  final String typeLabel;
  final String level;
  final IconData icon;
  final Color color;
  final bool isLive;

  const _Course({
    required this.id,
    required this.title,
    required this.teacher,
    required this.time,
    required this.lessons,
    required this.typeLabel,
    required this.level,
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
      typeLabel: isLive ? '直播' : '录播',
      level: json['exam_category'] ?? '',
      icon: isLive ? Icons.live_tv_rounded : Icons.video_library_rounded,
      color: isLive ? AppTheme.error : AppTheme.primary,
      isLive: isLive,
    );
  }
}
