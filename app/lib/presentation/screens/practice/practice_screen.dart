import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/conversation.dart';
import '../../../data/providers/ai_chat_provider.dart';
import '../../../data/providers/question_provider.dart';
import '../../../data/providers/study_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/app_glass.dart';
import '../ai_chat/ai_chat_screen.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  DateTime _questionStartedAt = DateTime.now();
  int? _activeQuestionId;
  AITextResult? _questionCoachResult;
  int? _questionCoachQuestionId;
  bool _isLoadingQuestionCoach = false;
  bool _isQuestionCoachCollected = false;
  AIReasoningEvaluation? _reasoningEvaluation;
  int? _reasoningQuestionId;
  bool _isEvaluatingReasoning = false;
  bool _isLoadingPracticeReview = false;

  @override
  void initState() {
    super.initState();
    _questionStartedAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<QuestionProvider>();
      if (!provider.hasPracticeQuestions && provider.chapters.isEmpty) {
        provider.loadChapters();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuestionProvider>();
    final hasActivePractice =
        provider.hasPracticeQuestions || provider.practiceAttempted;
    return PopScope(
      canPop: !hasActivePractice,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && hasActivePractice) {
          _confirmExitPractice(context);
        }
      },
      child: GlassScaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  tooltip: '返回',
                  onPressed: hasActivePractice
                      ? () => _confirmExitPractice(context)
                      : () => Navigator.pop(context),
                )
              : null,
          title: Text(_titleFor(provider)),
          actions: [
            if (hasActivePractice)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: '退出练习',
                onPressed: () => _confirmExitPractice(context),
              ),
          ],
        ),
        body: Consumer<QuestionProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!provider.hasPracticeQuestions) {
              if (provider.practiceAttempted &&
                  provider.practiceMode != 'exam') {
                return _buildPracticeEmpty(context, provider);
              }
              return _buildChapterList(context, provider);
            }
            return _buildQuestionView(context, provider);
          },
        ),
      ),
    );
  }

  String _titleFor(QuestionProvider provider) {
    if ((provider.hasPracticeQuestions || provider.practiceAttempted) &&
        provider.practiceMode != 'exam') {
      return provider.practiceTitle ?? '刷题';
    }
    return '专项练习';
  }

  Future<void> _confirmExitPractice(BuildContext context) async {
    final provider = context.read<QuestionProvider>();
    final shouldConfirm = provider.hasPracticeQuestions;
    var shouldExit = true;
    if (shouldConfirm) {
      shouldExit = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('退出本次练习？'),
              content: const Text('当前练习进度会被清空，已提交的答题记录会保留。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('继续练习'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('退出'),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (!shouldExit || !context.mounted) return;
    final canReturnToPreviousPage = Navigator.canPop(context);
    provider.reset();
    if (canReturnToPreviousPage) {
      Navigator.pop(context);
    } else if (provider.chapters.isEmpty) {
      await provider.loadChapters();
    }
  }

  Widget _buildPracticeEmpty(BuildContext context, QuestionProvider provider) {
    final title = provider.practiceTitle ?? _emptyTitle(provider.practiceMode);
    final canSwitchToCurrentChapter = provider.practiceMode != 'chapter' &&
        provider.practiceChapterId != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          tint: Colors.white.withOpacity(0.82),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: AppTheme.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _emptyMessage(provider.practiceMode, provider.error),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () async {
                    if (canSwitchToCurrentChapter) {
                      await provider.loadPracticeQuestions(
                        chapterId: provider.practiceChapterId,
                        mode: 'chapter',
                        title: _chapterPracticeFallbackTitle(provider),
                      );
                      return;
                    }
                    provider.reset();
                    if (provider.chapters.isEmpty) {
                      await provider.loadChapters();
                    }
                  },
                  child: Text(
                    canSwitchToCurrentChapter ? '切换到本章节练习' : '返回章节练习',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _emptyTitle(String mode) {
    switch (mode) {
      case 'adaptive':
        return 'AI 自适应练习';
      case 'unanswered':
        return '未做题练习';
      case 'wrong':
        return '错题复习';
      case 'tag':
        return '高频考点';
      case 'random':
        return '随机练习';
      default:
        return '章节练习';
    }
  }

  String _chapterPracticeFallbackTitle(QuestionProvider provider) {
    final currentTitle = provider.practiceTitle?.trim();
    if (currentTitle == null || currentTitle.isEmpty) return '本章节练习';
    final parts = currentTitle
        .split('·')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length <= 1) return '本章节练习';
    return '${parts.first} · 本章节练习';
  }

  String _emptyMessage(String mode, String? error) {
    if (error != null && error != '暂无题目') return error;
    switch (mode) {
      case 'adaptive':
        return 'AI 暂未选出合适题目，可以先完成一组章节练习，积累能力数据后再试。';
      case 'unanswered':
        return '这个范围内暂时没有未做题，可以切换章节练习或课后练习继续巩固。';
      case 'wrong':
        return '当前没有待复习错题，继续做题后错题会自动进入错题本。';
      case 'tag':
        return '当前考试分类暂未识别到高频考点题，可以先按章节练习。';
      case 'random':
        return '当前考试分类暂无可随机抽取的题目。';
      default:
        return '暂无题目，请先在后台为该章节添加题目。';
    }
  }

  Widget _buildChapterList(BuildContext context, QuestionProvider provider) {
    final chapters = provider.chapters;
    if (chapters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            tint: Colors.white.withOpacity(0.84),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open_rounded,
                    size: 64, color: AppTheme.textHint),
                const SizedBox(height: 16),
                Text(
                  '${provider.examCategory}暂无题目',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '请在后台题库管理中添加题目，添加后这里会按当前考试分类展示章节和专项练习。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        _buildQuestionBankStatusCard(provider),
        const SizedBox(height: 14),
        _buildAdaptivePracticeCard(context, provider),
        const SizedBox(height: 14),
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

  Widget _buildQuestionBankStatusCard(QuestionProvider provider) {
    final questionCount = provider.examAvailableCount;
    final countText = questionCount == null ? '题量统计中' : '共 $questionCount 题';
    return GlassCard(
      padding: const EdgeInsets.all(16),
      tint: AppTheme.primary.withOpacity(0.07),
      borderColor: AppTheme.primary.withOpacity(0.14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.library_books_rounded,
                color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前题库：${provider.examCategory}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$countText · ${provider.chapters.length} 个章节',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeGrid(BuildContext context, QuestionProvider provider) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 3.4,
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
          subtitle: '自动匹配重点',
          color: Colors.orange,
          onTap: () => _startMode(context, provider, mode: 'tag'),
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

  Widget _buildAdaptivePracticeCard(
    BuildContext context,
    QuestionProvider provider,
  ) {
    final plan = provider.adaptivePlan;
    final subtitle = plan == null
        ? 'AI 根据你的正确率、未做题和薄弱章节，实时生成最合适的一组题'
        : '上次聚焦 ${plan.focusChapterName} · 难度 ${plan.targetDifficulty}/5';
    return GlassCard(
      onTap: () => _startAdaptivePractice(context, provider),
      padding: const EdgeInsets.all(16),
      tint: const Color(0xFF6C5CE7).withOpacity(0.09),
      borderColor: const Color(0xFF6C5CE7).withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF6C5CE7),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 自适应练习',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '每完成一组，下一组都会重新调节',
                      style: TextStyle(
                        color: Color(0xFF6C5CE7),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF6C5CE7),
                size: 17,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.5,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 11),
          const Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _AdaptiveFeatureChip(label: '动态难度'),
              _AdaptiveFeatureChip(label: '薄弱优先'),
              _AdaptiveFeatureChip(label: '未做覆盖'),
              _AdaptiveFeatureChip(label: '每组重算'),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startAdaptivePractice(
    BuildContext context,
    QuestionProvider provider,
  ) async {
    final plan = await provider.loadAdaptiveQuestions(limit: 5);
    if (!context.mounted) return;
    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'AI 自适应题组生成失败')),
      );
    }
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
    if (_activeQuestionId != question.id) {
      _activeQuestionId = question.id;
      _questionStartedAt = DateTime.now();
      _questionCoachResult = null;
      _questionCoachQuestionId = null;
      _isLoadingQuestionCoach = false;
      _isQuestionCoachCollected = false;
      _reasoningEvaluation = null;
      _reasoningQuestionId = null;
      _isEvaluatingReasoning = false;
    }

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
        if (provider.practiceMode == 'adaptive' &&
            provider.adaptivePlan != null)
          _buildAdaptivePlanBanner(provider.adaptivePlan!),
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
                      '难度 ${question.difficulty}',
                      AppTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 题目
                Text(
                  question.content,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                // 选项
                ...question.options.entries.map((entry) {
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
                      onTap: result == null && !provider.isLoading
                          ? () async {
                              final seconds = DateTime.now()
                                  .difference(_questionStartedAt)
                                  .inSeconds
                                  .clamp(1, 86400);
                              final submitted = await provider.submitAnswer(
                                entry.key,
                                timeSpent: seconds,
                              );
                              if (!context.mounted) return;
                              if (submitted != null) {
                                final examCategory = context
                                    .read<QuestionProvider>()
                                    .examCategory;
                                final study = context.read<StudyProvider>();
                                await study.loadTodayStats(
                                    examCategory: examCategory);
                                await study.loadTodayTask(
                                    examCategory: examCategory);
                                await study.loadPrescription(
                                    examCategory: examCategory);
                                await study.loadStatsOverview(
                                    examCategory: examCategory);
                              }
                              if (!context.mounted) return;
                              final error =
                                  context.read<QuestionProvider>().error;
                              if (submitted == null && error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error)),
                                );
                              }
                            }
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
                if (result != null) ...[
                  const SizedBox(height: 14),
                  _buildAiQuestionCoach(context, provider),
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
                  onPressed: _isLoadingPracticeReview
                      ? null
                      : () => provider.isLastQuestion
                          ? _finishPractice(context, provider)
                          : _goToNextQuestion(provider),
                  child: _isLoadingPracticeReview
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 9),
                            Text('AI 正在总结本组练习...'),
                          ],
                        )
                      : Text(
                          provider.isLastQuestion ? '查看练习小结' : '下一题',
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAdaptivePlanBanner(AIAdaptivePracticePlan plan) {
    final parts = <String>[
      if (plan.unseenCount > 0) '未做 ${plan.unseenCount}',
      if (plan.weakReviewCount > 0) '薄弱回测 ${plan.weakReviewCount}',
      if (plan.spacedReviewCount > 0) '间隔复习 ${plan.spacedReviewCount}',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 11),
      decoration: BoxDecoration(
        color: const Color(0xFF6C5CE7).withOpacity(0.08),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF6C5CE7).withOpacity(0.12),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.psychology_alt_rounded,
            color: Color(0xFF6C5CE7),
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '聚焦 ${plan.focusChapterName} · 目标难度 ${plan.targetDifficulty}/5',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  parts.isEmpty ? 'AI 已根据近期表现完成选题' : parts.join(' · '),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _goToNextQuestion(QuestionProvider provider) {
    provider.nextQuestion();
  }

  Future<void> _finishPractice(
    BuildContext context,
    QuestionProvider provider,
  ) async {
    if (_isLoadingPracticeReview || provider.practiceAnsweredCount == 0) return;
    final examCategory = provider.examCategory;
    final practiceTitle = provider.practiceTitle ?? '专项练习';
    final totalQuestions = provider.currentQuestions.length;
    final answeredCount = provider.practiceAnsweredCount;
    final correctCount = provider.practiceCorrectCount;
    final wrongCount = provider.practiceWrongCount;
    final totalTime = provider.practiceTotalTime;
    final wrongTags = provider.practiceWrongTagCounts;
    setState(() => _isLoadingPracticeReview = true);
    final ai = context.read<AIChatProvider>();
    final result = await ai.buildPracticeReview(
      examCategory: examCategory,
      practiceTitle: practiceTitle,
      totalQuestions: totalQuestions,
      answeredCount: answeredCount,
      correctCount: correctCount,
      wrongCount: wrongCount,
      timeSpent: totalTime,
      wrongTags: wrongTags,
    );
    if (!context.mounted) return;
    setState(() => _isLoadingPracticeReview = false);
    context.read<StudyProvider>().loadTodayStats(examCategory: examCategory);
    await _showPracticeReviewSheet(
      context,
      provider,
      aiResult: result,
      practiceTitle: practiceTitle,
      answeredCount: answeredCount,
      correctCount: correctCount,
      wrongCount: wrongCount,
      totalTime: totalTime,
      wrongTags: wrongTags,
    );
  }

  Future<void> _showPracticeReviewSheet(
    BuildContext context,
    QuestionProvider provider, {
    required AITextResult? aiResult,
    required String practiceTitle,
    required int answeredCount,
    required int correctCount,
    required int wrongCount,
    required int totalTime,
    required Map<String, int> wrongTags,
  }) async {
    final parentContext = context;
    final accuracy =
        answeredCount == 0 ? 0 : (correctCount / answeredCount * 100).round();
    final averageSeconds = answeredCount == 0 ? 0 : totalTime ~/ answeredCount;
    final weakNames = wrongTags.keys.take(3).toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.56,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    color: AppTheme.success,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '本组练习已完成',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        practiceTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _PracticeReviewMetric(
                  value: '$answeredCount',
                  label: '完成题数',
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                _PracticeReviewMetric(
                  value: '$accuracy%',
                  label: '本组正确率',
                  color: accuracy >= 80 ? AppTheme.success : AppTheme.accent,
                ),
                const SizedBox(width: 8),
                _PracticeReviewMetric(
                  value: '${averageSeconds}s',
                  label: '平均每题',
                  color: const Color(0xFF6C5CE7),
                ),
              ],
            ),
            if (weakNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.error.withOpacity(0.12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.track_changes_rounded,
                      color: AppTheme.error,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '本组重点关注：${weakNames.join('、')}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(16),
              tint: const Color(0xFF6C5CE7).withOpacity(0.07),
              borderColor: const Color(0xFF6C5CE7).withOpacity(0.15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF6C5CE7),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        aiResult?.title ?? 'AI 练习小结',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      if (aiResult?.isDemo == true)
                        const _Tag('演示建议', AppTheme.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    aiResult?.content ?? '本组已完成。建议先复习答错题，再做一组同知识点练习巩固。',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      height: 1.62,
                      fontSize: 14,
                    ),
                  ),
                  if (aiResult != null && aiResult.actions.isNotEmpty) ...[
                    const SizedBox(height: 11),
                    ...aiResult.actions.map(
                      (action) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(color: Color(0xFF6C5CE7)),
                            ),
                            Expanded(
                              child: Text(
                                action,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
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
              ),
            ),
            const SizedBox(height: 16),
            if (provider.practiceMode == 'adaptive') ...[
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final currentCount = provider.currentQuestions.length;
                    final nextLimit = currentCount < 5
                        ? 5
                        : currentCount > 30
                            ? 30
                            : currentCount;
                    Navigator.pop(sheetContext);
                    final nextPlan = await provider.loadAdaptiveQuestions(
                      limit: nextLimit,
                      excludeCurrentQuestions: true,
                    );
                    if (!parentContext.mounted) return;
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          nextPlan == null
                              ? provider.error ?? '下一组生成失败，请稍后重试'
                              : '已按本组 $accuracy% 的表现重新选题：难度 ${nextPlan.targetDifficulty}/5',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('AI 调整难度并生成下一组'),
                ),
              ),
              const SizedBox(height: 9),
            ],
            if (wrongCount > 0) ...[
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final chapterId = provider.practiceChapterId;
                    Navigator.pop(sheetContext);
                    await provider.loadPracticeQuestions(
                      chapterId: chapterId,
                      mode: 'wrong',
                      title: '$practiceTitle · 错题巩固',
                      limit: 20,
                    );
                    if (!parentContext.mounted) return;
                    if (!provider.hasPracticeQuestions) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(content: Text('本组错题已处理，没有待复习题目')),
                      );
                    }
                  },
                  icon: const Icon(Icons.replay_circle_filled_rounded),
                  label: Text('立即复习本组错题（$wrongCount）'),
                ),
              ),
              const SizedBox(height: 9),
            ],
            SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  provider.reset();
                },
                child: const Text('完成并返回题库'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiQuestionCoach(
    BuildContext context,
    QuestionProvider provider,
  ) {
    final question = provider.currentQuestion!;
    final result = provider.lastResult!;
    final aiResult =
        _questionCoachQuestionId == question.id ? _questionCoachResult : null;
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      radius: 14,
      tint: const Color(0xFF6C5CE7).withOpacity(0.07),
      borderColor: const Color(0xFF6C5CE7).withOpacity(0.16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF6C5CE7),
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI 题目教练',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      result.isCorrect
                          ? '答对也要确认判断依据，避免蒙对'
                          : '定位错因、辨析干扰项，避免重复丢分',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (aiResult?.isDemo == true)
                const _Tag('演示建议', AppTheme.textSecondary),
            ],
          ),
          if (aiResult == null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoadingQuestionCoach
                    ? null
                    : () => _generateQuestionCoach(context, provider),
                icon: _isLoadingQuestionCoach
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.psychology_alt_rounded, size: 19),
                label: Text(
                  _isLoadingQuestionCoach
                      ? '正在拆解这道题...'
                      : result.isCorrect
                          ? 'AI 验证我的思路'
                          : 'AI 帮我拆解错因',
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Text(
              aiResult.content,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                height: 1.62,
                fontSize: 14,
              ),
            ),
            if (aiResult.actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: aiResult.actions
                    .map(
                      (action) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.74),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Text(
                          action,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showAiFollowUps(context, provider),
                  icon: const Icon(Icons.forum_outlined, size: 17),
                  label: const Text('继续追问本题'),
                ),
                if (aiResult.assistantMessageId != null)
                  TextButton.icon(
                    onPressed: _isQuestionCoachCollected
                        ? null
                        : () => _collectQuestionCoach(context, aiResult),
                    icon: Icon(
                      _isQuestionCoachCollected
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 17,
                    ),
                    label: Text(
                      _isQuestionCoachCollected ? '已加入学习档案' : '加入学习档案',
                    ),
                  ),
                if (aiResult.assistantMessageId != null)
                  TextButton.icon(
                    onPressed: () => _generateKnowledgeCardFromResult(
                      context,
                      aiResult,
                      titleHint:
                          question.tags.isEmpty ? null : question.tags.first,
                    ),
                    icon: const Icon(Icons.add_card_rounded, size: 17),
                    label: const Text('制成记忆卡'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isEvaluatingReasoning
                  ? null
                  : () => _showReasoningCoach(context, provider),
              icon: const Icon(Icons.record_voice_over_rounded, size: 18),
              label: Text(
                _reasoningQuestionId == question.id &&
                        _reasoningEvaluation != null
                    ? '复述评测 ${_reasoningEvaluation!.score} 分 · 再讲一遍'
                    : 'AI 检查我的复述',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showReasoningCoach(
    BuildContext context,
    QuestionProvider provider,
  ) async {
    final question = provider.currentQuestion;
    final result = provider.lastResult;
    if (question == null || result == null) return;
    final controller = TextEditingController();
    var evaluation =
        _reasoningQuestionId == question.id ? _reasoningEvaluation : null;
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.82,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.record_voice_over_rounded,
                          color: Color(0xFF6C5CE7),
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'AI 费曼复述',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      '不要照抄解析。请用自己的话说明：题干哪个信息最关键、为什么选这个答案、其他选项为什么不合适。',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        question.content,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (evaluation == null) ...[
                      TextField(
                        controller: controller,
                        minLines: 4,
                        maxLines: 7,
                        maxLength: 1000,
                        autofocus: false,
                        decoration: const InputDecoration(
                          labelText: '我的复述',
                          hintText: '例如：题干中的……提示……，所以应选……；B 选项不合适是因为……',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final reasoning = controller.text.trim();
                                  if (reasoning.length < 2) {
                                    ScaffoldMessenger.of(sheetContext)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text('请先写下你的判断过程'),
                                      ),
                                    );
                                    return;
                                  }
                                  setSheetState(() => isSubmitting = true);
                                  if (mounted) {
                                    setState(
                                      () => _isEvaluatingReasoning = true,
                                    );
                                  }
                                  final ai =
                                      sheetContext.read<AIChatProvider>();
                                  final response = await ai.evaluateReasoning(
                                    questionId: question.id,
                                    examCategory: provider.examCategory,
                                    questionContent: question.content,
                                    correctAnswer: result.correctAnswer,
                                    selectedAnswer: result.selectedAnswer,
                                    referenceExplanation: result.explanation,
                                    learnerReasoning: reasoning,
                                    isCorrect: result.isCorrect,
                                    tags: question.tags,
                                  );
                                  if (!sheetContext.mounted) return;
                                  setSheetState(() {
                                    isSubmitting = false;
                                    evaluation = response;
                                  });
                                  if (mounted) {
                                    setState(() {
                                      _isEvaluatingReasoning = false;
                                      _reasoningQuestionId = question.id;
                                      _reasoningEvaluation = response;
                                    });
                                  }
                                  context.read<StudyProvider>().loadTodayStats(
                                        examCategory: provider.examCategory,
                                      );
                                  if (response == null) {
                                    ScaffoldMessenger.of(sheetContext)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ai.error ?? 'AI 复述评测失败，请稍后重试',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.psychology_alt_rounded),
                          label: Text(
                            isSubmitting ? 'AI 正在检查理解...' : '提交给 AI 评测',
                          ),
                        ),
                      ),
                    ] else ...[
                      _ReasoningEvaluationPanel(evaluation: evaluation!),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                controller.clear();
                                setSheetState(() => evaluation = null);
                              },
                              icon: const Icon(Icons.replay_rounded),
                              label: const Text('重新复述'),
                            ),
                          ),
                          if (evaluation!.assistantMessageId != null) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _generateKnowledgeCardFromReasoning(
                                  sheetContext,
                                  evaluation!,
                                  question.tags.isEmpty
                                      ? '本题推理'
                                      : question.tags.first,
                                ),
                                icon: const Icon(Icons.add_card_rounded),
                                label: const Text('制成记忆卡'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
    if (mounted && _isEvaluatingReasoning) {
      setState(() => _isEvaluatingReasoning = false);
    }
  }

  Future<void> _generateKnowledgeCardFromReasoning(
    BuildContext context,
    AIReasoningEvaluation evaluation,
    String titleHint,
  ) async {
    final messageId = evaluation.assistantMessageId;
    if (messageId == null) return;
    final provider = context.read<AIChatProvider>();
    final card = await provider.generateKnowledgeCard(
      sourceMessageId: messageId,
      examCategory: context.read<QuestionProvider>().examCategory,
      titleHint: titleHint,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          card == null
              ? provider.error ?? 'AI 记忆卡生成失败'
              : '已生成「${card.title}」，稍后会按遗忘曲线提醒复习',
        ),
      ),
    );
  }

  Future<void> _generateQuestionCoach(
    BuildContext context,
    QuestionProvider provider,
  ) async {
    if (_isLoadingQuestionCoach) return;
    final question = provider.currentQuestion;
    final result = provider.lastResult;
    if (question == null || result == null) return;
    setState(() {
      _isLoadingQuestionCoach = true;
      _questionCoachQuestionId = question.id;
      _questionCoachResult = null;
      _isQuestionCoachCollected = false;
    });
    final ai = context.read<AIChatProvider>();
    final response = await ai.explainWrongQuestion(
      questionId: question.id,
      examCategory: provider.examCategory,
      questionContent: question.content,
      questionOptions: question.options,
      correctAnswer: result.correctAnswer,
      selectedAnswer: result.selectedAnswer,
      explanation: result.explanation,
      tags: question.tags,
    );
    if (!context.mounted || _questionCoachQuestionId != question.id) return;
    setState(() {
      _isLoadingQuestionCoach = false;
      _questionCoachResult = response;
    });
    context.read<StudyProvider>().loadTodayStats(
          examCategory: provider.examCategory,
        );
    if (response == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ai.error ?? 'AI 题目讲解生成失败，请稍后再试')),
      );
    }
  }

  Future<void> _collectQuestionCoach(
    BuildContext context,
    AITextResult result,
  ) async {
    final messageId = result.assistantMessageId;
    if (messageId == null) return;
    final examCategory = context.read<QuestionProvider>().examCategory;
    final collected = await context
        .read<AIChatProvider>()
        .collectMessage(messageId, examCategory: examCategory);
    if (!context.mounted || collected == null) return;
    setState(() => _isQuestionCoachCollected = collected);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(collected ? '已加入 AI 学习档案' : '已取消收藏')),
    );
  }

  Future<void> _generateKnowledgeCardFromResult(
    BuildContext context,
    AITextResult result, {
    String? titleHint,
  }) async {
    final messageId = result.assistantMessageId;
    if (messageId == null) return;
    final provider = context.read<AIChatProvider>();
    final card = await provider.generateKnowledgeCard(
      sourceMessageId: messageId,
      examCategory: context.read<QuestionProvider>().examCategory,
      titleHint: titleHint,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          card == null
              ? provider.error ?? 'AI 记忆卡生成失败'
              : '已生成「${card.title}」，可在 AI 学习档案中复习',
        ),
      ),
    );
  }

  void _showAiFollowUps(
    BuildContext context,
    QuestionProvider provider,
  ) {
    final question = provider.currentQuestion;
    final result = provider.lastResult;
    if (question == null || result == null) return;
    final prompts = <(IconData, String, String)>[
      (
        Icons.compare_arrows_rounded,
        '辨析干扰项',
        '请逐个解释这道题的其他选项为什么不合适，并总结最容易混淆的判断边界。',
      ),
      (
        Icons.memory_rounded,
        '生成记忆口诀',
        '请把这道题的核心考点整理成简短、准确的记忆口诀，并说明口诀的适用边界。',
      ),
      (
        Icons.change_circle_outlined,
        '生成变式训练',
        '请围绕这道题的核心考点生成一道新的变式单选题。先只出题和选项，等我作答后再公布答案。',
      ),
    ];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '想继续怎么问？',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'AI 会携带本题上下文开启一次独立对话。',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              ...prompts.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF6C5CE7).withOpacity(0.1),
                    child: Icon(item.$1, color: const Color(0xFF6C5CE7)),
                  ),
                  title: Text(
                    item.$2,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openQuestionAiChat(context, question, result, item.$3);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openQuestionAiChat(
    BuildContext context,
    dynamic question,
    dynamic result,
    String request,
  ) {
    final options = question.options.entries
        .map((entry) => '${entry.key}. ${entry.value}')
        .join('\n');
    final prompt = '''$request

题干：${question.content}
选项：
$options
我的答案：${result.selectedAnswer}
正确答案：${result.correctAnswer}
已有解析：${result.explanation ?? '暂无'}''';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AIChatScreen(
          initialPrompt: prompt,
          relatedQuestionId: question.id,
          autoSend: true,
        ),
      ),
    );
  }
}

class _ReasoningEvaluationPanel extends StatelessWidget {
  final AIReasoningEvaluation evaluation;

  const _ReasoningEvaluationPanel({required this.evaluation});

  @override
  Widget build(BuildContext context) {
    final scoreColor = evaluation.score >= 80
        ? AppTheme.success
        : evaluation.score >= 60
            ? Colors.orange
            : AppTheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scoreColor.withOpacity(0.13),
                const Color(0xFF6C5CE7).withOpacity(0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scoreColor.withOpacity(0.22)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.86),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${evaluation.score}',
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          evaluation.masteryLabel,
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        if (evaluation.isDemo) ...[
                          const SizedBox(width: 8),
                          const _Tag('演示评测', AppTheme.textSecondary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      evaluation.verdict,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ReasoningFeedbackBlock(
          icon: Icons.check_circle_outline_rounded,
          title: '已经讲清楚',
          color: AppTheme.success,
          items: evaluation.strengths,
        ),
        const SizedBox(height: 10),
        _ReasoningFeedbackBlock(
          icon: Icons.search_rounded,
          title: '还需补齐',
          color: Colors.orange,
          items: evaluation.gaps,
        ),
        const SizedBox(height: 10),
        _ReasoningFeedbackBlock(
          icon: Icons.help_outline_rounded,
          title: '继续追问自己',
          color: const Color(0xFF6C5CE7),
          items: evaluation.coachingQuestions,
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '参考推理链',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                evaluation.modelReasoning,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.arrow_circle_right_outlined,
              color: AppTheme.primary,
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                evaluation.nextAction,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReasoningFeedbackBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<String> items;

  const _ReasoningFeedbackBlock({
    required this.icon,
    required this.title,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '• $item',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  height: 1.45,
                ),
              ),
            ),
          ),
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

class _PracticeReviewMetric extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _PracticeReviewMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.13)),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      tint: Colors.white.withOpacity(0.78),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
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

class _AdaptiveFeatureChip extends StatelessWidget {
  final String label;

  const _AdaptiveFeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withOpacity(0.16),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6C5CE7),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
