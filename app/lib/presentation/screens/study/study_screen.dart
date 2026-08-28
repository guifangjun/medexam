import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/study.dart';
import '../../../data/models/conversation.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/ai_chat_provider.dart';
import '../../../data/providers/study_provider.dart';
import '../../../data/providers/question_provider.dart';
import '../../../core/app_messenger.dart';
import '../../../core/theme/app_theme.dart';
import '../practice/practice_screen.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _loadedExamCategory;
  bool _loadScheduled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadForCurrentCategory();
    });
  }

  Future<void> _reloadForCurrentCategory() async {
    if (!mounted) return;
    final p = context.read<StudyProvider>();
    final examCategory = context.read<QuestionProvider>().examCategory;
    _loadedExamCategory = examCategory;
    await p.loadStudyPlans(examCategory: examCategory);
    await p.loadTodayTask(examCategory: examCategory);
    await p.loadTodayStats(examCategory: examCategory);
    await p.loadPrescription(examCategory: examCategory);
    await p.loadWrongQuestions(examCategory: examCategory);
  }

  void _scheduleReloadIfCategoryChanged(String examCategory) {
    if (_loadedExamCategory == examCategory || _loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadScheduled = false;
      await _reloadForCurrentCategory();
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
    _scheduleReloadIfCategoryChanged(examCategory);
    return Scaffold(
      appBar: AppBar(
        title: const Text('学习中心'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
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
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: '今日'),
                Tab(text: '计划'),
                Tab(text: '错题本'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _TodayTab(),
          const _PlanTab(),
          WrongQuestionTab(),
        ],
      ),
    );
  }
}

// ── 今日 ──
class _TodayTab extends StatelessWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<StudyProvider>(
      builder: (context, provider, _) {
        final task = provider.todayTask;
        final stats = provider.todayStats;
        return RefreshIndicator(
          onRefresh: () async {
            final examCategory = context.read<QuestionProvider>().examCategory;
            await provider.loadTodayTask(examCategory: examCategory);
            await provider.loadTodayStats(examCategory: examCategory);
            await provider.loadPrescription(examCategory: examCategory);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: task == null
                ? provider.isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _TodayEmptyState(
                        message: provider.error ?? '今日任务暂未生成',
                        onRetry: () async {
                          final examCategory =
                              context.read<QuestionProvider>().examCategory;
                          await provider.loadTodayTask(
                              examCategory: examCategory);
                          await provider.loadTodayStats(
                              examCategory: examCategory);
                        },
                        onCreatePlan: () =>
                            const _PlanTab().showCreatePlanDialog(context),
                        onStartPractice: () => _startTodayWarmup(context),
                      )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryLight],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(task.date,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14)),
                            const SizedBox(height: 20),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 118,
                                  height: 118,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 92,
                                        height: 92,
                                        child: CircularProgressIndicator(
                                          value: task.displayProgress,
                                          strokeWidth: 8,
                                          backgroundColor:
                                              Colors.white.withOpacity(0.2),
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                                  Colors.white),
                                        ),
                                      ),
                                      Text(
                                        '${task.displayPercent}%',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  task.progressLabel,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.82),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              task.completionStatusLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('今日数据',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 14),
                      _TodayStatsRow(stats: stats),
                      const SizedBox(height: 24),
                      _TodayAiCoachCard(
                        stats: stats,
                        prescription: provider.prescription,
                      ),
                      const SizedBox(height: 24),
                      const Text('今日任务',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 14),
                      _TodayTaskSummary(task: task),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Future<void> _startTodayWarmup(BuildContext context) async {
    final questionProvider = context.read<QuestionProvider>();
    await questionProvider.loadPracticeQuestions(
      mode: 'random',
      title: '今日热身练习',
      limit: 10,
    );
    if (!context.mounted) return;
    if (questionProvider.currentQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(questionProvider.error ?? '暂无可练习题目')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PracticeScreen()),
    );
  }
}

class _TodayAiCoachCard extends StatefulWidget {
  final StudyStats? stats;
  final StudyPrescription? prescription;

  const _TodayAiCoachCard({
    required this.stats,
    required this.prescription,
  });

  @override
  State<_TodayAiCoachCard> createState() => _TodayAiCoachCardState();
}

class _TodayAiCoachCardState extends State<_TodayAiCoachCard> {
  bool _isStarting = false;

  @override
  Widget build(BuildContext context) {
    final examCategory = context.watch<QuestionProvider>().examCategory;
    final ai = context.watch<AIChatProvider>();
    final advice =
        ai.studyAdviceExamCategory == examCategory ? ai.studyAdvice : null;
    final path =
        ai.learningPathExamCategory == examCategory ? ai.learningPath : null;
    final prescription = widget.prescription;
    final title = prescription?.recommendationTitle ?? 'AI 今日学习建议';
    final reason = prescription?.recommendationReason ??
        '先完成一组练习，系统会结合今日数据、错题和薄弱章节生成下一步建议。';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI 今日教练',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (advice?.isDemo == true || path?.isDemo == true)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '演示',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            advice?.content ?? reason,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
          if (path != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${path.title} · 约 ${path.estimatedMinutes} 分钟',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    path.todayChallenge,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  if (path.steps.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: path.steps
                          .take(3)
                          .map(
                            (step) => ActionChip(
                              avatar: const Icon(
                                Icons.play_circle_outline_rounded,
                                size: 16,
                              ),
                              label: Text('${step.day} · ${step.title}'),
                              onPressed:
                                  _isStarting ? null : () => _startStep(step),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.white.withOpacity(0.8),
                              side: BorderSide(
                                  color: AppTheme.accent.withOpacity(0.16)),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isStarting
                      ? null
                      : () => _startPrescription(widget.prescription),
                  icon: _isStarting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(_isStarting ? '打开中...' : '开始推荐练习'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: ai.isLoadingStudyAdvice
                    ? null
                    : () => _generateAdvice(ai, examCategory),
                icon: ai.isLoadingStudyAdvice
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology_alt_rounded),
                label: const Text('AI建议'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: ai.isLoadingLearningPath
                  ? null
                  : () => _generateLearningPath(ai, examCategory),
              icon: ai.isLoadingLearningPath
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.route_rounded),
              label: Text(ai.isLoadingLearningPath ? '生成路径中...' : '生成 7 天学习路径'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAdvice(AIChatProvider ai, String examCategory) async {
    final prescription = widget.prescription;
    final result = await ai.buildStudyAdvice(
      examCategory: examCategory,
      todayStats: widget.stats?.toJson() ??
          {
            'total_questions': prescription?.completedQuestions ?? 0,
            'accuracy_rate': prescription?.accuracyRate ?? 0.0,
            'time_spent': prescription?.timeSpent ?? 0,
          },
      weakAreas:
          (prescription?.weakAreas ?? []).map((area) => area.toJson()).toList(),
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

  Future<void> _generateLearningPath(
    AIChatProvider ai,
    String examCategory,
  ) async {
    final prescription = widget.prescription;
    final result = await ai.buildLearningPath(
      examCategory: examCategory,
      todayStats: widget.stats?.toJson() ??
          {
            'total_questions': prescription?.completedQuestions ?? 0,
            'accuracy_rate': prescription?.accuracyRate ?? 0.0,
            'time_spent': prescription?.timeSpent ?? 0,
          },
      prescription: prescription?.toJson() ?? {},
      wrongReview:
          context.read<StudyProvider>().wrongReviewPlan?.toJson() ?? {},
    );
    if (!mounted || result != null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI 学习路径生成失败，请稍后再试')),
    );
  }

  Future<void> _startStep(AILearningPathStep step) async {
    await _loadAndOpenPractice(
      chapterId: step.chapterId,
      mode: step.mode,
      tag: step.tag,
      title: '${step.day} · ${step.title}',
      emptyMessage: _emptyPracticeMessageForMode(step.mode),
    );
  }

  Future<void> _startPrescription(StudyPrescription? prescription) async {
    await _loadAndOpenPractice(
      chapterId: prescription?.recommendedChapterId,
      mode: prescription?.recommendedMode ?? 'random',
      tag: prescription?.recommendedTag,
      title: prescription?.recommendationTitle ?? '今日推荐练习',
      emptyMessage: '今日推荐暂无可练题目，可以切换到随机练习保持手感',
    );
  }

  Future<void> _loadAndOpenPractice({
    int? chapterId,
    required String mode,
    String? tag,
    required String title,
    required String emptyMessage,
  }) async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      final questionProvider = context.read<QuestionProvider>();
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PracticeScreen()),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
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
}

class _TodayEmptyState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback onCreatePlan;
  final VoidCallback onStartPractice;

  const _TodayEmptyState({
    required this.message,
    required this.onRetry,
    required this.onCreatePlan,
    required this.onStartPractice,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 54),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 68,
              color: AppTheme.textHint.withOpacity(0.72),
            ),
            const SizedBox(height: 16),
            const Text(
              '今日学习数据暂不可用',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: onStartPractice,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('先做练习'),
                ),
                OutlinedButton.icon(
                  onPressed: onCreatePlan,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('创建计划'),
                ),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayStatsRow extends StatelessWidget {
  final StudyStats? stats;

  const _TodayStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final minutes = ((stats?.timeSpent ?? 0) / 60).round();
    final items = [
      _TodayStatCard(
        icon: Icons.check_circle_rounded,
        label: '正确率',
        value: '${((stats?.accuracyRate ?? 0) * 100).toInt()}%',
        color: AppTheme.success,
      ),
      _TodayStatCard(
        icon: Icons.quiz_rounded,
        label: '做题数',
        value: '${stats?.totalQuestions ?? 0}',
        color: AppTheme.primary,
      ),
      _TodayStatCard(
        icon: Icons.timer_rounded,
        label: '时长',
        value: '${minutes}min',
        color: AppTheme.accent,
      ),
      _TodayStatCard(
        icon: Icons.smart_toy_rounded,
        label: 'AI',
        value: '${stats?.aiQuestions ?? 0}次',
        color: Colors.orange,
      ),
    ];
    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: item,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TodayStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _TodayStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TodayTaskSummary extends StatelessWidget {
  final DailyTask task;

  const _TodayTaskSummary({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(
            task.isCompleted
                ? Icons.celebration_rounded
                : Icons.menu_book_rounded,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              task.isCompleted ? '今日任务已完成' : '今日任务 ${task.progressLabel}',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 计划 ──
class _PlanTab extends StatelessWidget {
  const _PlanTab();

  void showCreatePlanDialog(BuildContext context) {
    _showCreatePlanDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudyProvider>(
      builder: (context, provider, _) {
        final ai = context.watch<AIChatProvider>();
        final examCategory = context.watch<QuestionProvider>().examCategory;
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final sprintPlan =
            ai.sprintPlanExamCategory == examCategory ? ai.sprintPlan : null;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
          children: [
            _buildSprintPlannerCard(
              context,
              ai: ai,
              examCategory: examCategory,
              plan: sprintPlan,
            ),
            const SizedBox(height: 16),
            if (provider.plans.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_note_outlined,
                      size: 48,
                      color: AppTheme.textHint,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '暂无已应用的学习计划',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '让 AI 先根据考期和薄弱点规划，或手动创建计划。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _showCreatePlanDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('手动创建计划'),
                    ),
                  ],
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _showCreatePlanDialog(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('创建新的学习计划'),
                ),
              ),
              const SizedBox(height: 12),
              ...provider.plans.map(
                (plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPlanCard(context, plan),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSprintPlannerCard(
    BuildContext context, {
    required AIChatProvider ai,
    required String examCategory,
    required AISprintPlan? plan,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B5FEF), Color(0xFF8A64F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B5FEF).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 冲刺规划师',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '考期 × 薄弱点 × 每日时间，生成可执行计划',
                      style: TextStyle(
                        color: Color(0xFFE8E7FF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            plan == null
                ? '读取你在「$examCategory」的正确率和章节覆盖，自动拆分基础、强化、冲刺阶段。'
                : '已生成 ${plan.daysRemaining} 天计划 · 每天 ${plan.dailyMinutes} 分钟 · ${plan.dailyQuestions} 题',
            style: const TextStyle(
              color: Colors.white,
              height: 1.45,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: ai.isLoadingSprintPlan
                  ? null
                  : () {
                      if (plan != null) {
                        _showSprintPlanPreview(context, plan);
                      } else {
                        _openSprintPlanner(context);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF5B5FEF),
              ),
              icon: ai.isLoadingSprintPlan
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      plan == null
                          ? Icons.auto_fix_high_rounded
                          : Icons.visibility_outlined,
                      size: 19,
                    ),
              label: Text(plan == null ? '生成我的冲刺计划' : '查看 AI 冲刺方案'),
            ),
          ),
          if (plan != null) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => _openSprintPlanner(context),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('重新设置考期与学习强度'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openSprintPlanner(BuildContext context) async {
    final now = DateTime.now();
    final savedDate = context.read<AuthProvider>().user?.targetDate;
    var examDate = savedDate != null && savedDate.isAfter(now)
        ? savedDate
        : now.add(const Duration(days: 42));
    var dailyMinutes = 60;
    var intensity = 'steady';
    var isGenerating = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.divider,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '生成 AI 冲刺计划',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI 会读取当前科目的做题记录和章节覆盖，计划生成后可一键应用。',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '考试日期',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: isGenerating
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: sheetContext,
                              initialDate: examDate,
                              firstDate: now.add(const Duration(days: 1)),
                              lastDate: now.add(const Duration(days: 730)),
                              helpText: '选择目标考试日期',
                            );
                            if (picked != null) {
                              setSheetState(() => examDate = picked);
                            }
                          },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_available_rounded,
                            color: Color(0xFF5B5FEF),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _formatDate(examDate),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '每日可学习时间',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '$dailyMinutes 分钟',
                        style: const TextStyle(
                          color: Color(0xFF5B5FEF),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: dailyMinutes.toDouble(),
                    min: 20,
                    max: 180,
                    divisions: 16,
                    label: '$dailyMinutes 分钟',
                    onChanged: isGenerating
                        ? null
                        : (value) => setSheetState(
                              () => dailyMinutes = value.round(),
                            ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '学习强度',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _intensityChip(
                        label: '稳步',
                        value: 'steady',
                        selected: intensity,
                        enabled: !isGenerating,
                        onSelected: (value) =>
                            setSheetState(() => intensity = value),
                      ),
                      _intensityChip(
                        label: '加速',
                        value: 'accelerated',
                        selected: intensity,
                        enabled: !isGenerating,
                        onSelected: (value) =>
                            setSheetState(() => intensity = value),
                      ),
                      _intensityChip(
                        label: '冲刺',
                        value: 'sprint',
                        selected: intensity,
                        enabled: !isGenerating,
                        onSelected: (value) =>
                            setSheetState(() => intensity = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isGenerating
                          ? null
                          : () async {
                              setSheetState(() => isGenerating = true);
                              final ai = context.read<AIChatProvider>();
                              final plan = await ai.buildSprintPlan(
                                examCategory: context
                                    .read<QuestionProvider>()
                                    .examCategory,
                                examDate: examDate,
                                dailyMinutes: dailyMinutes,
                                intensity: intensity,
                              );
                              if (!context.mounted) return;
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              if (plan == null) {
                                rootScaffoldMessengerKey.currentState
                                    ?.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ai.error ?? 'AI 冲刺计划生成失败，请稍后重试',
                                    ),
                                  ),
                                );
                                return;
                              }
                              _showSprintPlanPreview(context, plan);
                            },
                      icon: isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(isGenerating ? 'AI 正在规划...' : '生成个性化计划'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _intensityChip({
    required String label,
    required String value,
    required String selected,
    required bool enabled,
    required ValueChanged<String> onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: enabled ? (_) => onSelected(value) : null,
      selectedColor: const Color(0xFF5B5FEF).withOpacity(0.14),
      labelStyle: TextStyle(
        color: selected == value
            ? const Color(0xFF5B5FEF)
            : AppTheme.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Future<void> _showSprintPlanPreview(
    BuildContext context,
    AISprintPlan plan,
  ) async {
    var isApplying = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.6,
          maxChildSize: 0.96,
          expand: false,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          plan.title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B5FEF).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFF5B5FEF).withOpacity(0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.summary,
                              style: const TextStyle(
                                height: 1.55,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _planMetric('${plan.daysRemaining} 天', '考期'),
                                _planMetric('${plan.dailyMinutes} 分', '每天'),
                                _planMetric('${plan.dailyQuestions} 题', '题量'),
                                _planMetric(
                                  '${plan.weeklyMockExams} 次',
                                  '周模考',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SprintSectionTitle('优先提分章节'),
                      const SizedBox(height: 10),
                      if (plan.priorityChapters.isEmpty)
                        const Text(
                          '暂无章节数据，先完成一组练习后再校准。',
                          style: TextStyle(color: AppTheme.textSecondary),
                        )
                      else
                        ...plan.priorityChapters.take(4).map(
                              (item) => _SprintPriorityTile(item: item),
                            ),
                      const SizedBox(height: 16),
                      const _SprintSectionTitle('分阶段路线'),
                      const SizedBox(height: 10),
                      ...plan.phases.asMap().entries.map(
                            (entry) => _SprintPhaseCard(
                              index: entry.key + 1,
                              phase: entry.value,
                            ),
                          ),
                      const SizedBox(height: 16),
                      const _SprintSectionTitle('每天怎么学'),
                      const SizedBox(height: 10),
                      ...plan.dailySchedule.map(
                        (item) => _SprintBullet(
                          icon: Icons.schedule_rounded,
                          text: item,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _SprintSectionTitle('今天先做这三步'),
                      const SizedBox(height: 10),
                      ...plan.todayActions.asMap().entries.map(
                            (entry) => _SprintBullet(
                              leading: '${entry.key + 1}',
                              text: entry.value,
                              color: const Color(0xFF5B5FEF),
                            ),
                          ),
                      if (plan.riskAlerts.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const _SprintSectionTitle('AI 风险提醒'),
                        const SizedBox(height: 10),
                        ...plan.riskAlerts.map(
                          (item) => _SprintBullet(
                            icon: Icons.info_outline_rounded,
                            text: item,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppTheme.divider)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: isApplying
                            ? null
                            : () async {
                                setSheetState(() => isApplying = true);
                                final applied =
                                    await _applySprintPlan(context, plan);
                                if (!context.mounted) return;
                                if (applied && sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                } else if (sheetContext.mounted) {
                                  setSheetState(() => isApplying = false);
                                }
                              },
                        icon: isApplying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.rocket_launch_rounded),
                        label: Text(isApplying ? '正在应用计划...' : '一键应用为学习计划'),
                      ),
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

  Widget _planMetric(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$value · $label',
        style: const TextStyle(
          color: Color(0xFF5B5FEF),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<bool> _applySprintPlan(
    BuildContext context,
    AISprintPlan plan,
  ) async {
    final auth = context.read<AuthProvider>();
    final goalSaved = await auth.updateLearningGoal(
      targetDate: plan.examDate,
      dailyGoal: plan.dailyQuestions,
    );
    if (!context.mounted) return false;
    if (!goalSaved) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(auth.error ?? '考试日期保存失败')),
      );
      return false;
    }
    final study = context.read<StudyProvider>();
    final success = await study.createStudyPlan(
      title: 'AI ${plan.daysRemaining} 天冲刺计划',
      startDate: DateTime.now(),
      endDate: plan.examDate,
      targetChapters:
          plan.priorityChapters.map((item) => item.chapterId).toList(),
      dailyQuestions: plan.dailyQuestions,
      examCategory: plan.examCategory,
    );
    if (!success) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(study.error ?? '学习计划应用失败')),
      );
      return false;
    }
    await study.loadPrescription(examCategory: plan.examCategory);
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('AI 冲刺计划已应用，今日任务已同步更新'),
        backgroundColor: AppTheme.success,
      ),
    );
    return true;
  }

  String _formatDate(DateTime date) =>
      '${date.year} 年 ${date.month} 月 ${date.day} 日';

  Widget _buildPlanCard(BuildContext context, StudyPlan plan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${plan.dailyQuestions} 题/天',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: plan.isActive
                      ? AppTheme.accent.withOpacity(0.1)
                      : AppTheme.textHint.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  plan.isActive ? '进行中' : '历史计划',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: plan.isActive ? AppTheme.accent : AppTheme.textHint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _startPlanStudy(context, plan),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('开始学习'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startPlanStudy(BuildContext context, StudyPlan plan) async {
    final questionProvider = context.read<QuestionProvider>();
    final chapterId =
        plan.targetChapters.isNotEmpty ? plan.targetChapters.first : null;
    await questionProvider.loadPracticeQuestions(
      chapterId: chapterId,
      mode: 'unanswered',
      title:
          chapterId == null ? '${plan.title} · 今日未做题' : '${plan.title} · 目标章节',
      limit: plan.dailyQuestions.clamp(1, 100).toInt(),
    );
    if (!context.mounted) return;
    if (questionProvider.currentQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            questionProvider.error ??
                (chapterId == null ? '当前计划暂无未做题' : '该计划目标章节暂无可练题目'),
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PracticeScreen()),
    );
  }

  void _showCreatePlanDialog(BuildContext context) {
    final examCategory = context.read<QuestionProvider>().examCategory;
    final titleCtl = TextEditingController();
    var dailyQ = 30;
    var isSubmitting = false;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('创建学习计划', style: TextStyle(fontWeight: FontWeight.w700)),
        content: StatefulBuilder(
          builder: (ctx, setInnerState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_rounded,
                        color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '当前目标：$examCategory',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtl,
                enabled: !isSubmitting,
                decoration: InputDecoration(
                    labelText: '计划名称', hintText: '例如: $examCategory 30 天冲刺'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('每日目标: ',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  Expanded(
                    child: Slider(
                      value: dailyQ.toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 9,
                      label: '$dailyQ',
                      activeColor: AppTheme.primary,
                      onChanged: isSubmitting
                          ? null
                          : (v) => setInnerState(() => dailyQ = v.toInt()),
                    ),
                  ),
                  Text('$dailyQ',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('取消')),
          StatefulBuilder(
            builder: (ctx, setActionState) => ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final title = titleCtl.text.trim();
                      if (title.isEmpty) {
                        rootScaffoldMessengerKey.currentState?.showSnackBar(
                          const SnackBar(content: Text('请输入计划名称')),
                        );
                        return;
                      }

                      setActionState(() => isSubmitting = true);
                      final provider = context.read<StudyProvider>();
                      final questionProvider = context.read<QuestionProvider>();
                      if (questionProvider.chapters.isEmpty) {
                        await questionProvider.loadChapters();
                      }
                      final targetChapters = questionProvider.chapters
                          .map((chapter) => chapter.id)
                          .toList();
                      final success = await provider.createStudyPlan(
                        title: title,
                        startDate: DateTime.now(),
                        endDate: DateTime.now().add(const Duration(days: 30)),
                        targetChapters: targetChapters,
                        dailyQuestions: dailyQ,
                        examCategory: examCategory,
                      );

                      if (!context.mounted) return;
                      if (success) {
                        await provider.loadPrescription(
                          examCategory:
                              context.read<QuestionProvider>().examCategory,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(ctx);
                        rootScaffoldMessengerKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text('学习计划已创建'),
                            backgroundColor: AppTheme.success,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else {
                        setActionState(() => isSubmitting = false);
                        rootScaffoldMessengerKey.currentState?.showSnackBar(
                          SnackBar(
                            content: Text(provider.error ?? '创建学习计划失败'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('创建'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SprintSectionTitle extends StatelessWidget {
  final String title;

  const _SprintSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SprintPriorityTile extends StatelessWidget {
  final AISprintPriorityChapter item;

  const _SprintPriorityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final accuracy = item.accuracyRate == null
        ? '未覆盖'
        : '${(item.accuracyRate! * 100).round()}%';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF5B5FEF).withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              accuracy,
              style: const TextStyle(
                color: Color(0xFF5B5FEF),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.chapterName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.reason,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SprintPhaseCard extends StatelessWidget {
  final int index;
  final AISprintPhase phase;

  const _SprintPhaseCard({required this.index, required this.phase});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF5B5FEF),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  phase.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '第 ${phase.startDay}-${phase.endDay} 天',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            phase.focus,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: phase.dailyActions
                .map(
                  (item) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B5FEF).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Color(0xFF5B5FEF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 9),
          Text(
            '阶段验收：${phase.milestone}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SprintBullet extends StatelessWidget {
  final IconData? icon;
  final String? leading;
  final String text;
  final Color color;

  const _SprintBullet({
    this.icon,
    this.leading,
    required this.text,
    this.color = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: leading != null
                ? Text(
                    leading!,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  )
                : Icon(icon ?? Icons.check_rounded, color: color, size: 15),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 错题本 ──
class WrongQuestionTab extends StatefulWidget {
  @override
  State<WrongQuestionTab> createState() => _WrongQuestionTabState();
}

class _WrongQuestionTabState extends State<WrongQuestionTab> {
  String _wrongStatusFilter = 'all';
  String? _wrongChapterFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final examCategory = context.read<QuestionProvider>().examCategory;
      context
          .read<StudyProvider>()
          .loadWrongQuestions(examCategory: examCategory);
      context
          .read<StudyProvider>()
          .loadWrongReviewCalendar(examCategory: examCategory);
      context
          .read<StudyProvider>()
          .loadWrongReviewPlan(examCategory: examCategory);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudyProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final ai = context.watch<AIChatProvider>();
        final questionProvider = context.watch<QuestionProvider>();
        final examCategory = questionProvider.examCategory;
        final errorReport = ai.errorPatternExamCategory == examCategory
            ? ai.errorPatternReport
            : null;
        final mastered =
            provider.wrongQuestions.where((w) => w.isMastered).length;
        final total = provider.wrongQuestionTotalCount;
        final loaded = provider.wrongQuestions.length;
        final chapters = questionProvider.chapters;
        final filteredWrongs = provider.wrongQuestions.where((w) {
          if (_wrongStatusFilter == 'pending' && w.isMastered) return false;
          if (_wrongStatusFilter == 'mastered' && !w.isMastered) return false;
          if (_wrongChapterFilter != null &&
              !w.questionTags.contains(_wrongChapterFilter)) {
            return false;
          }
          return true;
        }).toList();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _WrongReviewPlanCard(
                plan: provider.wrongReviewPlan,
                onStart: () => _startWrongPractice(context),
              ),
            ),
            SliverToBoxAdapter(
              child: _AIErrorPatternCard(
                report: errorReport,
                isLoading: ai.isLoadingErrorPatterns,
                onGenerate: () => _generateErrorPatterns(context),
                onStartPattern: (pattern) =>
                    _startErrorPatternTraining(context, pattern),
              ),
            ),
            SliverToBoxAdapter(
              child: _WrongReviewCalendarCard(
                calendar: provider.wrongReviewCalendar,
              ),
            ),
            if (provider.wrongQuestions.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyWrongBookState(
                  onStartPractice: () => _startFallbackPractice(context),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.error.withOpacity(0.08),
                        AppTheme.primary.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatChip(
                          label: '错题总数',
                          value: '$total',
                          color: AppTheme.error),
                      _StatChip(
                          label: '已掌握',
                          value: '$mastered',
                          color: AppTheme.success),
                      _StatChip(
                          label: '待复习',
                          value: '${total - mastered}',
                          color: AppTheme.accent),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _WrongFilterBar(
                  statusFilter: _wrongStatusFilter,
                  chapterFilter: _wrongChapterFilter,
                  chapters: chapters.map((chapter) => chapter.name).toList(),
                  onStatusChanged: (value) {
                    setState(() => _wrongStatusFilter = value);
                  },
                  onChapterChanged: (value) {
                    setState(() => _wrongChapterFilter = value);
                  },
                ),
              ),
              if (filteredWrongs.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: _InlineEmptyBox(
                      icon: Icons.filter_alt_off_rounded,
                      title: '当前筛选下暂无错题',
                      subtitle: '可以切换筛选条件，或先完成一组练习积累错题。',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final w = filteredWrongs[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _showReviewSheet(context, w),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.divider),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: w.isMastered
                                        ? AppTheme.success.withOpacity(0.1)
                                        : AppTheme.error.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    w.isMastered
                                        ? Icons.check_circle_rounded
                                        : Icons.close_rounded,
                                    color: w.isMastered
                                        ? AppTheme.success
                                        : AppTheme.error,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          w.questionContent?.isNotEmpty == true
                                              ? w.questionContent!
                                              : '错题 #${w.questionId}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          _MiniTag(w.chapterName),
                                          const SizedBox(width: 8),
                                          if (w.wrongReason != null) ...[
                                            _MiniTag(w.wrongReason!),
                                            const SizedBox(width: 8),
                                          ],
                                          Icon(Icons.refresh_rounded,
                                              size: 14,
                                              color: AppTheme.textHint),
                                          const SizedBox(width: 2),
                                          Text('${w.reviewCount} 次',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppTheme.textSecondary)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${w.masteryLabel} · ${w.nextReviewLabel}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: w.isMastered
                                              ? AppTheme.success
                                              : AppTheme.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (w.isMastered)
                                  const Icon(Icons.check_circle_rounded,
                                      color: AppTheme.success, size: 22)
                                else
                                  const Icon(Icons.chevron_right,
                                      color: AppTheme.textHint, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: filteredWrongs.length,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: _WrongLoadMoreFooter(
                  loaded: loaded,
                  total: total,
                  hasMore: provider.hasMoreWrongQuestions,
                  isLoading: provider.isLoadingMoreWrongQuestions,
                  onLoadMore: () => provider.loadMoreWrongQuestions(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _generateErrorPatterns(BuildContext context) async {
    final examCategory = context.read<QuestionProvider>().examCategory;
    final ai = context.read<AIChatProvider>();
    final report = await ai.buildErrorPatternReport(
      examCategory: examCategory,
      periodDays: 60,
    );
    if (!context.mounted) return;
    if (report == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ai.error ?? 'AI 错因诊断生成失败，请稍后重试')),
      );
      return;
    }
    if (report.patterns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前错题样本不足，完成一组练习后再诊断')),
      );
    }
  }

  Future<void> _startErrorPatternTraining(
    BuildContext context,
    AIErrorPattern pattern,
  ) async {
    final questionProvider = context.read<QuestionProvider>();
    final hasExactQuestions = pattern.questionIds.isNotEmpty;
    await questionProvider.loadPracticeQuestions(
      questionIds: hasExactQuestions ? pattern.questionIds : null,
      chapterId: hasExactQuestions ? null : pattern.chapterId,
      mode: hasExactQuestions ? 'wrong' : pattern.mode,
      tag: hasExactQuestions ? null : pattern.tag,
      title: 'AI 纠偏 · ${pattern.name}',
      limit: 10,
    );
    if (!context.mounted) return;
    if (questionProvider.currentQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(questionProvider.error ?? '暂无可用纠偏题目')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PracticeScreen()),
    );
  }

  Future<void> _startWrongPractice(BuildContext context) async {
    final questionProvider = context.read<QuestionProvider>();
    final examCategory = questionProvider.examCategory;
    questionProvider.setExamCategory(examCategory);
    await questionProvider.loadPracticeQuestions(
      mode: 'wrong',
      title: '今日错题智能复盘',
    );
    if (!context.mounted) return;
    if (questionProvider.currentQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(questionProvider.error ?? '暂无可复习错题')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PracticeScreen()),
    );
  }

  Future<void> _startFallbackPractice(BuildContext context) async {
    final questionProvider = context.read<QuestionProvider>();
    questionProvider.setExamCategory(questionProvider.examCategory);
    await questionProvider.loadPracticeQuestions(
      mode: 'random',
      title: '积累第一批错题',
      limit: 10,
    );
    if (!context.mounted) return;
    if (questionProvider.currentQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(questionProvider.error ?? '暂无可练习题目')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PracticeScreen()),
    );
  }

  void _showReviewSheet(BuildContext context, WrongQuestion wrong) {
    if (wrong.questionContent == null || wrong.questionOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('题目内容缺失，无法复习')),
      );
      return;
    }

    String? selectedAnswer;
    String? selectedReason = wrong.wrongReason;
    bool? isCorrect;
    var isSubmitting = false;
    var isExplaining = false;
    AITextResult? aiExplain;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final resultColor = isCorrect == true
                ? AppTheme.success
                : isCorrect == false
                    ? AppTheme.error
                    : AppTheme.primary;
            return DraggableScrollableSheet(
              initialChildSize: 0.78,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              expand: false,
              builder: (context, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.divider,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _MiniTag('错题复习'),
                        const SizedBox(width: 8),
                        _MiniTag('复习 ${wrong.reviewCount} 次'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      wrong.questionContent!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.55,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (wrong.questionTags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        wrong.questionTags.join(' · '),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _WrongReasonSelector(
                      selectedReason: selectedReason,
                      onSelected: (reason) async {
                        setSheetState(() => selectedReason = reason);
                        final ok = await context
                            .read<StudyProvider>()
                            .updateWrongReason(wrong.id, reason);
                        if (!context.mounted) return;
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('错因标注失败')),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    ...wrong.questionOptions.entries.map((entry) {
                      final isSelected = selectedAnswer == entry.key;
                      final isRight = isCorrect != null &&
                          entry.key == wrong.questionAnswer;
                      final isWrong = isCorrect == false && isSelected;
                      final borderColor = isRight
                          ? AppTheme.success
                          : isWrong
                              ? AppTheme.error
                              : isSelected
                                  ? AppTheme.primary
                                  : AppTheme.divider;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: isCorrect == null
                              ? () => setSheetState(
                                  () => selectedAnswer = entry.key)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: borderColor.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: borderColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(entry.value)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (isCorrect != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: resultColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: resultColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCorrect == true
                                  ? '答对了'
                                  : '答错了，正确答案：${wrong.questionAnswer ?? '-'}',
                              style: TextStyle(
                                  color: resultColor,
                                  fontWeight: FontWeight.w800),
                            ),
                            if (wrong.questionExplanation?.isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 8),
                              Text(
                                wrong.questionExplanation!,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: isExplaining
                          ? null
                          : () async {
                              setSheetState(() => isExplaining = true);
                              final result = await context
                                  .read<AIChatProvider>()
                                  .explainWrongQuestion(
                                    questionId: wrong.questionId,
                                    examCategory: context
                                        .read<QuestionProvider>()
                                        .examCategory,
                                    questionContent: wrong.questionContent!,
                                    questionOptions: wrong.questionOptions,
                                    correctAnswer: wrong.questionAnswer,
                                    selectedAnswer: selectedAnswer,
                                    explanation: wrong.questionExplanation,
                                    tags: wrong.questionTags,
                                  );
                              if (!context.mounted) return;
                              setSheetState(() {
                                aiExplain = result;
                                isExplaining = false;
                              });
                              if (result != null) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (!scrollController.hasClients) return;
                                  scrollController.animateTo(
                                    scrollController.position.maxScrollExtent,
                                    duration: const Duration(milliseconds: 320),
                                    curve: Curves.easeOutCubic,
                                  );
                                });
                              }
                            },
                      icon: isExplaining
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(isExplaining ? 'AI 正在讲解...' : 'AI 讲解这道题'),
                    ),
                    if (aiExplain != null) ...[
                      const SizedBox(height: 12),
                      _AIExplainBox(result: aiExplain!),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isCorrect != null
                            ? () => Navigator.pop(sheetContext)
                            : selectedAnswer == null || isSubmitting
                                ? null
                                : () async {
                                    final correct =
                                        selectedAnswer == wrong.questionAnswer;
                                    setSheetState(() {
                                      isSubmitting = true;
                                      isCorrect = correct;
                                    });
                                    final ok = await context
                                        .read<StudyProvider>()
                                        .reviewWrongQuestion(wrong.id, correct);
                                    if (!context.mounted) return;
                                    setSheetState(() => isSubmitting = false);
                                    if (!ok) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(content: Text('复习记录失败')),
                                      );
                                    } else {
                                      final mastered =
                                          correct && wrong.reviewCount + 1 >= 3;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            correct
                                                ? mastered
                                                    ? '本次复习答对，已掌握 1 题；建议明天继续巩固相近知识点'
                                                    : '本次复习答对，正确率 100%；累计复习 ${wrong.reviewCount + 1} 次'
                                                : '本次复习答错，正确率 0%；系统已安排明天再次复习',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                        child: Text(isCorrect == null ? '提交答案' : '完成'),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _WrongLoadMoreFooter extends StatelessWidget {
  final int loaded;
  final int total;
  final bool hasMore;
  final bool isLoading;
  final VoidCallback onLoadMore;

  const _WrongLoadMoreFooter({
    required this.loaded,
    required this.total,
    required this.hasMore,
    required this.isLoading,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 84),
        child: Column(
          children: [
            Text(
              total > 0 ? '已加载 $loaded / 共 $total 道错题' : '已加载 $loaded 道错题',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: !hasMore || isLoading ? null : onLoadMore,
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                    hasMore ? (isLoading ? '正在加载...' : '加载更多错题') : '已加载全部错题'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WrongFilterBar extends StatelessWidget {
  final String statusFilter;
  final String? chapterFilter;
  final List<String> chapters;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String?> onChapterChanged;

  const _WrongFilterBar({
    required this.statusFilter,
    required this.chapterFilter,
    required this.chapters,
    required this.onStatusChanged,
    required this.onChapterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final visibleChapters = chapters.take(8).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '筛选错题',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip('全部', 'all'),
              _filterChip('待复习', 'pending'),
              _filterChip('已掌握', 'mastered'),
            ],
          ),
          if (visibleChapters.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('全部章节'),
                  selected: chapterFilter == null,
                  onSelected: (_) => onChapterChanged(null),
                ),
                ...visibleChapters.map(
                  (chapter) => ChoiceChip(
                    label: Text(chapter),
                    selected: chapterFilter == chapter,
                    onSelected: (_) => onChapterChanged(chapter),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: statusFilter == value,
      onSelected: (_) => onStatusChanged(value),
    );
  }
}

class _InlineEmptyBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InlineEmptyBox({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.textHint, size: 36),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _EmptyWrongBookState extends StatelessWidget {
  final VoidCallback onStartPractice;

  const _EmptyWrongBookState({required this.onStartPractice});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 72,
            color: AppTheme.success.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          const Text(
            '暂无错题',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '完成练习或模考后，答错的题会自动进入错题本；你也可以先做一组随机练习积累复盘素材。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onStartPractice,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('先做一组练习'),
          ),
        ],
      ),
    );
  }
}

class _WrongReasonSelector extends StatelessWidget {
  final String? selectedReason;
  final ValueChanged<String> onSelected;

  const _WrongReasonSelector({
    required this.selectedReason,
    required this.onSelected,
  });

  static const reasons = ['概念不清', '记忆模糊', '理解偏差', '粗心大意'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('标注错因，智能复盘会更准',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: reasons.map((reason) {
              final selected = selectedReason == reason;
              return ChoiceChip(
                label: Text(reason),
                selected: selected,
                onSelected: (_) => onSelected(reason),
                selectedColor: AppTheme.primary.withOpacity(0.14),
                labelStyle: TextStyle(
                  color: selected ? AppTheme.primary : AppTheme.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: selected ? AppTheme.primary : AppTheme.divider,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _AIErrorPatternCard extends StatelessWidget {
  final AIErrorPatternReport? report;
  final bool isLoading;
  final VoidCallback onGenerate;
  final ValueChanged<AIErrorPattern> onStartPattern;

  const _AIErrorPatternCard({
    required this.report,
    required this.isLoading,
    required this.onGenerate,
    required this.onStartPattern,
  });

  @override
  Widget build(BuildContext context) {
    final patterns = report?.patterns ?? const <AIErrorPattern>[];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF5E8),
            const Color(0xFFF0EDFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF7C5CE7).withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C5CE7).withOpacity(0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  color: Color(0xFF7C5CE7),
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 错因雷达',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '跨题识别反复失分的真正原因',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (report != null && report!.totalWrong > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C5CE7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${report!.totalWrong} 题样本',
                    style: const TextStyle(
                      color: Color(0xFF7C5CE7),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          if (report == null) ...[
            const Text(
              'AI 会结合错因标注、答题用时、题目难度和重复复习次数，区分知识漏洞、概念混淆、记忆不牢、审题偏差与时间压力。',
              style: TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
                fontSize: 13,
              ),
            ),
          ] else ...[
            Text(
              report!.summary,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                height: 1.5,
                fontSize: 13,
              ),
            ),
            if (patterns.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...patterns.take(3).map(
                    (pattern) => _ErrorPatternTile(
                      pattern: pattern,
                      onStart: () => onStartPattern(pattern),
                    ),
                  ),
              if (report!.trainingSequence.isNotEmpty) ...[
                const SizedBox(height: 5),
                const Text(
                  'AI 纠偏顺序',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 7),
                ...report!.trainingSequence.map(
                  (step) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: Color(0xFF7C5CE7),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            step,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              height: 1.4,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : onGenerate,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C5CE7),
                side: const BorderSide(color: Color(0xFF7C5CE7)),
                backgroundColor: Colors.white.withOpacity(0.72),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      report == null
                          ? Icons.auto_awesome_rounded
                          : Icons.refresh_rounded,
                      size: 18,
                    ),
              label: Text(
                isLoading
                    ? 'AI 正在分析错题模式...'
                    : report == null
                        ? '生成我的错因诊断'
                        : '重新分析最新错题',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPatternTile extends StatelessWidget {
  final AIErrorPattern pattern;
  final VoidCallback onStart;

  const _ErrorPatternTile({required this.pattern, required this.onStart});

  Color get _color {
    switch (pattern.key) {
      case 'reading_bias':
        return AppTheme.warning;
      case 'memory_decay':
        return const Color(0xFF7C5CE7);
      case 'time_pressure':
        return AppTheme.accent;
      case 'reasoning_chain':
        return const Color(0xFFEF6C8F);
      default:
        return AppTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = (pattern.percentage * 100).round();
    final color = _color;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pattern.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${pattern.count} 题 · $percent%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${pattern.severity}风险',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pattern.percentage.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pattern.diagnosis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (pattern.evidence.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              '依据：${pattern.evidence.take(2).join('；')}',
              style: const TextStyle(
                color: AppTheme.textHint,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  pattern.correction,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 17),
                label: const Text('纠偏'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: color,
                  backgroundColor: color.withOpacity(0.1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WrongReviewPlanCard extends StatelessWidget {
  final WrongReviewPlan? plan;
  final VoidCallback onStart;

  const _WrongReviewPlanCard({required this.plan, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final current = plan;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.10),
            AppTheme.accent.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
      ),
      child: current == null
          ? const Row(
              children: [
                SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text('正在生成智能复盘建议...',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.psychology_alt_rounded,
                          color: AppTheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(current.title,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800)),
                          Text(current.summary,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _ReviewMetric(
                        label: '今日到期',
                        value: '${current.dueToday}',
                        color: AppTheme.primary),
                    const SizedBox(width: 8),
                    _ReviewMetric(
                        label: '已逾期',
                        value: '${current.overdue}',
                        color: AppTheme.error),
                    const SizedBox(width: 8),
                    _ReviewMetric(
                        label: '建议复习',
                        value: '${current.suggestedCount}',
                        color: AppTheme.accent),
                  ],
                ),
                if (current.focusTags.isNotEmpty ||
                    current.focusReasons.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...current.focusTags.map((item) =>
                          _ReviewFocusChip(item: item, color: AppTheme.error)),
                      ...current.focusReasons.map((item) =>
                          _ReviewFocusChip(item: item, color: AppTheme.accent)),
                    ],
                  ),
                ],
                if (current.actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...current.actions.take(3).map(
                        (action) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w900)),
                              Expanded(
                                child: Text(action,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                        height: 1.35)),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: current.suggestedCount == 0 ? null : onStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('开始今日错题复盘'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _WrongReviewCalendarCard extends StatelessWidget {
  final WrongReviewCalendar? calendar;

  const _WrongReviewCalendarCard({required this.calendar});

  @override
  Widget build(BuildContext context) {
    final days = calendar?.upcoming ?? [];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('错题复习日历',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          if (calendar == null)
            const Text('正在加载复习日历...',
                style: TextStyle(color: AppTheme.textSecondary))
          else ...[
            Row(
              children: [
                _ReviewMetric(
                    label: '错题总数',
                    value: '${calendar!.totalWrong}',
                    color: AppTheme.error),
                const SizedBox(width: 8),
                _ReviewMetric(
                    label: '今日待复习',
                    value: '${calendar!.dueToday + calendar!.overdue}',
                    color: AppTheme.primary),
                const SizedBox(width: 8),
                _ReviewMetric(
                    label: '已掌握',
                    value: '${calendar!.mastered}',
                    color: AppTheme.success),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final day = days[index];
                  return _CalendarDayPill(day: day, isToday: index == 0);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ReviewMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ReviewFocusChip extends StatelessWidget {
  final WrongReviewFocusItem item;
  final Color color;

  const _ReviewFocusChip({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('${item.label} ×${item.count}',
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _AIExplainBox extends StatelessWidget {
  final AITextResult result;

  const _AIExplainBox({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.primary, size: 18),
              const SizedBox(width: 6),
              Text(result.title,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800)),
              if (result.isDemo) ...[
                const SizedBox(width: 6),
                const Text('演示',
                    style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(_readableAiContent(result.content),
              style:
                  const TextStyle(color: AppTheme.textSecondary, height: 1.5)),
          if (result.actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: result.actions.map((item) => _MiniTag(item)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _readableAiContent(String raw) {
    return raw
        .split('\n')
        .map((line) {
          final trimmed = line.trimRight();
          if (RegExp(r'^\s*`{3,}').hasMatch(trimmed)) {
            return '';
          }
          if (trimmed.trim().startsWith('|')) {
            return trimmed
                .replaceAll('|', '  ')
                .replaceAll(RegExp(r'\s{2,}'), ' ')
                .trim();
          }
          return trimmed
              .replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '')
              .replaceAll('**', '')
              .replaceFirst(RegExp(r'^\s*[-*]\s+'), '• ')
              .replaceFirst(RegExp(r'^\s*>\s?'), '')
              .trimRight();
        })
        .where((line) =>
            line.trim().isNotEmpty && !RegExp(r'^[-\s]+$').hasMatch(line))
        .join('\n');
  }
}

class _CalendarDayPill extends StatelessWidget {
  final WrongReviewCalendarDay day;
  final bool isToday;

  const _CalendarDayPill({required this.day, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final count = day.dueCount + day.overdueCount;
    final color = day.overdueCount > 0
        ? AppTheme.error
        : count > 0
            ? AppTheme.primary
            : AppTheme.textHint;
    final parts = day.date.split('-');
    final label = parts.length == 3 ? '${parts[1]}/${parts[2]}' : day.date;
    return Container(
      width: 62,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isToday ? AppTheme.primary.withOpacity(0.09) : AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isToday ? AppTheme.primary.withOpacity(0.28) : AppTheme.divider,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(isToday ? '今天' : label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 6),
          Text('$count',
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(day.overdueCount > 0 ? '逾期' : '到期',
              style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11,
              color: AppTheme.primary,
              fontWeight: FontWeight.w500)),
    );
  }
}
