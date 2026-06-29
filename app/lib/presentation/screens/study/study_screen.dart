import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/study_provider.dart';
import '../../../core/theme/app_theme.dart';

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
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
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
        return RefreshIndicator(
          onRefresh: () => provider.loadTodayTask(),
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
                            colors: [
                              AppTheme.primary,
                              AppTheme.primaryLight
                            ],
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
                                    valueColor:
                                        const AlwaysStoppedAnimation(
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
                                          color:
                                              Colors.white.withOpacity(0.8),
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
                    ],
                  ),
          ),
        );
      },
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
        return Scaffold(
          backgroundColor: AppTheme.surface,
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppTheme.primary,
            onPressed: () => _showCreatePlanDialog(context),
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
          body: provider.plans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_note_outlined,
                          size: 64, color: AppTheme.textHint),
                      const SizedBox(height: 16),
                      const Text('暂无学习计划',
                          style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      const Text('点击右下角创建',
                          style: TextStyle(color: AppTheme.textHint)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
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
                          border:
                              Border.all(color: AppTheme.divider),
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
                                    color: AppTheme.primary
                                        .withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                      Icons.menu_book_rounded,
                                      color: AppTheme.primary,
                                      size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(plan.title ?? '学习计划',
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w600)),
                                      Text(
                                        '${plan.dailyQuestions ?? 20} 题/天',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color:
                                                AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: plan.isActive
                                        ? AppTheme.success
                                            .withOpacity(0.1)
                                        : AppTheme.accent
                                            .withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(8),
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
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showCreatePlanDialog(BuildContext context) {
    final titleCtl = TextEditingController();
    var dailyQ = 30;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('创建学习计划',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: StatefulBuilder(
          builder: (ctx, setInnerState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtl,
                decoration: const InputDecoration(
                    labelText: '计划名称',
                    hintText: '例如: 内科专项复习'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('每日目标: ',
                      style: TextStyle(
                          color: AppTheme.textSecondary)),
                  Expanded(
                    child: Slider(
                      value: dailyQ.toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 9,
                      label: '$dailyQ',
                      activeColor: AppTheme.primary,
                      onChanged: (v) =>
                          setInnerState(() => dailyQ = v.toInt()),
                    ),
                  ),
                  Text('$dailyQ',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (titleCtl.text.isEmpty) return;
              context.read<StudyProvider>().createStudyPlan(
                    title: titleCtl.text,
                    startDate: DateTime.now(),
                    endDate: DateTime.now().add(const Duration(days: 30)),
                    dailyQuestions: dailyQ,
                  );
              Navigator.pop(ctx);
            },
            child: const Text('创建'),
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final w = provider.wrongQuestions[index];
                    return Container(
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
                                Text('错题 #${w.questionId}',
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
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
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
