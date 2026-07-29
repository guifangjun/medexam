import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/ai_chat_provider.dart';
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
import '../syllabus/syllabus_screen.dart';
import '../auth/login_screen.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/study.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;
  int? _syncedUserId;
  String? _syncedExamCategory;

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

  void _syncUserExamCategory(AuthProvider auth) {
    final user = auth.user;
    if (user == null) return;
    final category = AppConstants.normalizeExamCategory(user.targetExam);
    if (_syncedUserId == user.id && _syncedExamCategory == category) return;
    final isDifferentUser = _syncedUserId != null && _syncedUserId != user.id;
    _syncedUserId = user.id;
    _syncedExamCategory = category;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isDifferentUser) {
        context.read<QuestionProvider>().clearUserSession();
        context.read<StudyProvider>().clearUserSession();
        context.read<AIChatProvider>().clearUserSession();
      }
      context.read<QuestionProvider>().setExamCategory(category);
      final study = context.read<StudyProvider>();
      study.loadStudyPlans(examCategory: category);
      study.loadTodayTask(examCategory: category);
      study.loadTodayStats(examCategory: category);
      study.loadPrescription(examCategory: category);
      study.loadWrongReviewCalendar(examCategory: category);
      study.loadWrongReviewPlan(examCategory: category);
      context
          .read<AIChatProvider>()
          .clearStudyAdvice(exceptExamCategory: category);
      context
          .read<AIChatProvider>()
          .clearLearningPath(exceptExamCategory: category);
    });
  }

  Future<void> _switchExamCategory(String category) async {
    final provider = context.read<QuestionProvider>();
    if (provider.examCategory == category) return;
    provider.setExamCategory(category);
    final study = context.read<StudyProvider>();
    study.loadStudyPlans(examCategory: category);
    study.loadTodayTask(examCategory: category);
    study.loadTodayStats(examCategory: category);
    study.loadPrescription(examCategory: category);
    study.loadWrongReviewCalendar(examCategory: category);
    study.loadWrongReviewPlan(examCategory: category);
    context
        .read<AIChatProvider>()
        .clearStudyAdvice(exceptExamCategory: category);
    context
        .read<AIChatProvider>()
        .clearLearningPath(exceptExamCategory: category);

    final auth = context.read<AuthProvider>();
    final saved = await auth.updateTargetExam(category);
    if (!mounted || saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(auth.error ?? '考试分类已切换，但保存到账号失败'),
        backgroundColor: AppTheme.error,
      ),
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
        _syncUserExamCategory(auth);

        final pages = <Widget>[
          _HomeTab(homeState: this),
          const PracticeScreen(),
          const CourseScreen(),
          const ExamScreen(),
          const _StudyTab(),
        ];

        final questionProvider = context.watch<QuestionProvider>();
        final isPracticeInProgress =
            currentIndex == 1 && questionProvider.hasPracticeQuestions;
        final isExamInProgress =
            currentIndex == 3 && questionProvider.hasExamQuestions;
        final isAnsweringInProgress = isPracticeInProgress || isExamInProgress;
        final showAiFab = currentIndex != 1 && currentIndex != 3;

        return GlassScaffold(
          body: IndexedStack(index: currentIndex, children: pages),
          floatingActionButton: showAiFab
              ? FloatingActionButton.small(
                  onPressed: _openAIChat,
                  backgroundColor: AppTheme.primary,
                  elevation: 0,
                  child: const Text("AI",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                )
              : null,
          bottomNavigationBar: isAnsweringInProgress
              ? null
              : GlassPanel(
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
                            icon: Icon(Icons.video_library_outlined),
                            label: '课程'),
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
  bool _isStartingPractice = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final examCategory = context.read<QuestionProvider>().examCategory;
      context.read<StudyProvider>().loadStudyPlans(examCategory: examCategory);
      context.read<StudyProvider>().loadTodayTask(examCategory: examCategory);
      context.read<StudyProvider>().loadTodayStats(examCategory: examCategory);
      context
          .read<StudyProvider>()
          .loadPrescription(examCategory: examCategory);
      context
          .read<StudyProvider>()
          .loadWrongReviewCalendar(examCategory: examCategory);
      context
          .read<StudyProvider>()
          .loadWrongReviewPlan(examCategory: examCategory);
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
              widget.homeState._syncedUserId = null;
              widget.homeState._syncedExamCategory = null;
              widget.homeState.currentIndex = 0;
              context.read<QuestionProvider>().clearUserSession();
              context.read<StudyProvider>().clearUserSession();
              context.read<AIChatProvider>().clearUserSession();
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
    final prescription = study.prescription;
    final questionProvider = context.watch<QuestionProvider>();

    return RefreshIndicator(
      onRefresh: () async {
        await study.loadStudyPlans(examCategory: examCategory);
        await study.loadTodayTask(examCategory: examCategory);
        await study.loadTodayStats(examCategory: examCategory);
        await study.loadPrescription(examCategory: examCategory);
        await study.loadWrongReviewCalendar(examCategory: examCategory);
        await study.loadWrongReviewPlan(examCategory: examCategory);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(user, stats, examCategory, task, plan, prescription),
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
                  _buildLearningCommandCard(task, plan, stats, prescription),
                  const SizedBox(height: 14),
                  _buildAiCoachCard(stats, prescription, examCategory),
                  if (questionProvider.recentStudyTitle != null) ...[
                    const SizedBox(height: 14),
                    _buildContinueCard(questionProvider),
                  ],
                  const SizedBox(height: 24),
                  _buildWeakAreaMap(prescription),
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

  Widget _buildHeader(user, stats, String examCategory, DailyTask? task,
      StudyPlan? plan, StudyPrescription? prescription) {
    final targetQuestions = task?.targetQuestions ?? plan?.dailyQuestions ?? 40;
    final completedQuestions =
        stats?.totalQuestions ?? task?.completedQuestions ?? 0;
    final progressLabel =
        targetQuestions > 0 && completedQuestions > targetQuestions
            ? '目标 $targetQuestions 题，已完成 $completedQuestions 题'
            : '$completedQuestions/$targetQuestions 题';
    final estimatedMinutes = (targetQuestions * 0.7).round();
    final hasTodayTask = task != null;
    final planTitle = plan?.title ?? '当前考试分类';
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
            _ExamCategorySelector(
              selected: examCategory,
              onChanged: widget.homeState._switchExamCategory,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SyllabusScreen()),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.map_rounded, size: 16),
                  label: const Text(
                    '考试大纲',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hasTodayTask
                  ? '今日已完成 $progressLabel，预计 $estimatedMinutes 分钟'
                  : '先创建学习计划，再生成今日任务',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasTodayTask
                  ? '来自「$planTitle」，AI 会结合错题调整今日复习优先级。'
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
                    onPressed: () => hasTodayTask
                        ? _startPrescription(prescription)
                        : widget.homeState.goToTab(4),
                    child: Text(hasTodayTask ? '开始今日任务' : '创建学习计划'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => widget.homeState.goToTab(4),
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
    final actions = [
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
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 900 ? 4 : 2;
        final aspectRatio = width >= 900
            ? 2.3
            : width >= 620
                ? 2.0
                : 1.55;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: aspectRatio,
          children: actions,
        );
      },
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
          icon: Icons.smart_toy_rounded,
          label: 'AI',
          value: '${stats?.aiQuestions ?? 0}次',
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

  Widget _buildLearningCommandCard(DailyTask? task, StudyPlan? plan,
      dynamic stats, StudyPrescription? prescription) {
    final target = prescription?.targetQuestions ??
        task?.targetQuestions ??
        plan?.dailyQuestions ??
        20;
    final completed = stats?.totalQuestions ??
        prescription?.completedQuestions ??
        task?.completedQuestions ??
        0;
    final accuracy =
        ((prescription?.accuracyRate ?? stats?.accuracyRate ?? 0) * 100)
            .round();
    final progress = target == 0 ? 0.0 : (completed / target).clamp(0.0, 1.0);
    final title = prescription?.recommendationTitle ?? '开始今日学习';
    final recommendation = prescription?.recommendationReason ??
        (completed == 0
            ? '先完成一组随机练习，快速进入状态'
            : accuracy < 70
                ? '正确率偏低，建议先复习错题'
                : completed < target
                    ? '继续今日任务，补齐目标题量'
                    : '今日刷题达标，可以看一节课程巩固');
    return GlassCard(
      padding: const EdgeInsets.all(18),
      tint: AppTheme.primary.withOpacity(0.08),
      borderColor: AppTheme.primary.withOpacity(0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
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
          Text(
              target > 0 && completed > target
                  ? '目标 $target 题，已完成 $completed 题 · 今日正确率 $accuracy%'
                  : '$completed/$target 题 · 今日正确率 $accuracy%',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _startPrescription(prescription),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('一键开始今日任务'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startPrescription(StudyPrescription? prescription) async {
    await _loadAndOpenPractice(
      chapterId: prescription?.recommendedChapterId,
      mode: prescription?.recommendedMode ?? 'random',
      tag: prescription?.recommendedTag,
      title: prescription?.recommendationTitle ?? '今日任务',
      emptyMessage: '今日任务暂无可练题目，可以切换到随机练习保持手感',
    );
  }

  Widget _buildAiCoachCard(
    dynamic stats,
    StudyPrescription? prescription,
    String examCategory,
  ) {
    return Consumer<AIChatProvider>(
      builder: (context, ai, _) {
        final advice =
            ai.studyAdviceExamCategory == examCategory ? ai.studyAdvice : null;
        final path = ai.learningPathExamCategory == examCategory
            ? ai.learningPath
            : null;
        return GlassCard(
          padding: const EdgeInsets.all(16),
          tint: AppTheme.accent.withOpacity(0.08),
          borderColor: AppTheme.accent.withOpacity(0.16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: AppTheme.accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'AI 学习教练',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (advice?.isDemo == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '演示建议',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                advice?.content ??
                    '根据今日做题、正确率和薄弱章节生成一条可执行的备考建议。建议在做完一组题后再生成，会更准。',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              if (advice != null && advice.actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: advice.actions
                      .map(
                        (action) => Chip(
                          label: Text(action),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.white.withOpacity(0.72),
                          side: BorderSide(
                              color: AppTheme.accent.withOpacity(0.18)),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),
              _buildAiChallengeCard(stats, prescription),
              if (path != null) ...[
                const SizedBox(height: 14),
                _buildAiLearningPathPreview(path),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: ai.isLoadingStudyAdvice
                          ? null
                          : () => _generateAiStudyAdvice(
                                ai,
                                stats,
                                prescription,
                                examCategory,
                              ),
                      icon: ai.isLoadingStudyAdvice
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.psychology_alt_rounded),
                      label: Text(
                        ai.isLoadingStudyAdvice ? '生成中...' : 'AI 建议',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: ai.isLoadingLearningPath
                          ? null
                          : () => _generateAiLearningPath(
                                ai,
                                stats,
                                prescription,
                                examCategory,
                              ),
                      icon: ai.isLoadingLearningPath
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.route_rounded),
                      label: Text(
                        ai.isLoadingLearningPath ? '生成中...' : '7天路径',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAiChallengeCard(dynamic stats, StudyPrescription? prescription) {
    final completed = prescription?.completedQuestions ??
        (stats is StudyStats ? stats.totalQuestions : 0);
    final target = prescription?.targetQuestions ?? 20;
    final remaining = (target - completed).clamp(0, target);
    final mode = prescription?.recommendedMode ?? 'random';
    final challenge = _aiChallengeCopy(mode, remaining, prescription);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.10),
            AppTheme.accent.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withOpacity(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.78),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(challenge.icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  challenge.subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.4,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => _startPrescription(prescription),
            child: const Text('挑战'),
          ),
        ],
      ),
    );
  }

  _AiChallengeCopy _aiChallengeCopy(
    String mode,
    int remaining,
    StudyPrescription? prescription,
  ) {
    final safeRemaining = remaining <= 0 ? 5 : remaining;
    switch (mode) {
      case 'wrong':
        return _AiChallengeCopy(
          icon: Icons.replay_circle_filled_rounded,
          title: '错题反杀挑战',
          subtitle: '先拿下 ${safeRemaining.clamp(5, 20)} 道错题，AI 会根据薄弱点继续调整复盘节奏。',
        );
      case 'chapter':
        final chapter = prescription?.weakAreas.isNotEmpty == true
            ? prescription!.weakAreas.first.chapterName
            : '薄弱章节';
        return _AiChallengeCopy(
          icon: Icons.track_changes_rounded,
          title: '薄弱章节突围',
          subtitle: '集中攻克「$chapter」，完成一组专项题后再生成 AI 建议会更准。',
        );
      case 'unanswered':
        return _AiChallengeCopy(
          icon: Icons.playlist_add_check_circle_rounded,
          title: '未做题开荒',
          subtitle: '今天还差 $safeRemaining 题达标，优先清掉未做题，建立新的知识覆盖面。',
        );
      default:
        return _AiChallengeCopy(
          icon: Icons.casino_rounded,
          title: '随机热身 10 题',
          subtitle: '用一组随机题快速进入备考状态，做完后 AI 会帮你定位下一步。',
        );
    }
  }

  Widget _buildAiLearningPathPreview(AILearningPath path) {
    final previewSteps = path.steps.take(3).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppTheme.accent, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${path.title} · 约 ${path.estimatedMinutes} 分钟',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (path.isDemo)
                const Text(
                  '演示',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            path.summary,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.45,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: previewSteps.isEmpty || _isStartingPractice
                ? null
                : () => _startAiPathStep(previewSteps.first),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: AppTheme.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _isStartingPractice
                        ? const Text(
                            '正在打开今日挑战...',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          )
                        : Text(
                            path.todayChallenge,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                  ),
                  if (_isStartingPractice)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.play_arrow_rounded,
                        color: AppTheme.accent, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (previewSteps.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: previewSteps
                  .map(
                    (step) => ActionChip(
                      avatar: const Icon(Icons.play_circle_outline_rounded,
                          size: 16),
                      label: Text('${step.day} · ${step.title}'),
                      onPressed: _isStartingPractice
                          ? null
                          : () => _startAiPathStep(step),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white.withOpacity(0.72),
                      side: BorderSide(
                        color: AppTheme.accent.withOpacity(0.18),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 10),
          if (path.microTasks.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: Colors.orange, size: 17),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '完成后解锁：${path.rewardTitle}',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: path.microTasks
                  .map(
                    (task) => Chip(
                      label: Text(task),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppTheme.primary.withOpacity(0.08),
                      side:
                          BorderSide(color: AppTheme.primary.withOpacity(0.12)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 4),
          ],
          ...previewSteps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      step.day,
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${step.title}：${step.focus}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAiStudyAdvice(
    AIChatProvider ai,
    dynamic stats,
    StudyPrescription? prescription,
    String examCategory,
  ) async {
    final weakAreas =
        (prescription?.weakAreas ?? []).map((area) => area.toJson()).toList();
    final todayStats = stats is StudyStats
        ? stats.toJson()
        : {
            'total_questions': prescription?.completedQuestions ?? 0,
            'accuracy_rate': prescription?.accuracyRate ?? 0.0,
            'time_spent': prescription?.timeSpent ?? 0,
          };
    final result = await ai.buildStudyAdvice(
      examCategory: examCategory,
      todayStats: todayStats,
      weakAreas: weakAreas,
      wrongSummary: {
        'pending_wrong_count':
            context.read<StudyProvider>().wrongReviewCalendar?.totalWrong ?? 0,
        'recommended_mode': prescription?.recommendedMode ?? 'random',
        'recommendation_title': prescription?.recommendationTitle ?? '',
      },
    );
    if (!mounted || result != null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI 建议生成失败，请稍后再试')),
    );
  }

  Future<void> _generateAiLearningPath(
    AIChatProvider ai,
    dynamic stats,
    StudyPrescription? prescription,
    String examCategory,
  ) async {
    final todayStats = stats is StudyStats
        ? stats.toJson()
        : {
            'total_questions': prescription?.completedQuestions ?? 0,
            'accuracy_rate': prescription?.accuracyRate ?? 0.0,
            'time_spent': prescription?.timeSpent ?? 0,
          };
    final result = await ai.buildLearningPath(
      examCategory: examCategory,
      todayStats: todayStats,
      prescription: prescription?.toJson() ?? {},
      wrongReview:
          context.read<StudyProvider>().wrongReviewPlan?.toJson() ?? {},
    );
    if (!mounted || result != null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI 学习路径生成失败，请稍后再试')),
    );
  }

  Future<void> _startAiPathStep(AILearningPathStep step) async {
    await _loadAndOpenPractice(
      chapterId: step.chapterId,
      mode: step.mode,
      tag: step.tag,
      title: '${step.day} · ${step.title}',
      emptyMessage: _emptyPracticeMessageForMode(step.mode),
    );
  }

  Widget _buildWeakAreaMap(StudyPrescription? prescription) {
    final weakAreas = prescription?.weakAreas ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('薄弱项地图',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 14),
        if (weakAreas.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(16),
            tint: Colors.white.withOpacity(0.72),
            child: const Row(
              children: [
                Icon(Icons.insights_rounded, color: AppTheme.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '暂无薄弱项，先完成一组练习，系统会自动生成章节表现。',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: weakAreas
                .map((area) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _WeakAreaCard(
                        area: area,
                        onTap: () => _startWeakArea(area),
                      ),
                    ))
                .toList(),
          ),
      ],
    );
  }

  Future<void> _startWeakArea(WeakArea area) async {
    await _loadAndOpenPractice(
      chapterId: area.chapterId,
      mode: 'chapter',
      title: '补强${area.chapterName}',
      emptyMessage: '「${area.chapterName}」暂无可练题目，请先在后台补充题库',
    );
  }

  Future<void> _loadAndOpenPractice({
    int? chapterId,
    required String mode,
    String? tag,
    required String title,
    required String emptyMessage,
  }) async {
    if (_isStartingPractice) return;
    setState(() => _isStartingPractice = true);
    final questionProvider = context.read<QuestionProvider>();
    try {
      await questionProvider.loadPracticeQuestions(
        chapterId: chapterId,
        mode: mode,
        tag: tag,
        title: title,
      );
      if (!mounted) return;
      if (questionProvider.currentQuestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(emptyMessage)),
        );
        return;
      }
      widget.homeState.goToTab(1);
    } finally {
      if (mounted) {
        setState(() => _isStartingPractice = false);
      }
    }
  }

  String _emptyPracticeMessageForMode(String mode) {
    return switch (mode) {
      'wrong' => '暂无可复习错题，先做一组随机练习积累新错题',
      'unanswered' => '暂无未做题，可以切换章节练习或随机练习',
      'tag' => '暂无高频考点题目，可以先做随机练习',
      'chapter' => '该章节暂无可练题目，请先在后台补充题库',
      _ => '暂无可练题目，请稍后再试',
    };
  }

  Widget _buildContinueCard(QuestionProvider provider) {
    return GlassCard(
      onTap: () => _continueRecentStudy(provider),
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

  Future<void> _continueRecentStudy(QuestionProvider provider) async {
    final title = provider.recentStudyTitle;
    if (title == null || _isStartingPractice) return;

    setState(() => _isStartingPractice = true);
    try {
      await provider.loadPracticeQuestions(
        chapterId: provider.recentChapterId,
        mode: provider.recentStudyMode ?? 'chapter',
        tag: provider.recentStudyTag,
        limit: provider.recentStudyLimit,
        title: title,
      );
      if (!mounted) return;

      if (provider.currentQuestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无可继续的题目，可以选择其他练习模式')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PracticeScreen()),
      );
    } finally {
      if (mounted) {
        setState(() => _isStartingPractice = false);
      }
    }
  }

  Widget _buildTaskCard(DailyTask task, StudyPlan? plan) {
    final percent = task.targetQuestions > 0
        ? task.completedQuestions / task.targetQuestions
        : 0.0;
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
                  task.completionStatusLabel,
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
                Text(task.progressLabel,
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
  final ValueChanged<String> onChanged;

  const _ExamCategorySelector({
    required this.selected,
    required this.onChanged,
  });

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
            onChanged(category);
          },
        );
      }).toList(),
    );
  }
}

// ── Reusable Widgets ──
class _WeakAreaCard extends StatelessWidget {
  final WeakArea area;
  final VoidCallback onTap;

  const _WeakAreaCard({required this.area, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final percent = (area.accuracyRate * 100).round();
    final color = area.status == '薄弱'
        ? AppTheme.error
        : area.status == '一般'
            ? AppTheme.accent
            : area.status == '待开始'
                ? AppTheme.primary
                : AppTheme.success;
    final subtitle = area.practiceCount == 0
        ? '还没练过，建议先做一组摸底'
        : '已练 ${area.practiceCount} 题 · 错 ${area.wrongCount} 题 · 正确率 $percent%';
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      tint: color.withOpacity(0.07),
      borderColor: color.withOpacity(0.12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.radar_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  area.chapterName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              area.status,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

class _AiChallengeCopy {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AiChallengeCopy({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _StudyTab extends StatelessWidget {
  const _StudyTab();

  @override
  Widget build(BuildContext context) {
    return const StudyScreen();
  }
}
