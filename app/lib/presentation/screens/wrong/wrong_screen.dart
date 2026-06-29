import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/providers/study_provider.dart';
import '../../../core/theme/app_theme.dart';

class WrongScreen extends StatefulWidget {
  const WrongScreen({super.key});

  @override
  State<WrongScreen> createState() => _WrongScreenState();
}

class _WrongScreenState extends State<WrongScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudyProvider>().loadWrongQuestions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('错题本')),
      body: Consumer<StudyProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final wrongs = provider.wrongQuestions;

          if (wrongs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 80,
                      color: AppTheme.success.withOpacity(0.5)),
                  const SizedBox(height: 24),
                  const Text('太棒了！',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  const Text('暂无错题记录',
                      style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('继续练习'),
                  ),
                ],
              ),
            );
          }

          // 错因统计
          final reasonCount = <String, int>{};
          for (final w in wrongs) {
            final r = w.wrongReason ?? '未分类';
            reasonCount[r] = (reasonCount[r] ?? 0) + 1;
          }

          final mastered = wrongs.where((w) => w.isMastered).length;

          return CustomScrollView(
            slivers: [
              // 统计
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.error.withOpacity(0.08),
                        AppTheme.primary.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatBox(
                          label: '错题总数',
                          value: '${wrongs.length}',
                          color: AppTheme.error),
                      _StatBox(
                          label: '已掌握',
                          value: '$mastered',
                          color: AppTheme.success),
                      _StatBox(
                          label: '待复习',
                          value: '${wrongs.length - mastered}',
                          color: AppTheme.accent),
                    ],
                  ),
                ),
              ),
              // 错因分析
              if (reasonCount.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('错因分析',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          const SizedBox(height: 12),
                          ...reasonCount.entries.map((e) {
                            final pct =
                                (e.value / wrongs.length * 100).toInt();
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 64,
                                    child: Text(e.key,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color:
                                                AppTheme.textSecondary)),
                                  ),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: pct / 100.0,
                                        minHeight: 8,
                                        backgroundColor:
                                            AppTheme.divider,
                                        valueColor:
                                            AlwaysStoppedAnimation(
                                                _getReasonColor(
                                                    e.key)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('$pct%',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              // 错题列表
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final w = wrongs[index];
                      return GestureDetector(
                        onTap: () =>
                            _showWrongDetail(context, w),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: AppTheme.divider),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: w.isMastered
                                      ? AppTheme.success
                                          .withOpacity(0.1)
                                      : AppTheme.error
                                          .withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  w.isMastered
                                      ? Icons.check_circle_rounded
                                      : Icons.close_rounded,
                                  color: w.isMastered
                                      ? AppTheme.success
                                      : AppTheme.error,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('错题 #${w.questionId}',
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.w600,
                                            color:
                                                AppTheme.textPrimary)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (w.wrongReason != null) ...[
                                          Container(
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                            decoration: BoxDecoration(
                                              color: _getReasonColor(
                                                      w.wrongReason!)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(4),
                                            ),
                                            child: Text(
                                                w.wrongReason!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      _getReasonColor(
                                                          w.wrongReason!),
                                                  fontWeight:
                                                      FontWeight.w500,
                                                )),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Icon(Icons.refresh_rounded,
                                            size: 14,
                                            color: AppTheme.textHint),
                                        const SizedBox(width: 2),
                                        Text('${w.reviewCount} 次',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme
                                                    .textSecondary)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (w.isMastered)
                                const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.success,
                                    size: 22)
                              else
                                const Icon(Icons.chevron_right,
                                    color: AppTheme.textHint,
                                    size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: wrongs.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getReasonColor(String reason) {
    switch (reason) {
      case '粗心大意':
        return Colors.orange;
      case '概念不清':
        return AppTheme.error;
      case '记忆模糊':
        return Colors.purple;
      case '理解偏差':
        return Colors.blue;
      default:
        return AppTheme.textSecondary;
    }
  }

  void _showWrongDetail(BuildContext context, dynamic wrong) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          minChildSize: 0.35,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: scrollController,
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
                  const Text('错题详情',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  _DetailRow(
                      label: '题目 ID', value: '${wrong.questionId}'),
                  _DetailRow(
                      label: '错因',
                      value: wrong.wrongReason ?? '未分类'),
                  _DetailRow(
                      label: '复习次数',
                      value: '${wrong.reviewCount} 次'),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                      child: const Text('开始复习'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}
