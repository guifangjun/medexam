import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/question.dart';
import '../../../data/providers/question_provider.dart';
import '../../../core/theme/app_theme.dart';

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
      context.read<QuestionProvider>().loadExamAttempts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('模考')),
      body: Consumer<QuestionProvider>(
        builder: (context, provider, _) {
          if (provider.hasQuestions) {
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
          const Text('选择题量',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: [25, 50, 100].map((count) {
              final sel = _selectedCount == count;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      left: count == 25 ? 0 : 8, right: count == 100 ? 0 : 8),
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
              onPressed: () {
                context
                    .read<QuestionProvider>()
                    .loadExamQuestions(count: _selectedCount);
              },
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
          _RuleItem(Icons.lock_outline_rounded, '不可回退', '提交后不能返回修改'),
          _RuleItem(Icons.bar_chart_rounded, '详细报告', '考后查看知识点分析'),
          const SizedBox(height: 24),
          _ExamHistorySection(attempts: provider.examAttempts),
        ],
      ),
    );
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
        if (!context.mounted || result == null) return;
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
                attempt.score.toStringAsFixed(0),
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
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
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
              icon: const Icon(Icons.close),
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('确认交卷？'),
                  content: const Text('剩余未答题将不计分。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('继续答题')),
                    ElevatedButton(
                        onPressed: () {
                          _submitExam();
                          Navigator.pop(ctx);
                        },
                        child: const Text('交卷')),
                  ],
                ),
              ),
            ),
            actions: [
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
                                  ? () => _submitExam()
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
                  Text('${result.score.toStringAsFixed(1)}分',
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

class _ExamReportCard extends StatelessWidget {
  final ExamResult result;

  const _ExamReportCard({required this.result});

  @override
  Widget build(BuildContext context) {
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
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'AI 学习建议',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                          color: AppTheme.textSecondary, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
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
