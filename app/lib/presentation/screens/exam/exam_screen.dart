import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    final examCategory = context.watch<QuestionProvider>().examCategory;
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
        ],
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

  @override
  void initState() {
    super.initState();
    _seconds = widget.questionCount ~/ 2 * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds > 0) {
        setState(() => _seconds--);
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

  @override
  Widget build(BuildContext context) {
    return Consumer<QuestionProvider>(
      builder: (context, provider, _) {
        final q = provider.currentQuestion;
        final result = provider.lastResult;
        if (q == null) {
          return const Center(child: CircularProgressIndicator());
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
                          provider.reset();
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
                      Text(q.content ?? '',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 1.6)),
                      const SizedBox(height: 20),
                      ...(q.options ?? {}).entries.map((entry) {
                        Color? bg, border;
                        IconData? trailing;
                        if (result != null) {
                          final sel = entry.key == result.selectedAnswer;
                          final correct = entry.key == result.correctAnswer;
                          if (correct) {
                            bg = AppTheme.success.withOpacity(0.08);
                            border = AppTheme.success;
                            trailing = Icons.check_circle_rounded;
                          } else if (sel && !result.isCorrect) {
                            bg = AppTheme.error.withOpacity(0.08);
                            border = AppTheme.error;
                            trailing = Icons.cancel_rounded;
                          }
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: bg ?? Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: result == null
                                  ? () => provider.submitAnswer(entry.key)
                                  : null,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: border ?? AppTheme.divider,
                                    width: border != null ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: border != null
                                            ? border
                                            : Colors.transparent,
                                        border: Border.all(
                                          color:
                                              border ?? AppTheme.textSecondary,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(entry.key,
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: border != null
                                                    ? Colors.white
                                                    : AppTheme.textSecondary)),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: Text(entry.value,
                                            style: const TextStyle(
                                                height: 1.4, fontSize: 15))),
                                    if (trailing != null)
                                      Icon(trailing, color: border, size: 22),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      if (result != null && result.explanation != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppTheme.primary.withOpacity(0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.lightbulb_outline_rounded,
                                      color: AppTheme.primary, size: 18),
                                  SizedBox(width: 8),
                                  Text('解析',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primary)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(result.explanation!,
                                  style: const TextStyle(
                                      height: 1.6,
                                      color: AppTheme.textPrimary,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
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
                            onPressed: () => provider.previousQuestion(),
                            child: const Text('上一题'),
                          ),
                        ),
                      if (provider.currentIndex > 0) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: result == null
                              ? null
                              : provider.isLastQuestion
                                  ? () => provider.reset()
                                  : () => provider.nextQuestion(),
                          child: Text(
                            provider.isLastQuestion ? '完成考试' : '下一题',
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
