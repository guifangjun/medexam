import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/question_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/app_glass.dart';

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
    return GlassScaffold(
      appBar: AppBar(
        title: Text(context.watch<QuestionProvider>().hasQuestions
            ? context.watch<QuestionProvider>().practiceTitle ?? '刷题'
            : '专项练习'),
        actions: [
          if (context.watch<QuestionProvider>().hasQuestions)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.read<QuestionProvider>().reset(),
            ),
        ],
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
            Icon(Icons.folder_open_rounded, size: 64, color: AppTheme.textHint),
            const SizedBox(height: 16),
            Text(
              provider.error ?? '暂无题目',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        _buildModeGrid(context, provider),
        const SizedBox(height: 18),
        const Text(
          '章节练习',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(chapters.length, (index) {
          final ch = chapters[index];
          final colors = [
            AppTheme.primary,
            AppTheme.accent,
            const Color(0xFF7C4DFF),
            AppTheme.success,
            AppTheme.error,
            AppTheme.primaryLight,
            Colors.orange,
          ];
          final c = colors[index % colors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              onTap: () async {
                await provider.loadPracticeQuestions(
                  chapterId: ch.id,
                  mode: 'chapter',
                  title: ch.name,
                );
                if (!context.mounted) return;
                final updated = context.read<QuestionProvider>();
                if (!updated.hasQuestions && updated.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${ch.name}：${updated.error}')),
                  );
                }
              },
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: c,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ch.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppTheme.textPrimary)),
                        if (ch.subjects.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(ch.subjects.join('、'),
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppTheme.textHint, size: 20),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildModeGrid(BuildContext context, QuestionProvider provider) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.35,
      children: [
        _ModeCard(
          icon: Icons.playlist_add_check_rounded,
          title: '未做题',
          subtitle: '优先补空白',
          color: AppTheme.accent,
          onTap: () => _startMode(context, provider, mode: 'unanswered'),
        ),
        _ModeCard(
          icon: Icons.assignment_late_rounded,
          title: '错题复习',
          subtitle: '只练未掌握',
          color: AppTheme.error,
          onTap: () => _startMode(context, provider, mode: 'wrong'),
        ),
        _ModeCard(
          icon: Icons.local_fire_department_rounded,
          title: '高频考点',
          subtitle: '按标签抽题',
          color: Colors.orange,
          onTap: () => _startMode(context, provider, mode: 'tag', tag: '内科学'),
        ),
        _ModeCard(
          icon: Icons.shuffle_rounded,
          title: '随机练习',
          subtitle: '快速热身',
          color: AppTheme.success,
          onTap: () => _startMode(context, provider, mode: 'random'),
        ),
      ],
    );
  }

  Future<void> _startMode(
    BuildContext context,
    QuestionProvider provider, {
    required String mode,
    String? tag,
  }) async {
    await provider.loadPracticeQuestions(mode: mode, tag: tag, limit: 20);
    if (!context.mounted) return;
    final updated = context.read<QuestionProvider>();
    if (!updated.hasQuestions && updated.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(updated.error!)),
      );
    }
  }

  Widget _buildQuestionView(BuildContext context, QuestionProvider provider) {
    final question = provider.currentQuestion!;
    final result = provider.lastResult;

    return Column(
      children: [
        // 进度
        GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: provider.progress,
                    minHeight: 6,
                    backgroundColor: AppTheme.divider,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${provider.currentIndex + 1}/${provider.currentQuestions.length}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标签
                Row(
                  children: [
                    _Tag(
                      question.questionType == 'single'
                          ? '单选题'
                          : question.questionType == 'multi'
                              ? '多选题'
                              : '病例题',
                      AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    _Tag(
                      '难度 ${question.difficulty ?? 3}',
                      AppTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 题目
                Text(
                  question.content ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                // 选项
                ...(question.options ?? {}).entries.map((entry) {
                  Color? bg;
                  Color? border;
                  IconData? trailing;
                  if (result != null) {
                    final isSelected = entry.key == result.selectedAnswer;
                    final isCorrectKey = entry.key == result.correctAnswer;
                    if (isCorrectKey) {
                      bg = AppTheme.success.withOpacity(0.08);
                      border = AppTheme.success;
                      trailing = Icons.check_circle_rounded;
                    } else if (isSelected && !result.isCorrect) {
                      bg = AppTheme.error.withOpacity(0.08);
                      border = AppTheme.error;
                      trailing = Icons.cancel_rounded;
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      onTap: result == null
                          ? () => provider.submitAnswer(entry.key)
                          : null,
                      radius: 14,
                      padding: const EdgeInsets.all(16),
                      tint: bg ?? AppTheme.glassFill,
                      borderColor: border ?? AppTheme.glassStroke,
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  border != null ? border : Colors.transparent,
                              border: Border.all(
                                color: border ?? AppTheme.textSecondary,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: border != null
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(entry.value,
                                style:
                                    const TextStyle(height: 1.4, fontSize: 15)),
                          ),
                          if (trailing != null)
                            Icon(trailing, color: border, size: 22),
                        ],
                      ),
                    ),
                  );
                }),
                // 解析
                if (result != null && result.explanation != null) ...[
                  const SizedBox(height: 20),
                  GlassCard(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    radius: 14,
                    tint: AppTheme.primary.withOpacity(0.08),
                    borderColor: AppTheme.primary.withOpacity(0.12),
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
        if (result != null)
          GlassPanel(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => provider.isLastQuestion
                      ? provider.reset()
                      : provider.nextQuestion(),
                  child: Text(provider.isLastQuestion ? '完成刷题' : '下一题'),
                ),
              ),
            ),
          ),
      ],
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

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
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
      padding: const EdgeInsets.all(14),
      tint: Colors.white.withOpacity(0.78),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
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
        ],
      ),
    );
  }
}
