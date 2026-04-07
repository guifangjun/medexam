import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/question_provider.dart';
import '../../../core/theme/app_theme.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuestionProvider>().loadChapters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('章节练习'),
      ),
      body: Consumer<QuestionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!provider.hasQuestions) {
            return _buildChapterList(context, provider);
          }

          return _buildQuestionView(context, provider);
        },
      ),
    );
  }

  Widget _buildChapterList(BuildContext context, QuestionProvider provider) {
    final chapters = provider.chapters;

    if (chapters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无章节数据',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Text(chapter.name),
            subtitle: chapter.subjects.isNotEmpty
                ? Text(chapter.subjects.join('、'))
                : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              provider.loadPracticeQuestions(chapterId: chapter.id);
            },
          ),
        );
      },
    );
  }

  Widget _buildQuestionView(BuildContext context, QuestionProvider provider) {
    final question = provider.currentQuestion!;
    final result = provider.lastResult;

    return Column(
      children: [
        // 进度条
        LinearProgressIndicator(
          value: provider.progress,
          backgroundColor: Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 题号和类型
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '第 ${provider.currentIndex + 1} 题',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        question.questionType == 'single'
                            ? '单选题'
                            : question.questionType == 'multi'
                                ? '多选题'
                                : '病例题',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                    const Spacer(),
                    if (result != null)
                      Icon(
                        result.isCorrect
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: result.isCorrect
                            ? AppTheme.secondaryColor
                            : AppTheme.errorColor,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // 题干
                Text(
                  question.content,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                // 选项
                ...question.options.entries.map<Widget>((entry) {
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
                                  color:
                                      borderColor ?? AppTheme.primaryColor,
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
        // 底部按钮
        if (result != null)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (!provider.isLastQuestion)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => provider.nextQuestion(),
                      child: const Text('下一题'),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => provider.reset(),
                      child: const Text('完成练习'),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
