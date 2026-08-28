import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/conversation.dart';
import '../../../data/providers/ai_chat_provider.dart';
import '../../widgets/app_glass.dart';

class AICaseScreen extends StatefulWidget {
  final String examCategory;
  final String? initialTopic;
  final int? chapterId;

  const AICaseScreen({
    super.key,
    required this.examCategory,
    this.initialTopic,
    this.chapterId,
  });

  @override
  State<AICaseScreen> createState() => _AICaseScreenState();
}

class _AICaseScreenState extends State<AICaseScreen> {
  late final TextEditingController _topicController;
  int _difficulty = 2;
  bool _isGenerating = false;
  bool _isReviewing = false;
  bool _hintVisible = false;
  int _currentStageIndex = 0;
  AICaseSimulation? _simulation;
  AICaseReview? _review;
  final Map<int, String> _answers = {};

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.initialTopic ?? '');
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: AppBar(
        title: const Text('AI 临床病例推演'),
        actions: [
          if (_simulation != null)
            IconButton(
              tooltip: '重新生成病例',
              onPressed: _isGenerating || _isReviewing ? null : _reset,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: _review != null
            ? _buildReview(_review!)
            : _simulation != null
                ? _buildSimulation(_simulation!)
                : _buildStart(),
      ),
    );
  }

  Widget _buildStart() {
    const purple = Color(0xFF6C5CE7);
    return SingleChildScrollView(
      key: const ValueKey('case-start'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            tint: purple.withOpacity(0.08),
            borderColor: purple.withOpacity(0.18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: purple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.medical_information_outlined,
                    color: purple,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '把知识放进病例里练',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'AI 分三步释放病例信息。你需要先提取证据、再形成诊断或辨证判断，最后完成鉴别与处置。每一步都会即时纠偏。',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _InfoPill(Icons.search_rounded, '信息提取'),
                    _InfoPill(Icons.account_tree_outlined, '推理链'),
                    _InfoPill(Icons.fact_check_outlined, '即时纠偏'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '当前考试：${widget.examCategory}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _topicController,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: '想练的主题（可不填）',
              hintText: '例如：方剂学、内科学、鉴别诊断',
              prefixIcon: Icon(Icons.topic_outlined),
              counterText: '',
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '推演难度',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _DifficultyButton(
                label: '基础',
                subtitle: '抓关键词',
                selected: _difficulty == 1,
                onTap: () => setState(() => _difficulty = 1),
              ),
              const SizedBox(width: 10),
              _DifficultyButton(
                label: '进阶',
                subtitle: '完整判断',
                selected: _difficulty == 2,
                onTap: () => setState(() => _difficulty = 2),
              ),
              const SizedBox(width: 10),
              _DifficultyButton(
                label: '挑战',
                subtitle: '易混辨析',
                selected: _difficulty == 3,
                onTap: () => setState(() => _difficulty = 3),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateCase,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_isGenerating ? 'AI 正在构建病例...' : '生成病例推演'),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              '病例内容仅用于考试学习，不替代真实临床诊疗。',
              style: TextStyle(
                color: AppTheme.textHint,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateCase() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    final ai = context.read<AIChatProvider>();
    final simulation = await ai.generateCaseSimulation(
      examCategory: widget.examCategory,
      topic: _topicController.text.trim(),
      difficulty: _difficulty,
      chapterId: widget.chapterId,
    );
    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _simulation = simulation;
      _currentStageIndex = 0;
      _answers.clear();
      _review = null;
      _hintVisible = false;
    });
    if (simulation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ai.error ?? '病例生成失败，请稍后再试')),
      );
    }
  }

  Widget _buildSimulation(AICaseSimulation simulation) {
    final stage = simulation.stages[_currentStageIndex];
    final selectedAnswer = _answers[stage.index];
    final answered = selectedAnswer != null;
    final isCorrect = selectedAnswer == stage.bestAnswer;
    return Column(
      key: ValueKey('case-stage-${stage.index}'),
      children: [
        GlassPanel(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value:
                            (_currentStageIndex + 1) / simulation.stages.length,
                        backgroundColor: AppTheme.divider,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_currentStageIndex + 1}/${simulation.stages.length}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        simulation.title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (simulation.isDemo)
                      const _CaseTag('题库演示', AppTheme.textSecondary),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: simulation.learningObjectives
                      .map((item) => _CaseTag(item, AppTheme.primary))
                      .toList(),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  tint: Colors.white.withOpacity(0.78),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            color: AppTheme.primary,
                            size: 19,
                          ),
                          SizedBox(width: 7),
                          Text(
                            '病例背景',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        simulation.patientProfile,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  stage.title,
                  style: const TextStyle(
                    color: Color(0xFF6C5CE7),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  stage.scenario,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  stage.prompt,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                ...stage.options.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CaseOption(
                      optionKey: entry.key,
                      text: entry.value,
                      selected: selectedAnswer == entry.key,
                      correct: answered && entry.key == stage.bestAnswer,
                      incorrect: answered &&
                          selectedAnswer == entry.key &&
                          entry.key != stage.bestAnswer,
                      onTap: answered
                          ? null
                          : () => setState(() {
                                _answers[stage.index] = entry.key;
                                _hintVisible = false;
                              }),
                    ),
                  ),
                ),
                if (!answered) ...[
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _hintVisible = !_hintVisible),
                    icon: const Icon(Icons.lightbulb_outline_rounded),
                    label: Text(_hintVisible ? '收起 AI 提示' : '需要一个 AI 提示'),
                  ),
                  if (_hintVisible)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        stage.hint,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                ],
                if (answered) ...[
                  const SizedBox(height: 6),
                  _StageFeedback(
                    isCorrect: isCorrect,
                    explanation: stage.explanation,
                    knowledgePoint: stage.knowledgePoint,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isReviewing ? null : _nextStage,
                      icon: _isReviewing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _currentStageIndex == simulation.stages.length - 1
                                  ? Icons.auto_graph_rounded
                                  : Icons.arrow_forward_rounded,
                            ),
                      label: Text(
                        _isReviewing
                            ? 'AI 正在复盘推理链...'
                            : _currentStageIndex == simulation.stages.length - 1
                                ? '生成 AI 病例复盘'
                                : '进入下一阶段',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _nextStage() async {
    final simulation = _simulation;
    if (simulation == null) return;
    if (_currentStageIndex < simulation.stages.length - 1) {
      setState(() {
        _currentStageIndex += 1;
        _hintVisible = false;
      });
      return;
    }
    setState(() => _isReviewing = true);
    final ai = context.read<AIChatProvider>();
    final review = await ai.reviewCaseSimulation(
      simulation: simulation,
      answers: _answers,
    );
    if (!mounted) return;
    setState(() {
      _isReviewing = false;
      _review = review;
    });
    if (review == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ai.error ?? 'AI 病例复盘生成失败')),
      );
    }
  }

  Widget _buildReview(AICaseReview review) {
    final scoreColor = review.score >= 80
        ? AppTheme.success
        : review.score >= 60
            ? AppTheme.warning
            : AppTheme.error;
    return SingleChildScrollView(
      key: const ValueKey('case-review'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            tint: scoreColor.withOpacity(0.08),
            borderColor: scoreColor.withOpacity(0.2),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.86),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scoreColor.withOpacity(0.28),
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${review.score}',
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  review.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '完成 ${review.correctCount}/${review.totalStages} 个阶段',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                if (review.isDemo) ...[
                  const SizedBox(height: 8),
                  const _CaseTag('演示复盘', AppTheme.textSecondary),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI 推理表现总结',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  review.summary,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          if (review.wrongPoints.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              '需要补强',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: review.wrongPoints
                  .map((item) => _CaseTag(item, AppTheme.error))
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            '下一步训练',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          ...review.actions.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 14),
          if (review.assistantMessageId != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saveReviewAsCard,
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('把本次薄弱点制成记忆卡'),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('再来一例'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveReviewAsCard() async {
    final review = _review;
    final simulation = _simulation;
    if (review?.assistantMessageId == null || simulation == null) return;
    final ai = context.read<AIChatProvider>();
    final card = await ai.generateKnowledgeCard(
      sourceMessageId: review!.assistantMessageId!,
      examCategory: simulation.examCategory,
      titleHint: '${simulation.topic}病例推演',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          card == null
              ? ai.error ?? '记忆卡生成失败'
              : '已生成「${card.title}」，可在 AI 学习档案中复习',
        ),
      ),
    );
  }

  void _reset() {
    setState(() {
      _simulation = null;
      _review = null;
      _currentStageIndex = 0;
      _answers.clear();
      _hintVisible = false;
      _isGenerating = false;
      _isReviewing = false;
    });
  }
}

class _DifficultyButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _DifficultyButton({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withOpacity(0.1)
                : Colors.white.withOpacity(0.66),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.divider,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppTheme.primary : AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaseOption extends StatelessWidget {
  final String optionKey;
  final String text;
  final bool selected;
  final bool correct;
  final bool incorrect;
  final VoidCallback? onTap;

  const _CaseOption({
    required this.optionKey,
    required this.text,
    required this.selected,
    required this.correct,
    required this.incorrect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = correct
        ? AppTheme.success
        : incorrect
            ? AppTheme.error
            : selected
                ? AppTheme.primary
                : AppTheme.textSecondary;
    return GlassCard(
      onTap: onTap,
      width: double.infinity,
      radius: 14,
      padding: const EdgeInsets.all(15),
      tint: (correct || incorrect || selected)
          ? color.withOpacity(0.08)
          : Colors.white.withOpacity(0.74),
      borderColor:
          (correct || incorrect || selected) ? color : AppTheme.glassStroke,
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (correct || incorrect || selected)
                  ? color
                  : Colors.transparent,
              border: Border.all(color: color, width: 1.4),
            ),
            child: Center(
              child: Text(
                optionKey,
                style: TextStyle(
                  color:
                      (correct || incorrect || selected) ? Colors.white : color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                height: 1.45,
              ),
            ),
          ),
          if (correct)
            const Icon(Icons.check_circle_rounded, color: AppTheme.success),
          if (incorrect)
            const Icon(Icons.cancel_rounded, color: AppTheme.error),
        ],
      ),
    );
  }
}

class _StageFeedback extends StatelessWidget {
  final bool isCorrect;
  final String explanation;
  final String knowledgePoint;

  const _StageFeedback({
    required this.isCorrect,
    required this.explanation,
    required this.knowledgePoint,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? AppTheme.success : AppTheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect
                    ? Icons.check_circle_outline_rounded
                    : Icons.psychology_alt_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? '判断正确' : '这里需要纠偏',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              _CaseTag(knowledgePoint, color),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            explanation,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              height: 1.58,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF6C5CE7)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseTag extends StatelessWidget {
  final String label;
  final Color color;

  const _CaseTag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
