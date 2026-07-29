import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/conversation.dart';
import '../../../data/providers/ai_chat_provider.dart';
import '../../../data/providers/question_provider.dart';
import '../../../data/providers/study_provider.dart';
import '../../../core/theme/app_theme.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

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
      provider.ensureFreshVisibleSession();
      provider.loadSessions(examCategory: examCategory);
      provider.loadCollections(examCategory: examCategory);
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
                    return _MessageBubble(
                      message: msg.content,
                      isUser: msg.isUser,
                      isCollected: msg.isCollected,
                      onCollect: msg.id != null
                          ? () => _collectMessage(provider, msg.id!)
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
              length: 2,
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

  const _MessageBubble({
    required this.message,
    required this.isUser,
    this.isCollected = false,
    this.onCollect,
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
              if (!isUser && onCollect != null) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: onCollect,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCollected
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 15,
                          color: isCollected
                              ? AppTheme.primary
                              : AppTheme.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCollected ? '已收藏' : '收藏',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isCollected
                                ? AppTheme.primary
                                : AppTheme.textHint,
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
