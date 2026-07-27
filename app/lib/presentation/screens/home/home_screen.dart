import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/question_provider.dart';
import '../../../data/providers/study_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/app_glass.dart';
import '../practice/practice_screen.dart';
import '../exam/exam_screen.dart';
import '../ai_chat/ai_chat_screen.dart';
import '../course/course_screen.dart';
import '../study/study_screen.dart';
import '../stats/stats_screen.dart';
import '../auth/login_screen.dart';
import '../../../data/models/study.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  void goToTab(int index) {
    setState(() => currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkAuth();
    });
  }

  void _openAIChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AIChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!auth.isLoggedIn) return const LoginScreen();

        final pages = <Widget>[
          _HomeTab(homeState: this),
          const PracticeScreen(),
          const CourseScreen(),
          const ExamScreen(),
          const _StudyTab(),
        ];

        return GlassScaffold(
          body: IndexedStack(index: currentIndex, children: pages),
          floatingActionButton: FloatingActionButton.small(
            onPressed: _openAIChat,
            backgroundColor: AppTheme.primary,
            elevation: 0,
            child: const Text("AI",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ),
          bottomNavigationBar: GlassPanel(
            padding: const EdgeInsets.only(top: 4),
            child: SafeArea(
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                currentIndex: currentIndex,
                onTap: (i) => goToTab(i),
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.home_rounded), label: '首页'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.quiz_outlined), label: '刷题'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.video_library_outlined), label: '课程'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.assignment_outlined), label: '模考'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.menu_book_outlined), label: '学习'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
//  Home Tab
// ═══════════════════════════════════════════
class _HomeTab extends StatefulWidget {
  final HomeScreenState homeState;
  const _HomeTab({required this.homeState});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudyProvider>().loadStudyPlans();
      context.read<StudyProvider>().loadTodayTask();
      context.read<StudyProvider>().loadTodayStats();
    });
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认退出'),
        content: const Text('退出后需要重新登录'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final study = context.watch<StudyProvider>();
    final examCategory = context.watch<QuestionProvider>().examCategory;
    final task = study.todayTask;
    final plan = study.todayTaskPlan;
    final stats = study.todayStats;
    final questionProvider = context.watch<QuestionProvider>();

    return RefreshIndicator(
      onRefresh: () async {
        await study.loadStudyPlans();
        await study.loadTodayTask();
        await study.loadTodayStats();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(user, stats, examCategory, task, plan),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('快捷学习',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 14),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                      '今日数据',
                      () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const StatsScreen()))),
                  const SizedBox(height: 14),
                  _buildStatsRow(stats),
                  const SizedBox(height: 24),
                  _buildLearningCommandCard(task, plan, stats),
                  if (questionProvider.recentStudyTitle != null) ...[
                    const SizedBox(height: 14),
                    _buildContinueCard(questionProvider),
                  ],
                  if (task != null) ...[
                    const SizedBox(height: 24),
                    const Text('今日任务',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 14),
                    _buildTaskCard(task, plan),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      user, stats, String examCategory, DailyTask? task, StudyPlan? plan) {
    final targetQuestions = task?.targetQuestions ?? plan?.dailyQuestions ?? 40;
    final estimatedMinutes = (targetQuestions * 0.7).round();
    final hasPlan = plan != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        tint: Colors.white.withOpacity(0.70),
        borderColor: Colors.white.withOpacity(0.86),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$examCategory备考',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user?.fullName ?? user?.username ?? "医生"} · 距考试 42 天',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.accentLight.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.logout_rounded,
                        color: AppTheme.primary, size: 22),
                    onPressed: _confirmLogout,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ExamCategorySelector(selected: examCategory),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.accentLight.withOpacity(0.22),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fiber_manual_record,
                      size: 8, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    _focusText(examCategory),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasPlan
                  ? '今日完成 $targetQuestions 题，预计 $estimatedMinutes 分钟'
                  : '先创建学习计划，再生成今日任务',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasPlan
                  ? '来自「${plan.title}」，AI 会结合错题调整今日复习优先级。'
                  : '创建计划后，首页会自动生成每天的刷题目标和学习入口。',
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => widget.homeState.goToTab(hasPlan ? 1 : 4),
                    child: Text(hasPlan ? '开始今日任务' : '创建学习计划'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const StudyScreen())),
                  child: const Text('查看计划'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        GestureDetector(
          onTap: onTap,
          child: const Row(
            children: [
              Text('查看详情',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500)),
              SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 16, color: AppTheme.primary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _QuickActionCard(
          icon: Icons.quiz_rounded,
          title: '章节刷题',
          subtitle: '按章节刷题',
          color: AppTheme.primary,
          onTap: () => widget.homeState.goToTab(1),
        ),
        _QuickActionCard(
          icon: Icons.assignment_rounded,
          title: '模考',
          subtitle: '仿真考场',
          color: AppTheme.accent,
          onTap: () => widget.homeState.goToTab(3),
        ),
        _QuickActionCard(
          icon: Icons.live_tv_rounded,
          title: '直播课',
          subtitle: '名师带学',
          color: AppTheme.error,
          onTap: () => widget.homeState.goToTab(2),
        ),
        _QuickActionCard(
          icon: Icons.video_library_rounded,
          title: '录播课',
          subtitle: '系统精讲',
          color: AppTheme.success,
          onTap: () => widget.homeState.goToTab(2),
        ),
      ],
    );
  }

  Widget _buildStatsRow(dynamic stats) {
    final minutes = ((stats?.timeSpent ?? 0) / 60).round();
    final items = [
      _StatChip(
          icon: Icons.check_circle_rounded,
          label: '正确率',
          value: '${((stats?.accuracyRate ?? 0) * 100).toInt()}%',
          color: AppTheme.success),
      _StatChip(
          icon: Icons.quiz_rounded,
          label: '做题数',
          value: '${stats?.totalQuestions ?? 0}',
          color: AppTheme.primary),
      _StatChip(
          icon: Icons.timer_rounded,
          label: '时长',
          value: '${minutes}min',
          color: AppTheme.accent),
      _StatChip(
          icon: Icons.local_fire_department_rounded,
          label: '连续',
          value: '${stats?.aiQuestions ?? 0}d',
          color: Colors.orange),
    ];
    return Row(
        children: items
            .map((e) => Expanded(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: e)))
            .toList());
  }

  Widget _buildLearningCommandCard(
      DailyTask? task, StudyPlan? plan, dynamic stats) {
    final target = task?.targetQuestions ?? plan?.dailyQuestions ?? 20;
    final completed = task?.completedQuestions ?? stats?.totalQuestions ?? 0;
    final accuracy = ((stats?.accuracyRate ?? 0) * 100).round();
    final progress = target == 0 ? 0.0 : (completed / target).clamp(0.0, 1.0);
    final recommendation = completed == 0
        ? '先完成一组随机练习，快速进入状态'
        : accuracy < 70
            ? '正确率偏低，建议先复习错题'
            : completed < target
                ? '继续今日任务，补齐目标题量'
                : '今日刷题达标，可以看一节课程巩固';
    return GlassCard(
      padding: const EdgeInsets.all(18),
      tint: AppTheme.primary.withOpacity(0.08),
      borderColor: AppTheme.primary.withOpacity(0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日学习任务',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(recommendation,
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTheme.divider,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text('$completed/$target 题 · 今日正确率 $accuracy%',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => widget.homeState.goToTab(1),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('一键开始今日任务'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueCard(QuestionProvider provider) {
    return GlassCard(
      onTap: () => widget.homeState.goToTab(1),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.history_rounded, color: AppTheme.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('继续学习',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                Text(
                  provider.recentStudyAction ?? provider.recentStudyTitle!,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
        ],
      ),
    );
  }

  Widget _buildTaskCard(DailyTask task, StudyPlan? plan) {
    final percent = task.completedQuestions / task.targetQuestions;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      tint: AppTheme.primary.withOpacity(0.09),
      borderColor: AppTheme.primary.withOpacity(0.12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              task.isCompleted
                  ? Icons.celebration_rounded
                  : Icons.menu_book_rounded,
              color: AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.isCompleted ? '今日任务已完成 🎉' : '今日任务进行中',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppTheme.textPrimary),
                ),
                if (plan != null) ...[
                  const SizedBox(height: 4),
                  Text('关联计划：${plan.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppTheme.divider,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${task.completedQuestions}/${task.targetQuestions} 题',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _focusText(String category) {
    switch (category) {
      case '执业资格':
        return '今日重点：基础医学 + 高频考点';
      case '初级职称':
        return '今日重点：专业基础 + 常见题型';
      case '中级职称':
        return '今日重点：专业实践 + 病例分析';
      case '高级职称':
        return '今日重点：专科前沿 + 病例综合';
      default:
        return '今日重点：高频考点 + 错题复盘';
    }
  }
}

class _ExamCategorySelector extends StatelessWidget {
  final String selected;
  const _ExamCategorySelector({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConstants.examCategories.map((category) {
        final isSelected = category == selected;
        return ChoiceChip(
          label: Text(category),
          selected: isSelected,
          showCheckmark: false,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          selectedColor: AppTheme.primary,
          backgroundColor: Colors.white.withOpacity(0.72),
          side: BorderSide(
            color: isSelected
                ? AppTheme.primary
                : AppTheme.primary.withOpacity(0.12),
          ),
          onSelected: (_) {
            final provider = context.read<QuestionProvider>();
            provider.setExamCategory(category);
          },
        );
      }).toList(),
    );
  }
}

// ── Reusable Widgets ──
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(subtitle,
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      radius: 14,
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _StudyTab extends StatelessWidget {
  const _StudyTab();

  @override
  Widget build(BuildContext context) {
    return const StudyScreen();
  }
}
