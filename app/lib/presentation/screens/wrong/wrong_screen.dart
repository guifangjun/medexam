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
      appBar: AppBar(
        title: const Text('错题本'),
      ),
      body: Consumer<StudyProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.wrongQuestions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green[300],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '太棒了！',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '暂无错题记录',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('继续练习'),
                  ),
                ],
              ),
            );
          }

          // 按错因分组统计
          final reasonCount = <String, int>{};
          for (final wrong in provider.wrongQuestions) {
            final reason = wrong.wrongReason ?? '未分类';
            reasonCount[reason] = (reasonCount[reason] ?? 0) + 1;
          }

          return CustomScrollView(
            slivers: [
              // 统计卡片
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.errorColor.withOpacity(0.1),
                        AppTheme.primaryColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatBox(
                        label: '错题总数',
                        value: '${provider.wrongQuestions.length}',
                        color: AppTheme.errorColor,
                      ),
                      _StatBox(
                        label: '已掌握',
                        value: '${provider.wrongQuestions.where((w) => w.isMastered).length}',
                        color: AppTheme.secondaryColor,
                      ),
                      _StatBox(
                        label: '待复习',
                        value: '${provider.wrongQuestions.where((w) => !w.isMastered).length}',
                        color: AppTheme.warningColor,
                      ),
                    ],
                  ),
                ),
              ),
              // 错因分布
              if (reasonCount.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '错因分析',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...reasonCount.entries.map((e) {
                              final percentage = provider.wrongQuestions.isEmpty
                                  ? 0.0
                                  : e.value / provider.wrongQuestions.length;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(e.key),
                                        Text('${e.value} 题'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: percentage,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation(
                                        _getReasonColor(e.key),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // 错题列表
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final wrong = provider.wrongQuestions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _showWrongDetail(context, wrong),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: wrong.isMastered
                                        ? AppTheme.secondaryColor.withOpacity(0.1)
                                        : AppTheme.errorColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: wrong.isMastered
                                            ? AppTheme.secondaryColor
                                            : AppTheme.errorColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '题目 #${wrong.questionId}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (wrong.wrongReason != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getReasonColor(
                                                        wrong.wrongReason!)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                wrong.wrongReason!,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: _getReasonColor(
                                                      wrong.wrongReason!),
                                                ),
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.refresh,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${wrong.reviewCount} 次',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (wrong.isMastered)
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppTheme.secondaryColor,
                                  )
                                else
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: provider.wrongQuestions.length,
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
        return AppTheme.errorColor;
      case '记忆模糊':
        return Colors.purple;
      case '理解偏差':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showWrongDetail(BuildContext context, wrong) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '错题详情',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // TODO: 显示题目详情
                  Text('题目 ID: ${wrong.questionId}'),
                  const SizedBox(height: 8),
                  Text('错因: ${wrong.wrongReason ?? '未分类'}'),
                  const SizedBox(height: 8),
                  Text('复习次数: ${wrong.reviewCount}'),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: 开始复习
                        Navigator.pop(context);
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
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
