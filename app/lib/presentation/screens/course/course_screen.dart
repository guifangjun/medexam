import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers/question_provider.dart';
import '../../widgets/app_glass.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final examCategory = context.watch<QuestionProvider>().examCategory;

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
        children: [
          _CourseList(
            courses: _CourseCatalog.live(examCategory),
            emptyText: '暂无直播课',
          ),
          _CourseList(
            courses: _CourseCatalog.recorded(examCategory),
            emptyText: '暂无录播课',
          ),
        ],
      ),
    );
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

class _CourseCatalog {
  static List<_Course> live(String category) => [
        _Course(
          title: '$category考前高频考点直播',
          teacher: '主讲：三甲医院教研组',
          time: '今晚 20:00',
          lessons: '90 分钟',
          typeLabel: '直播',
          level: category,
          icon: Icons.live_tv_rounded,
          color: AppTheme.error,
          isLive: true,
        ),
        _Course(
          title: '$category病例题解题策略',
          teacher: '主讲：临床命题研究老师',
          time: '明晚 19:30',
          lessons: '75 分钟',
          typeLabel: '直播',
          level: category,
          icon: Icons.groups_rounded,
          color: AppTheme.accent,
          isLive: true,
        ),
      ];

  static List<_Course> recorded(String category) => [
        _Course(
          title: '$category核心基础精讲',
          teacher: '系统课 · 按大纲章节拆解',
          time: '随到随学',
          lessons: '32 讲',
          typeLabel: '录播',
          level: category,
          icon: Icons.video_library_rounded,
          color: AppTheme.primary,
          isLive: false,
        ),
        _Course(
          title: '$category真题与错题专题课',
          teacher: '专题课 · 高频错点复盘',
          time: '随到随学',
          lessons: '18 讲',
          typeLabel: '录播',
          level: category,
          icon: Icons.smart_display_rounded,
          color: AppTheme.success,
          isLive: false,
        ),
        _Course(
          title: '$category冲刺串讲课',
          teacher: '冲刺课 · 考前快速提分',
          time: '随到随学',
          lessons: '12 讲',
          typeLabel: '录播',
          level: category,
          icon: Icons.rocket_launch_rounded,
          color: AppTheme.accent,
          isLive: false,
        ),
      ];
}

class _Course {
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
}
