import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/conversation.dart';
import '../../../data/providers/ai_chat_provider.dart';
import '../../../data/providers/question_provider.dart';
import '../../../data/providers/study_provider.dart';
import '../../../core/theme/app_theme.dart';

class AIChatScreen extends StatefulWidget {
  final String? initialPrompt;
  final int? relatedQuestionId;
  final bool autoSend;

  const AIChatScreen({
    super.key,
    this.initialPrompt,
    this.relatedQuestionId,
    this.autoSend = false,
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AIChatProvider>();
      final examCategory = context.read<QuestionProvider>().examCategory;
      final initialPrompt = widget.initialPrompt?.trim();
      if (initialPrompt != null && initialPrompt.isNotEmpty) {
        provider.startNewSession();
        _controller.text = initialPrompt;
      } else {
        provider.ensureFreshVisibleSession();
      }
      provider.loadSessions(examCategory: examCategory);
      provider.loadCollections(examCategory: examCategory);
      provider.loadKnowledgeCards(examCategory: examCategory);
      if (widget.autoSend &&
          initialPrompt != null &&
          initialPrompt.isNotEmpty) {
        _sendMessage();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final provider = context.read<AIChatProvider>();
    if (provider.isSending) return;
    _controller.clear();
    _scrollToBottom();
    final examCategory = context.read<QuestionProvider>().examCategory;
    final answer = await provider.sendMessage(
      text,
      examCategory: examCategory,
      relatedQuestionId: widget.relatedQuestionId,
    );
    if (mounted) {
      context.read<StudyProvider>().loadTodayStats(examCategory: examCategory);
      if (answer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? '发送消息失败，请稍后重试')),
        );
      }
    }
    _scrollToBottom();
  }

  Future<void> _sendSuggestion(String text) async {
    if (context.read<AIChatProvider>().isSending) return;
    _controller.text = text;
    await _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 答疑'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => _showHistoryDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () {
              context.read<AIChatProvider>().startNewSession();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<AIChatProvider>(
              builder: (context, provider, _) {
                if (provider.messages.isEmpty) return _buildEmptyState();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount:
                      provider.messages.length + (provider.isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= provider.messages.length) {
                      return const _TypingBubble();
                    }
                    final msg = provider.messages[index];
                    final hasKnowledgeCard = msg.id != null &&
                        provider.knowledgeCards.any(
                          (card) => card.sourceMessageId == msg.id,
                        );
                    return _MessageBubble(
                      message: msg.content,
                      isUser: msg.isUser,
                      isCollected: msg.isCollected,
                      onCollect: msg.id != null
                          ? () => _collectMessage(provider, msg.id!)
                          : null,
                      hasKnowledgeCard: hasKnowledgeCard,
                      isGeneratingKnowledgeCard:
                          provider.isGeneratingKnowledgeCard,
                      onCreateKnowledgeCard: msg.isAssistant && msg.id != null
                          ? () => _generateKnowledgeCard(provider, msg.id!)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final examCategory = context.watch<QuestionProvider>().examCategory;
    final todayStats = context.watch<StudyProvider>().todayStats;
    final totalQuestions = todayStats?.totalQuestions ?? 0;
    final accuracy = ((todayStats?.accuracyRate ?? 0) * 100).round();
    final hasTodayData = totalQuestions > 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('AI 医学答疑助手',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(
              hasTodayData
                  ? '当前：$examCategory · 今日已做 $totalQuestions 题 · 正确率 $accuracy%'
                  : '当前：$examCategory · 可以从今日计划、错题复盘或考点答疑开始',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(
                  label: '复盘今日学习',
                  onTap: () => _sendSuggestion(
                    hasTodayData
                        ? '请根据我今天在$examCategory的学习数据：已做$totalQuestions题、正确率$accuracy%，帮我复盘今天的薄弱点，并给出下一步学习安排。'
                        : '我正在备考$examCategory，请帮我安排今天的学习任务和刷题顺序。',
                  ),
                ),
                _SuggestionChip(
                  label: '讲一个高频考点',
                  onTap: () => _sendSuggestion(
                    '请结合$examCategory考试，讲一个最容易丢分的高频考点，按“考点总结-易错点-记忆口诀-练习建议”回答。',
                  ),
                ),
                _SuggestionChip(
                  label: '制定 7 天计划',
                  onTap: () => _sendSuggestion(
                    '请为$examCategory制定一个 7 天冲刺学习计划，每天包含课程、刷题、错题复盘和模考安排。',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: '输入医学问题...',
                    border: InputBorder.none,
                    hintStyle:
                        TextStyle(color: AppTheme.textHint, fontSize: 15),
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryLight]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                onPressed: context.watch<AIChatProvider>().isSending
                    ? null
                    : _sendMessage,
                icon: context.watch<AIChatProvider>().isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistoryDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<AIChatProvider>(
          builder: (context, provider, _) {
            return DefaultTabController(
              length: 3,
              child: DraggableScrollableSheet(
                initialChildSize: 0.62,
                maxChildSize: 0.9,
                minChildSize: 0.35,
                expand: false,
                builder: (context, scrollController) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.divider,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('AI 学习档案',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                            IconButton(
                              tooltip: '刷新',
                              onPressed: () {
                                final examCategory = context
                                    .read<QuestionProvider>()
                                    .examCategory;
                                provider.loadSessions(
                                    examCategory: examCategory);
                                provider.loadCollections(
                                    examCategory: examCategory);
                                provider.loadKnowledgeCards(
                                    examCategory: examCategory);
                              },
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const TabBar(
                            indicatorSize: TabBarIndicatorSize.tab,
                            tabs: [
                              Tab(text: '会话'),
                              Tab(text: '收藏'),
                              Tab(text: '记忆卡'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _SessionList(
                                sessions: provider.sessions,
                                onSelect: (sessionId) {
                                  provider.selectSession(sessionId);
                                  Navigator.pop(ctx);
                                },
                              ),
                              _CollectionList(
                                collections: provider.collections,
                                onSelect: (message) {
                                  provider.selectSession(message.sessionId);
                                  Navigator.pop(ctx);
                                },
                              ),
                              _KnowledgeCardList(
                                cards: provider.knowledgeCards,
                                dueCount: provider.dueKnowledgeCardCount,
                                onReview: (card) =>
                                    _showKnowledgeCardReview(context, card),
                                onDelete: (card) =>
                                    _deleteKnowledgeCard(context, card),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _collectMessage(AIChatProvider provider, int messageId) async {
    final examCategory = context.read<QuestionProvider>().examCategory;
    final isCollected = await provider.collectMessage(
      messageId,
      examCategory: examCategory,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCollected == null
              ? provider.error ?? '收藏失败'
              : isCollected
                  ? '已加入 AI 学习档案'
                  : '已取消收藏',
        ),
      ),
    );
  }

  Future<void> _generateKnowledgeCard(
    AIChatProvider provider,
    int messageId,
  ) async {
    final examCategory = context.read<QuestionProvider>().examCategory;
    final card = await provider.generateKnowledgeCard(
      sourceMessageId: messageId,
      examCategory: examCategory,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          card == null
              ? provider.error ?? 'AI 记忆卡生成失败'
              : '已生成「${card.title}」，可在学习档案中复习',
        ),
      ),
    );
  }

  Future<void> _showKnowledgeCardReview(
    BuildContext context,
    AIKnowledgeCard card,
  ) async {
    var revealed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.style_rounded,
                      color: Color(0xFF6C5CE7),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${card.masteryLabel} · 已复习 ${card.reviewCount} 次',
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
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.14)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '先回忆',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      card.front,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        height: 1.55,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (!revealed)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => setSheetState(() => revealed = true),
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('想好后查看答案'),
                  ),
                )
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: AppTheme.success.withOpacity(0.14)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '答案与判断依据',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        card.back,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          height: 1.6,
                        ),
                      ),
                      if (card.mnemonic?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        Text(
                          '记忆提示：${card.mnemonic}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '这次回忆得怎么样？',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _MemoryRatingButton(
                      label: '忘记了',
                      color: AppTheme.error,
                      onTap: () => _reviewKnowledgeCard(
                        sheetContext,
                        card,
                        'again',
                      ),
                    ),
                    const SizedBox(width: 7),
                    _MemoryRatingButton(
                      label: '有点难',
                      color: AppTheme.accent,
                      onTap: () => _reviewKnowledgeCard(
                        sheetContext,
                        card,
                        'hard',
                      ),
                    ),
                    const SizedBox(width: 7),
                    _MemoryRatingButton(
                      label: '记住了',
                      color: AppTheme.primary,
                      onTap: () => _reviewKnowledgeCard(
                        sheetContext,
                        card,
                        'good',
                      ),
                    ),
                    const SizedBox(width: 7),
                    _MemoryRatingButton(
                      label: '很熟练',
                      color: AppTheme.success,
                      onTap: () => _reviewKnowledgeCard(
                        sheetContext,
                        card,
                        'easy',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reviewKnowledgeCard(
    BuildContext sheetContext,
    AIKnowledgeCard card,
    String rating,
  ) async {
    final examCategory = context.read<QuestionProvider>().examCategory;
    final provider = context.read<AIChatProvider>();
    final success = await provider.reviewKnowledgeCard(
      cardId: card.id,
      rating: rating,
      examCategory: examCategory,
    );
    if (!mounted) return;
    if (sheetContext.mounted) Navigator.pop(sheetContext);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '已安排下一次复习' : provider.error ?? '复习记录失败',
        ),
      ),
    );
  }

  Future<void> _deleteKnowledgeCard(
    BuildContext context,
    AIKnowledgeCard card,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除记忆卡？'),
            content: Text('“${card.title}”的复习记录也会一并删除。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final provider = this.context.read<AIChatProvider>();
    final success = await provider.deleteKnowledgeCard(card.id);
    if (!mounted) return;
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(content: Text(success ? '记忆卡已删除' : provider.error ?? '删除失败')),
    );
  }
}

class _SessionList extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final ValueChanged<String> onSelect;

  const _SessionList({
    required this.sessions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Center(
        child: Text('暂无对话记录', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.separated(
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final s = sessions[index];
        final title = (s['title'] ?? '新对话').toString();
        final collectedCount = s['collected_count'] ?? 0;
        final examCategory = (s['exam_category'] ?? '').toString();
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _HistoryIcon(
            icon: Icons.chat_rounded,
            color: AppTheme.primary,
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${examCategory.isNotEmpty ? '$examCategory · ' : ''}'
            '${s['message_count'] ?? 0} 条消息'
            '${collectedCount > 0 ? ' · 收藏 $collectedCount 条' : ''}'
            '${_formatSessionTime(s['last_message_at'])}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right,
              color: AppTheme.textHint, size: 20),
          onTap: () => onSelect(s['session_id'].toString()),
        );
      },
    );
  }
}

class _CollectionList extends StatelessWidget {
  final List<ConversationMessage> collections;
  final ValueChanged<ConversationMessage> onSelect;

  const _CollectionList({
    required this.collections,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return const Center(
        child: Text('暂无收藏内容，收藏 AI 回复后会出现在这里。',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.separated(
      itemCount: collections.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final message = collections[index];
        final examCategory = message.examCategory;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _HistoryIcon(
            icon: Icons.bookmark_rounded,
            color: AppTheme.accent,
          ),
          title: Text(
            _readableAiMessage(message.content),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${examCategory != null && examCategory.isNotEmpty ? '$examCategory · ' : ''}'
            '来自会话 ${_shortSession(message.sessionId)}${_formatDate(message.createdAt)}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right,
              color: AppTheme.textHint, size: 20),
          onTap: () => onSelect(message),
        );
      },
    );
  }
}

class _KnowledgeCardList extends StatelessWidget {
  final List<AIKnowledgeCard> cards;
  final int dueCount;
  final ValueChanged<AIKnowledgeCard> onReview;
  final ValueChanged<AIKnowledgeCard> onDelete;

  const _KnowledgeCardList({
    required this.cards,
    required this.dueCount,
    required this.onReview,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            '暂无记忆卡。在 AI 回复下点击“制成记忆卡”，即可开始主动回忆和间隔复习。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: cards.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.07),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: Color(0xFF6C5CE7), size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dueCount > 0
                        ? '今天有 $dueCount 张记忆卡待复习，建议先完成再刷题。'
                        : '今天的记忆卡已复习完成。',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final card = cards[index - 1];
        return Material(
          color: card.isDue ? AppTheme.primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onReview(card),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.style_rounded,
                        color: Color(0xFF6C5CE7), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          card.front,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${card.masteryLabel} · ${card.nextReviewLabel}',
                          style: TextStyle(
                            color: card.isDue
                                ? AppTheme.primary
                                : AppTheme.textHint,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '删除记忆卡',
                    onPressed: () => onDelete(card),
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.textHint, size: 19),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MemoryRatingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MemoryRatingButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.36)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _HistoryIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _HistoryIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

String _shortSession(String sessionId) {
  if (sessionId.length <= 8) return sessionId;
  return sessionId.substring(0, 8);
}

String _formatDate(DateTime? time) {
  if (time == null) return '';
  return ' · ${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

String _formatSessionTime(dynamic raw) {
  if (raw == null) return '';
  try {
    return _formatDate(DateTime.parse(raw.toString()));
  } catch (_) {
    return '';
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isCollected;
  final VoidCallback? onCollect;
  final VoidCallback? onCreateKnowledgeCard;
  final bool hasKnowledgeCard;
  final bool isGeneratingKnowledgeCard;

  const _MessageBubble({
    required this.message,
    required this.isUser,
    this.isCollected = false,
    this.onCollect,
    this.onCreateKnowledgeCard,
    this.hasKnowledgeCard = false,
    this.isGeneratingKnowledgeCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final assistantWidth = math.min(screenWidth * 0.78, 860.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: isUser ? null : assistantWidth,
          constraints: BoxConstraints(
            maxWidth: screenWidth * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            boxShadow: AppTheme.cardShadow,
            border: isUser ? null : Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUser ? message : _readableAiMessage(message),
                style: TextStyle(
                  color: isUser ? Colors.white : AppTheme.textPrimary,
                  height: 1.5,
                  fontSize: 15,
                ),
              ),
              if (!isUser &&
                  (onCollect != null || onCreateKnowledgeCard != null)) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (onCollect != null)
                      _InlineAiAction(
                        icon: isCollected
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        label: isCollected ? '已收藏' : '收藏',
                        active: isCollected,
                        onTap: onCollect!,
                      ),
                    if (onCreateKnowledgeCard != null)
                      _InlineAiAction(
                        icon: hasKnowledgeCard
                            ? Icons.style_rounded
                            : Icons.add_card_rounded,
                        label: hasKnowledgeCard
                            ? '已制卡'
                            : isGeneratingKnowledgeCard
                                ? '制卡中...'
                                : '制成记忆卡',
                        active: hasKnowledgeCard,
                        onTap: hasKnowledgeCard || isGeneratingKnowledgeCard
                            ? null
                            : onCreateKnowledgeCard!,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineAiAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _InlineAiAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? AppTheme.primary : AppTheme.textHint,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? AppTheme.primary : AppTheme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _readableAiMessage(String raw) {
  final withoutCodeBlocks =
      raw.replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), '');
  return withoutCodeBlocks
      .split('\n')
      .map((line) {
        final trimmed = line.trimRight();
        if (RegExp(r'^\s*`{3,}').hasMatch(trimmed)) {
          return '';
        }
        if (trimmed.trim().startsWith('|')) {
          return trimmed
              .replaceAll('|', '  ')
              .replaceAll(RegExp(r'\s{2,}'), ' ')
              .trim();
        }
        return trimmed
            .replaceAllMapped(
              RegExp(r'\[([^\]]+)\]\([^)]+\)'),
              (match) => match.group(1) ?? '',
            )
            .replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '')
            .replaceAllMapped(
              RegExp(r'\*\*([^*]+)\*\*'),
              (match) => match.group(1) ?? '',
            )
            .replaceAllMapped(
              RegExp(r'__([^_]+)__'),
              (match) => match.group(1) ?? '',
            )
            .replaceAllMapped(
              RegExp(r'`([^`]+)`'),
              (match) => match.group(1) ?? '',
            )
            .replaceAll('**', '')
            .replaceAll('__', '')
            .replaceAll('`', '')
            .replaceAllMapped(
              RegExp(r'(^|\s)\*([^*]+)\*(?=\s|$|，|。|：|；)'),
              (match) => '${match.group(1) ?? ''}${match.group(2) ?? ''}',
            )
            .replaceFirst(RegExp(r'^\s*[-*]\s+'), '• ')
            .replaceAll('*', '')
            .replaceFirst(RegExp(r'^\s*>\s?'), '')
            .trimRight();
      })
      .where((line) =>
          line.trim().isNotEmpty && !RegExp(r'^[-\s]+$').hasMatch(line))
      .join('\n');
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
            border: Border.fromBorderSide(BorderSide(color: AppTheme.divider)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'AI 正在思考…',
              style: TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}
