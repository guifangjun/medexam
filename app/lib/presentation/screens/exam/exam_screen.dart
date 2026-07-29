import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/question.dart';
import '../../../data/models/conversation.dart';
import '../../../data/providers/ai_chat_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/question_provider.dart';
import '../../../data/providers/study_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../practice/practice_screen.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  int _selectedCount = 50;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<QuestionProvider>();
      provider.loadExamAttempts();
      provider.loadExamAvailability();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('模考')),
      body: Consumer<QuestionProvider>(
        builder: (context, provider, _) {
          if (provider.hasExamQuestions) {
            return _ExamSessionScreen(questionCount: _selectedCount);
          }
          return _buildSetupView();
        },
      ),
    );
  }

  Widget _buildSetupView() {
    final provider = context.watch<QuestionProvider>();
    final examCategory = provider.examCategory;
    final availableCount = provider.examAvailableCount;
    final countOptions = _buildCountOptions(availableCount);
    final canStart = availableCount == null || availableCount > 0;
    if (availableCount != null &&
        countOptions.isNotEmpty &&
        !countOptions.contains(_selectedCount)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedCount = countOptions.last);
      });
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
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
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.assignment_rounded,
                      size: 32, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text('$examCategory模考',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 6),
                const Text('按当前考试目标生成仿真练习',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('考试分类',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 12),
          _buildExamCategorySelector(provider),
          const SizedBox(height: 24),
          const Text('选择题量',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: countOptions.map((count) {
              final sel = _selectedCount == count;
              final isFirst = count == countOptions.first;
              final isLast = count == countOptions.last;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: isFirst ? 0 : 8,
                    right: isLast ? 0 : 8,
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCount = count),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppTheme.primary.withOpacity(0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? AppTheme.primary : AppTheme.divider,
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text('$count',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: sel
                                      ? AppTheme.primary
                                      : AppTheme.textPrimary)),
                          Text('题',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: sel
                                      ? AppTheme.primary
                                      : AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (availableCount != null) ...[
            const SizedBox(height: 10),
            Text(
              availableCount > 0
                  ? '当前题库可用于模考：$availableCount 题，已自动隐藏超出题库数量的选项。'
                  : '当前考试目标暂无可用模考题，请先在后台添加题目。',
              style: TextStyle(
                color: availableCount > 0
                    ? AppTheme.textSecondary
                    : AppTheme.error,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 20, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text(
                  '预计时长 ${_selectedCount ~/ 2} 分钟',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: canStart
                  ? () {
                      context
                          .read<QuestionProvider>()
                          .loadExamQuestions(count: _selectedCount);
                    }
                  : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('开始模考'),
            ),
          ),
          if (provider.error != null) ...[
            const SizedBox(height: 14),
            Center(
              child: Text(
                provider.error!,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text('考试说明',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 12),
          _RuleItem(Icons.access_time_rounded, '限时作答', '按标准考试时间计时'),
          _RuleItem(Icons.lock_outline_rounded, '提交后锁定', '交卷前可检查答案，交卷后不能修改'),
          _RuleItem(Icons.bar_chart_rounded, '详细报告', '考后查看知识点分析'),
          const SizedBox(height: 24),
          _ExamHistorySection(attempts: provider.examAttempts),
        ],
      ),
    );
  }

  Widget _buildExamCategorySelector(QuestionProvider provider) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConstants.examCategories.map((category) {
        final isSelected = category == provider.examCategory;
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
          backgroundColor: Colors.white,
          side: BorderSide(
            color: isSelected ? AppTheme.primary : AppTheme.divider,
          ),
          onSelected: (_) {
            if (isSelected) return;
            _switchExamCategory(category);
          },
        );
      }).toList(),
    );
  }

  Future<void> _switchExamCategory(String category) async {
    setState(() => _selectedCount = 50);
    final questionProvider = context.read<QuestionProvider>();
    questionProvider.setExamCategory(category);

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

    final saved = await context.read<AuthProvider>().updateTargetExam(category);
    if (!mounted || saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.read<AuthProvider>().error ?? '考试分类已切换，但保存到账号失败',
        ),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  List<int> _buildCountOptions(int? availableCount) {
    if (availableCount == null) return const [25, 50, 100];
    if (availableCount <= 0) return const [25];
    final options = <int>[];
    for (final count in const [25, 50, 100]) {
      if (count <= availableCount) options.add(count);
    }
    if (!options.contains(availableCount)) {
      options.add(availableCount);
    }
    options.sort();
    return options;
  }
}

class _ExamHistorySection extends StatelessWidget {
  final List<ExamAttemptSummary> attempts;

  const _ExamHistorySection({required this.attempts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('模考记录',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    fontSize: 16)),
            TextButton.icon(
              onPressed: () =>
                  context.read<QuestionProvider>().loadExamAttempts(),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('刷新'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (attempts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('暂无模考记录，完成一次模考后可在这里回看报告。',
                style: TextStyle(color: AppTheme.textSecondary)),
          )
        else
          ...attempts.map(
            (attempt) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ExamAttemptCard(attempt: attempt),
            ),
          ),
      ],
    );
  }
}

class _ExamAttemptCard extends StatelessWidget {
  final ExamAttemptSummary attempt;

  const _ExamAttemptCard({required this.attempt});

  String get _dateText {
    final d = attempt.createdAt;
    return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String get _timeText {
    final minutes = attempt.timeSpent ~/ 60;
    final seconds = attempt.timeSpent % 60;
    return '$minutes分${seconds.toString().padLeft(2, '0')}秒';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final provider = context.read<QuestionProvider>();
        final result = await provider.loadExamAttempt(attempt.id);
        if (!context.mounted) return;
        if (result == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(provider.error ?? '加载模考报告失败')),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _ExamResultView(
              result: result,
              timedOut: false,
              onDone: () => Navigator.pop(context),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _formatScore(attempt.score),
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${attempt.examCategory}模考 · $_dateText',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    '正确 ${attempt.correctCount}/${attempt.totalQuestions} 题 · 错 ${attempt.wrongCount} 题 · 用时 $_timeText',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              '查看报告',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _RuleItem(this.icon, this.title, this.desc);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ 考试会话 ════════════════
class _ExamSessionScreen extends StatefulWidget {
  final int questionCount;
  const _ExamSessionScreen({required this.questionCount});

  @override
  State<_ExamSessionScreen> createState() => _ExamSessionScreenState();
}

class _ExamSessionScreenState extends State<_ExamSessionScreen> {
  Timer? _timer;
  int _seconds = 0;
  late final int _initialSeconds;
  bool _isSubmitting = false;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<QuestionProvider>();
    final actualCount = provider.currentQuestions.length;
    _initialSeconds = (actualCount ~/ 2).clamp(1, 100000) * 60;
    _seconds = _initialSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds > 0) {
        setState(() => _seconds--);
      } else {
        _timer?.cancel();
        _submitExam(timedOut: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeStr {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int get _timeSpent => _initialSeconds - _seconds;
  bool get _locked => _isSubmitting || _timedOut;

  Future<void> _confirmSubmitExam() async {
    if (_locked) return;
    final shouldSubmit = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('确认交卷？'),
            content: const Text('交卷后不能修改答案，剩余未答题将按未答处理。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('继续答题'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('交卷'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldSubmit || !mounted) return;
    await _submitExam();
  }

  Future<void> _confirmExitExam() async {
    if (_locked) return;
    final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('退出本次模考？'),
            content: const Text('当前答题进度会清空，不会生成报告。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('继续答题'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('退出'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldExit || !mounted) return;
    _timer?.cancel();
    context.read<QuestionProvider>().reset();
  }

  Future<void> _submitExam({bool timedOut = false}) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _timedOut = timedOut;
    });
    _timer?.cancel();
    final result = await context.read<QuestionProvider>().submitExam(
          timeSpent: _timeSpent,
        );
    if (!mounted) return;
    if (result != null) {
      final examCategory = context.read<QuestionProvider>().examCategory;
      final study = context.read<StudyProvider>();
      await study.loadTodayStats(examCategory: examCategory);
      await study.loadTodayTask(examCategory: examCategory);
      await study.loadPrescription(examCategory: examCategory);
      await study.loadStatsOverview(examCategory: examCategory);
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (result == null && !timedOut) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds > 0) {
        setState(() => _seconds--);
      } else {
        _timer?.cancel();
        _submitExam(timedOut: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuestionProvider>(
      builder: (context, provider, _) {
        final q = provider.currentQuestion;
        final examResult = provider.examResult;
        if (q == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (examResult != null) {
          return _ExamResultView(
            result: examResult,
            timedOut: _timedOut,
            onDone: () => provider.reset(),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_timeStr,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: _seconds < 120
                        ? AppTheme.error
                        : AppTheme.textPrimary)),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: '退出模考',
              onPressed: _locked ? null : _confirmExitExam,
            ),
            actions: [
              TextButton(
                onPressed: _locked ? null : _confirmSubmitExam,
                child: Text(_isSubmitting ? '交卷中...' : '交卷'),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    '${provider.currentIndex + 1}/${provider.currentQuestions.length}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // 进度条
              ClipRRect(
                child: LinearProgressIndicator(
                  value: provider.progress,
                  minHeight: 4,
                  backgroundColor: AppTheme.divider,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Tag(
                          q.questionType == 'single'
                              ? '单选题'
                              : q.questionType == 'multi'
                                  ? '多选题'
                                  : '病例题',
                          AppTheme.primary),
                      const SizedBox(height: 16),
                      Text(q.content,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 1.6)),
                      const SizedBox(height: 20),
                      ...q.options.entries.map((entry) {
                        final selected =
                            provider.examAnswers[q.id] == entry.key;
                        final border =
                            selected ? AppTheme.primary : AppTheme.divider;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: selected
                                ? AppTheme.primary.withOpacity(0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: _locked
                                  ? null
                                  : () => provider.selectExamAnswer(entry.key),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: border,
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: selected
                                            ? AppTheme.primary
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: selected
                                              ? AppTheme.primary
                                              : AppTheme.textSecondary,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(entry.key,
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: selected
                                                    ? Colors.white
                                                    : AppTheme.textSecondary)),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: Text(entry.value,
                                            style: const TextStyle(
                                                height: 1.4, fontSize: 15))),
                                    if (selected)
                                      const Icon(Icons.check_circle_rounded,
                                          color: AppTheme.primary, size: 22),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      if (provider.error != null) ...[
                        const SizedBox(height: 16),
                        Text(provider.error!,
                            style: const TextStyle(color: AppTheme.error)),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
              // 底部操作
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 8,
                        offset: Offset(0, -2)),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      if (provider.currentIndex > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => provider.previousQuestion(),
                            child: const Text('上一题'),
                          ),
                        ),
                      if (provider.currentIndex > 0) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting
                              ? null
                              : provider.isLastQuestion
                                  ? _confirmSubmitExam
                                  : () => provider.nextQuestion(),
                          child: Text(
                            _isSubmitting
                                ? '交卷中...'
                                : provider.isLastQuestion
                                    ? '交卷'
                                    : '下一题',
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
      },
    );
  }
}

class _ExamResultView extends StatelessWidget {
  final ExamResult result;
  final bool timedOut;
  final VoidCallback onDone;

  const _ExamResultView({
    required this.result,
    required this.timedOut,
    required this.onDone,
  });

  String get _timeText {
    final minutes = result.timeSpent ~/ 60;
    final seconds = result.timeSpent % 60;
    return '$minutes分${seconds.toString().padLeft(2, '0')}秒';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('模考成绩'),
        actions: [
          TextButton(onPressed: onDone, child: const Text('完成')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: [
                  if (timedOut)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text('考试时间已到，系统已自动交卷',
                          style: TextStyle(
                              color: AppTheme.error,
                              fontWeight: FontWeight.w600)),
                    ),
                  Text('${_formatScore(result.score)}分',
                      style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary)),
                  const SizedBox(height: 8),
                  Text(
                    '正确 ${result.correctCount} / ${result.totalQuestions} 题',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _ResultMetric('用时', _timeText),
                const SizedBox(width: 10),
                _ResultMetric('已答', '${result.answeredCount}题'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _ResultMetric('未答', '${result.unansweredCount}题'),
                const SizedBox(width: 10),
                _ResultMetric('错题', '${result.wrongCount}题'),
              ],
            ),
            const SizedBox(height: 16),
            _ExamReportCard(result: result),
            const SizedBox(height: 16),
            _ExamNextActionCard(
              result: result,
              onBackToExamHome: onDone,
            ),
            const SizedBox(height: 24),
            const Text('错题解析',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            if (result.wrongQuestions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('本次模考没有错题',
                    style: TextStyle(color: AppTheme.success)),
              )
            else
              ...result.wrongQuestions.map((item) => _WrongQuestionCard(item)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onDone,
                child: const Text('返回模考首页'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamNextActionCard extends StatelessWidget {
  final ExamResult result;
  final VoidCallback onBackToExamHome;

  const _ExamNextActionCard({
    required this.result,
    required this.onBackToExamHome,
  });

  @override
  Widget build(BuildContext context) {
    final weakTag = result.weakTagCounts.keys.isNotEmpty
        ? result.weakTagCounts.keys.first
        : null;
    final hasWrongQuestions = result.wrongQuestions.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.route_rounded, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                '下一步学习安排',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _nextActionText(result, weakTag),
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (hasWrongQuestions)
                _ActionChipButton(
                  icon: Icons.assignment_late_rounded,
                  label: '复习本次错题',
                  color: AppTheme.error,
                  onTap: () => _startPractice(
                    context,
                    mode: 'wrong',
                    questionIds: result.wrongQuestions
                        .map((question) => question.questionId)
                        .toList(),
                    title: '模考错题复习',
                  ),
                ),
              if (weakTag != null)
                _ActionChipButton(
                  icon: Icons.local_fire_department_rounded,
                  label: '练习薄弱点：$weakTag',
                  color: Colors.orange,
                  onTap: () => _startPractice(
                    context,
                    mode: 'tag',
                    tag: weakTag,
                    title: '$weakTag专项巩固',
                  ),
                ),
              _ActionChipButton(
                icon: Icons.refresh_rounded,
                label: '返回模考首页',
                color: AppTheme.primary,
                onTap: onBackToExamHome,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _nextActionText(ExamResult result, String? weakTag) {
    if (result.wrongQuestions.isEmpty && result.accuracyRate >= 0.8) {
      return '这次发挥不错，可以回到模考首页再开一套限时模考，保持考试手感。';
    }
    if (weakTag != null) {
      return '建议先处理失分最多的知识点“$weakTag”，再回到模考检验是否真正补上短板。';
    }
    if (result.wrongQuestions.isNotEmpty) {
      return '先把本次错题复习一遍，确认每道题为什么错，再进入下一轮训练。';
    }
    return '本次报告已生成，可以回到模考首页继续下一套练习。';
  }

  Future<void> _startPractice(
    BuildContext context, {
    required String mode,
    String? tag,
    List<int>? questionIds,
    required String title,
  }) async {
    final provider = context.read<QuestionProvider>();
    await provider.loadPracticeQuestions(
      mode: mode,
      tag: tag,
      questionIds: questionIds,
      title: title,
    );
    if (!context.mounted) return;
    if (provider.currentQuestions.isEmpty) {
      final message = provider.error ??
          (mode == 'tag' ? '当前薄弱点暂无可练习题目，请先复习本次错题' : '暂无可复习题目');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PracticeScreen()),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ResultMetric(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _ExamReportCard extends StatefulWidget {
  final ExamResult result;

  const _ExamReportCard({required this.result});

  @override
  State<_ExamReportCard> createState() => _ExamReportCardState();
}

class _ExamReportCardState extends State<_ExamReportCard> {
  late Future<AITextResult?> _aiReportFuture;

  @override
  void initState() {
    super.initState();
    _aiReportFuture = _initialReportFuture();
  }

  Future<AITextResult?> _initialReportFuture() {
    final result = widget.result;
    final cached = result.aiReport;
    if (cached != null && cached.content.trim().isNotEmpty) {
      return Future.value(
        AITextResult(
          title: cached.title,
          content: cached.content,
          actions: cached.actions,
          isDemo: cached.isDemo,
          sessionId: cached.sessionId,
          userMessageId: cached.userMessageId,
          assistantMessageId: cached.assistantMessageId,
        ),
      );
    }
    return _generateReport();
  }

  Future<AITextResult?> _generateReport() {
    final result = widget.result;
    return context.read<AIChatProvider>().buildExamReport(
          attemptId: result.id,
          examCategory: result.examCategory ?? '执业资格',
          totalQuestions: result.totalQuestions,
          correctCount: result.correctCount,
          wrongCount: result.wrongCount,
          unansweredCount: result.unansweredCount,
          accuracyRate: result.accuracyRate,
          timeSpent: result.timeSpent,
          weakTags: result.weakTagCounts,
        );
  }

  void _refreshReport() {
    setState(() {
      _aiReportFuture = _generateReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final topTags = result.weakTagCounts.entries.take(4).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<AITextResult?>(
            future: _aiReportFuture,
            builder: (context, snapshot) {
              final ai = snapshot.data;
              final isWaiting =
                  snapshot.connectionState == ConnectionState.waiting;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        ai?.title.trim().isNotEmpty == true
                            ? ai!.title
                            : 'AI 模考报告',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (isWaiting) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                      const Spacer(),
                      TextButton.icon(
                        onPressed: isWaiting ? null : _refreshReport,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('刷新'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isWaiting)
                    const Text(
                      '正在生成 AI 模考报告，请稍候…',
                      style: TextStyle(
                          color: AppTheme.textSecondary, height: 1.45),
                    )
                  else if (ai?.content.isNotEmpty == true)
                    Text(_readableAiContent(ai!.content),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, height: 1.45))
                  else
                    ...result.aiAdvice.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w800)),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    height: 1.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (ai?.actions.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ai!.actions
                          .map((action) => _Tag(action, AppTheme.primary))
                          .toList(),
                    ),
                  ],
                ],
              );
            },
          ),
          if (topTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topTags
                  .map((entry) => _Tag('${entry.key} ×${entry.value}',
                      entry.value >= 2 ? AppTheme.error : AppTheme.accent))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniReportMetric(
                label: '正确率',
                value: '${(result.accuracyRate * 100).round()}%',
              ),
              const SizedBox(width: 8),
              _MiniReportMetric(
                label: '平均用时',
                value: '${result.averageSecondsPerQuestion.round()}秒/题',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _readableAiContent(String raw) {
    return raw
        .split('\n')
        .map((line) => line
            .replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '')
            .replaceAll('**', '')
            .replaceFirst(RegExp(r'^\s*[-*]\s+'), '• ')
            .trimRight())
        .where((line) => line.trim().isNotEmpty)
        .join('\n');
  }
}

class _MiniReportMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniReportMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.82),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textHint,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _WrongQuestionCard extends StatelessWidget {
  final ExamQuestionResult item;

  const _WrongQuestionCard(this.item);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.content,
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.5)),
          const SizedBox(height: 10),
          Text('你的答案：${item.selectedAnswer ?? '未答'}',
              style: const TextStyle(color: AppTheme.error)),
          const SizedBox(height: 4),
          Text('正确答案：${item.correctAnswer}',
              style: const TextStyle(color: AppTheme.success)),
          if (item.explanation != null && item.explanation!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(item.explanation!,
                style: const TextStyle(
                    color: AppTheme.textSecondary, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    );
  }
}

String _formatScore(double score) {
  if (score == score.roundToDouble()) return score.toStringAsFixed(0);
  return score.toStringAsFixed(1);
}
