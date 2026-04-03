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
      final provider = context.read<StudyProvider>();
      provider.loadStudyPlans();
      provider.loadTodayTask();
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '今日'),
            Tab(text: '计划'),
            Tab(text: '错题本'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TodayTab(),
          _PlanTab(),
          WrongQuestionTab(),
        ],
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<StudyProvider>(
      builder: (context, provider, _) {
        final task = provider.todayTask;

        return RefreshIndicator(
          onRefresh: () => provider.loadTodayTask(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task == null)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            task.date,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 150,
                                height: 150,
                                child: CircularProgressIndicator(
                                  value: task.progress,
                                  strokeWidth: 12,
                                  backgroundColor: Colors.grey[200],
                                  valueColor:
                                      const AlwaysStoppedAnimation(AppTheme.primaryColor),
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    '${(task.progress * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${task.completedQuestions}/${task.targetQuestions}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            task.isCompleted ? '🎉 今日任务已完成' : '继续加油！',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlanTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<StudyProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.plans.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  '暂无学习计划',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _showCreatePlanDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('创建计划'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.plans.length,
          itemBuilder: (context, index) {
            final plan = provider.plans[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: plan.isActive
                        ? AppTheme.secondaryColor.withOpacity(0.1)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: plan.isActive ? AppTheme.secondaryColor : Colors.grey,
                  ),
                ),
                title: Text(plan.title),
                subtitle: Text(
                  '每天 ${plan.dailyQuestions} 题 | ${plan.startDate.month}/${plan.startDate.day} - ${plan.endDate.month}/${plan.endDate.day}',
                ),
                trailing: plan.isActive
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '进行中',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  void _showCreatePlanDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CreatePlanDialog(),
    );
  }
}

class _CreatePlanDialog extends StatefulWidget {
  const _CreatePlanDialog();

  @override
  State<_CreatePlanDialog> createState() => _CreatePlanDialogState();
}

class _CreatePlanDialogState extends State<_CreatePlanDialog> {
  final _titleController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  int _dailyQuestions = 20;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建学习计划'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '计划名称',
                hintText: '如：执业医师备考计划',
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('开始日期'),
              subtitle: Text('${_startDate.year}-${_startDate.month}-${_startDate.day}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _startDate = date);
              },
            ),
            ListTile(
              title: const Text('结束日期'),
              subtitle: Text('${_endDate.year}-${_endDate.month}-${_endDate.day}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate,
                  firstDate: _startDate,
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _endDate = date);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('每日题目：'),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _dailyQuestions.toDouble(),
                    min: 10,
                    max: 100,
                    divisions: 9,
                    label: '$_dailyQuestions',
                    onChanged: (v) => setState(() => _dailyQuestions = v.toInt()),
                  ),
                ),
                Text('$_dailyQuestions'),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isEmpty) return;
            context.read<StudyProvider>().createStudyPlan(
                  title: _titleController.text,
                  startDate: _startDate,
                  endDate: _endDate,
                  dailyQuestions: _dailyQuestions,
                );
            Navigator.pop(context);
          },
          child: const Text('创建'),
        ),
      ],
    );
  }
}

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
                Icon(Icons.check_circle, size: 64, color: Colors.green[400]),
                const SizedBox(height: 16),
                const Text(
                  '暂无错题',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  '继续保持！',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.wrongQuestions.length,
          itemBuilder: (context, index) {
            final wrong = provider.wrongQuestions[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: wrong.isMastered
                        ? AppTheme.secondaryColor.withOpacity(0.1)
                        : AppTheme.errorColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      wrong.isMastered ? Icons.check : Icons.close,
                      color: wrong.isMastered
                          ? AppTheme.secondaryColor
                          : AppTheme.errorColor,
                    ),
                  ),
                ),
                title: Text('错题 #${wrong.questionId}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (wrong.wrongReason != null)
                      Text('错因：${wrong.wrongReason}'),
                    Text('复习次数：${wrong.reviewCount}'),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: 查看错题详情
                },
              ),
            );
          },
        );
      },
    );
  }
}
