import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/study.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<StudyProvider>();
      p.loadStudyPlans();
      p.loadTodayTask();
      p.loadTodayStats();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            await provider.loadTodayTask();
            await provider.loadTodayStats();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: task == null
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: CircularProgressIndicator()))
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
                            SizedBox(
                              width: 140,
                              height: 140,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: task.progress,
                                    strokeWidth: 10,
                                    backgroundColor:
                                        Colors.white.withOpacity(0.2),
                                    valueColor: const AlwaysStoppedAnimation(
                                        Colors.white),
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        '${(task.progress * 100).toInt()}%',
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        '${task.completedQuestions}/${task.targetQuestions}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              task.isCompleted ? '今日任务已完成 🎉' : '继续加油！',
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
}

class _TodayStatsRow extends StatelessWidget {
  final StudyStats? stats;

  const _TodayStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
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
        value: '${stats?.timeSpent ?? 0}min',
        color: AppTheme.accent,
      ),
      _TodayStatCard(
        icon: Icons.local_fire_department_rounded,
        label: '连续',
        value: '${stats?.aiQuestions ?? 0}d',
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
              task.isCompleted
                  ? '今日任务已完成'
                  : '今日任务 ${task.completedQuestions}/${task.targetQuestions} 题',
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

  @override
  Widget build(BuildContext context) {
    return Consumer<StudyProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return Stack(
          children: [
            provider.plans.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 96),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_note_outlined,
                              size: 64, color: AppTheme.textHint),
                          const SizedBox(height: 16),
                          const Text('暂无学习计划',
                              style: TextStyle(
                                  fontSize: 16, color: AppTheme.textSecondary)),
                          const SizedBox(height: 8),
                          const Text('创建计划后，按当前考试目标推进复习',
                              style: TextStyle(color: AppTheme.textHint)),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
                    itemCount: provider.plans.length,
                    itemBuilder: (context, index) {
                      final plan = provider.plans[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
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
                                    child: const Icon(Icons.menu_book_rounded,
                                        color: AppTheme.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(plan.title ?? '学习计划',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        Text(
                                          '${plan.dailyQuestions ?? 20} 题/天',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: plan.isActive
                                          ? AppTheme.success.withOpacity(0.1)
                                          : AppTheme.accent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      plan.isActive ? '已完成' : '进行中',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: plan.isActive
                                            ? AppTheme.success
                                            : AppTheme.accent,
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
                                  onPressed: () => _startPlanStudy(context),
                                  icon: const Icon(Icons.play_arrow_rounded,
                                      size: 20),
                                  label: const Text('开始学习'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 88,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _showCreatePlanDialog(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('创建学习计划'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _startPlanStudy(BuildContext context) {
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
                      final success = await provider.createStudyPlan(
                        title: title,
                        startDate: DateTime.now(),
                        endDate: DateTime.now().add(const Duration(days: 30)),
                        dailyQuestions: dailyQ,
                      );

                      if (!context.mounted) return;
                      if (success) {
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

// ── 错题本 ──
class WrongQuestionTab extends StatefulWidget {
  @override
  State<WrongQuestionTab> createState() => _WrongQuestionTabState();
}

class _WrongQuestionTabState extends State<WrongQuestionTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudyProvider>().loadWrongQuestions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudyProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.wrongQuestions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 72, color: AppTheme.success.withOpacity(0.5)),
                const SizedBox(height: 20),
                const Text('暂无错题',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                const Text('继续保持！',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          );
        }

        final mastered =
            provider.wrongQuestions.where((w) => w.isMastered).length;
        final total = provider.wrongQuestions.length;

        return CustomScrollView(
          slivers: [
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
                        label: '错题总数', value: '$total', color: AppTheme.error),
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final w = provider.wrongQuestions[index];
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                      if (w.wrongReason != null) ...[
                                        _MiniTag(w.wrongReason!),
                                        const SizedBox(width: 8),
                                      ],
                                      Icon(Icons.refresh_rounded,
                                          size: 14, color: AppTheme.textHint),
                                      const SizedBox(width: 2),
                                      Text('${w.reviewCount} 次',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary)),
                                    ],
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
                  childCount: provider.wrongQuestions.length,
                ),
              ),
            ),
          ],
        );
      },
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
    bool? isCorrect;
    var isSubmitting = false;

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
