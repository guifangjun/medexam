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
      appBar: AppBar(
        title: const Text('模拟考试'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择题量',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [25, 50, 100].map((count) {
                final isSelected = _selectedCount == count;
                return ChoiceChip(
                  label: Text('$count 题'),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCount = count),
                  selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.timer,
                      size: 48,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '模拟考试',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '共 $_selectedCount 题，时间 ${_selectedCount ~/ 2} 分钟',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '题型：单选、多选、病例题',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          context
                              .read<QuestionProvider>()
                              .loadExamQuestions(count: _selectedCount);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const _ExamSessionScreen(),
                            ),
                          );
                        },
                        child: const Text('开始考试'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '考试说明',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildExamRule(
              Icons.access_time,
              '计时考试',
              '按考试标准时间计时，超时自动提交',
            ),
            _buildExamRule(
              Icons.block,
              '不能回改',
              '提交答案后不能返回修改',
            ),
            _buildExamRule(
              Icons.bar_chart,
              '详细报告',
              '考试结束后查看正确率和知识点分析',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamRule(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  desc,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamSessionScreen extends StatelessWidget {
  const _ExamSessionScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('考试中'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('退出考试？'),
                content: const Text('退出后考试将被标记为未完成'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text('退出'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: Consumer<QuestionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!provider.hasQuestions) {
            return const Center(child: Text('暂无题目'));
          }

          return _ExamQuestionView(provider: provider);
        },
      ),
    );
  }
}

class _ExamQuestionView extends StatelessWidget {
  final QuestionProvider provider;

  const _ExamQuestionView({required this.provider});

  @override
  Widget build(BuildContext context) {
    final question = provider.currentQuestion!;
    final result = provider.lastResult;

    return Column(
      children: [
        LinearProgressIndicator(
          value: provider.progress,
          backgroundColor: Colors.grey[200],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '第 ${provider.currentIndex + 1}/${provider.currentQuestions.length} 题',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      question.questionType == 'single'
                          ? '单选题'
                          : question.questionType == 'multi'
                              ? '多选题'
                              : '病例题',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  question.content,
                  style: const TextStyle(fontSize: 16, height: 1.6),
                ),
                const SizedBox(height: 24),
                ...question.options.entries.map((entry) {
                  final isSelected = result != null &&
                      entry.key.toUpperCase() ==
                          result.selectedAnswer.toUpperCase();

                  Color? bgColor;
                  Color? borderColor;
                  if (result != null) {
                    if (entry.key.toUpperCase() ==
                        result.correctAnswer.toUpperCase()) {
                      bgColor = AppTheme.secondaryColor.withOpacity(0.1);
                      borderColor = AppTheme.secondaryColor;
                    } else if (isSelected && !result.isCorrect) {
                      bgColor = AppTheme.errorColor.withOpacity(0.1);
                      borderColor = AppTheme.errorColor;
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: result == null
                          ? () => provider.submitAnswer(entry.key)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bgColor ?? Colors.white,
                          border: Border.all(
                            color: borderColor ?? Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: borderColor ?? AppTheme.primaryColor,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: borderColor ?? AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: const TextStyle(height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                // 解析
                if (result != null && result.explanation != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lightbulb_outline,
                                color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '解析',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          result.explanation!,
                          style: const TextStyle(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
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
                  onPressed: provider.isLastQuestion && result != null
                      ? () => Navigator.pop(context)
                      : result == null
                          ? null
                          : () => provider.nextQuestion(),
                  child: Text(
                    provider.isLastQuestion && result != null
                        ? '完成考试'
                        : result == null
                            ? '请先作答'
                            : '下一题',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
