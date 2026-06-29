import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/study_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../practice/practice_screen.dart';
import '../exam/exam_screen.dart';
import '../ai_chat/ai_chat_screen.dart';
import '../study/study_screen.dart';
import '../wrong/wrong_screen.dart';
import '../stats/stats_screen.dart';
import '../auth/login_screen.dart';
import '../../../data/models/study.dart';
import '../ai_chat/ai_chat_screen.dart';

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
          const ExamScreen(),
          const _StudyTab(),
        ];

        return Scaffold(
          body: IndexedStack(index: currentIndex, children: pages),
          floatingActionButton: FloatingActionButton.small(
            onPressed: _openAIChat,
            backgroundColor: AppTheme.primary,
            child: const Text("AI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 16,
                    offset: Offset(0, -4)),
              ],
            ),
            child: SafeArea(
              child: BottomNavigationBar(
                currentIndex: currentIndex,
                onTap: (i) => goToTab(i),
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.home_rounded), label: '首页'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.quiz_outlined), label: '练习'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.assignment_outlined), label: '考试'),
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
    final task = study.todayTask;
    final stats = study.todayStats;

    return RefreshIndicator(
      onRefresh: () async {
        await study.loadTodayTask();
        await study.loadTodayStats();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(user, stats),
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
                  _buildSectionHeader('今日数据', () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const StatsScreen()))),
                  const SizedBox(height: 14),
                  _buildStatsRow(stats),
                  if (task != null) ...[
                    const SizedBox(height: 24),
                    const Text('今日任务',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 14),
                    _buildTaskCard(task),
                  ],
                  const SizedBox(height: 24),
                  const Text('推荐学习',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 14),
                  _buildRecommendSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(user, stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primary, AppTheme.primaryLight]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '你好，${user?.fullName ?? user?.username ?? "同学"}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  Text('继续今天的医考学习吧',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8))),
                ],
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: const Icon(Icons.logout_rounded,
                      color: Colors.white, size: 22),
                  onPressed: _confirmLogout,
                ),
              ),
            ],
          ),
        ],
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
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.quiz_rounded,
            title: '章节练习',
            subtitle: '按章节刷题',
            color: AppTheme.primary,
            onTap: () => widget.homeState.goToTab(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.assignment_rounded,
            title: '模拟考试',
            subtitle: '仿真考场',
            color: AppTheme.accent,
            onTap: () => widget.homeState.goToTab(2),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(dynamic stats) {
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
          value: '${stats?.timeSpent ?? 0}min',
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

  Widget _buildTaskCard(DailyTask task) {
    final percent = task.completedQuestions / task.targetQuestions;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
      ),
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
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: AppTheme.divider,
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.primary),
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

  Widget _buildRecommendSection() {
    return Column(
      children: [
        _RecommendItem(
            icon: Icons.replay_rounded,
            title: '错题复习',
            desc:
                '${context.watch<StudyProvider>().wrongQuestions.length} 道待复习',
            color: AppTheme.error,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const WrongScreen()))),
        _RecommendItem(
            icon: Icons.bar_chart_rounded,
            title: '学习统计',
            desc: '查看学习成果',
            color: AppTheme.accent,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StatsScreen()))),
        _RecommendItem(
            icon: Icons.calendar_month_rounded,
            title: '学习计划',
            desc: '制定个性化计划',
            color: AppTheme.primaryLight,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StudyScreen()))),
      ].map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: e,
          )).toList(),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppTheme.divider),
        ),
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
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _RecommendItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final VoidCallback onTap;

  const _RecommendItem({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.textHint, size: 20),
          ],
        ),
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
