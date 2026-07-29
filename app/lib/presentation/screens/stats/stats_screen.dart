import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../data/providers/study_provider.dart';
import '../../../data/providers/question_provider.dart';
import '../../../data/models/study.dart';
import '../../../core/theme/app_theme.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String? _loadedExamCategory;
  bool _loadScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadForCurrentCategory();
    });
  }

  Future<void> _reloadForCurrentCategory() async {
    if (!mounted) return;
    final examCategory = context.read<QuestionProvider>().examCategory;
    _loadedExamCategory = examCategory;
    final provider = context.read<StudyProvider>();
    await provider.loadStatsOverview(examCategory: examCategory);
    await provider.loadTodayStats(examCategory: examCategory);
  }

  void _scheduleReloadIfCategoryChanged(String examCategory) {
    if (_loadedExamCategory == examCategory || _loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadScheduled = false;
      await _reloadForCurrentCategory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据统计')),
      body: Consumer<StudyProvider>(
        builder: (context, provider, _) {
          final examCategory = context.watch<QuestionProvider>().examCategory;
          _scheduleReloadIfCategoryChanged(examCategory);
          if (provider.isLoading && provider.overview == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async {
              await _reloadForCurrentCategory();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (provider.isLoading) ...[
                    const LinearProgressIndicator(minHeight: 3),
                    const SizedBox(height: 12),
                  ],
                  if (provider.error != null) ...[
                    _StatsErrorBanner(
                      message: provider.error!,
                      onRetry: _reloadForCurrentCategory,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _OverviewCard(
                    overview: provider.overview,
                    examCategory: examCategory,
                  ),
                  const SizedBox(height: 16),
                  _TodayStatsCard(stats: provider.todayStats),
                  const SizedBox(height: 16),
                  _AccuracyChart(
                      points: provider.overview?.accuracyTrend ?? []),
                  const SizedBox(height: 16),
                  _WeakSubjectsCard(
                      subjectStats: provider.overview?.subjectStats ?? {}),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final StatsOverview? overview;
  final String examCategory;
  const _OverviewCard({this.overview, required this.examCategory});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryLight],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$examCategory · 累计学习概况',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text('统计当前考试分类下的全部练习记录，下面“今日数据”只统计今天。',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withOpacity(0.75))),
          const SizedBox(height: 20),
          Wrap(
            spacing: 18,
            runSpacing: 14,
            alignment: WrapAlignment.spaceAround,
            children: [
              _OverviewItem(
                  icon: Icons.quiz_rounded,
                  value: '${overview?.totalQuestions ?? 0}',
                  label: '总做题'),
              _OverviewItem(
                  icon: Icons.check_circle_rounded,
                  value: '${overview?.totalCorrect ?? 0}',
                  label: '做对'),
              _OverviewItem(
                  icon: Icons.local_fire_department_rounded,
                  value: '${overview?.currentStreak ?? 0}',
                  label: '连续学习'),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('总正确率',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              Text(
                '${((overview?.overallAccuracy ?? 0) * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: overview?.overallAccuracy ?? 0,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _OverviewItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 24),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        Text(label,
            style:
                TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
      ],
    );
  }
}

class _TodayStatsCard extends StatelessWidget {
  final StudyStats? stats;
  const _TodayStatsCard({this.stats});

  @override
  Widget build(BuildContext context) {
    final minutes = ((stats?.timeSpent ?? 0) / 60).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.today_rounded, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('今日数据',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth < 360
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  _TodayItem(
                    label: '正确率',
                    value: '${((stats?.accuracyRate ?? 0) * 100).toInt()}%',
                    color: AppTheme.success,
                    width: itemWidth,
                  ),
                  _TodayItem(
                    label: '做题数',
                    value: '${stats?.totalQuestions ?? 0}',
                    color: AppTheme.primary,
                    width: itemWidth,
                  ),
                  _TodayItem(
                    label: '学习时长',
                    value: '${minutes}min',
                    color: AppTheme.accent,
                    width: itemWidth,
                  ),
                  _TodayItem(
                    label: 'AI 咨询',
                    value: '${stats?.aiQuestions ?? 0}次',
                    color: Colors.orange,
                    width: itemWidth,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TodayItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final double width;

  const _TodayItem({
    required this.label,
    required this.value,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _StatsErrorBanner extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _StatsErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.error.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _AccuracyChart extends StatelessWidget {
  final List<AccuracyTrendPoint> points;

  const _AccuracyChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up_rounded,
                  color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('正确率趋势',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          if (points.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 34),
              child: Center(
                child: Text(
                  '暂无趋势数据，完成练习后会自动生成',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 0.25,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppTheme.divider,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          return Text('${(value * 100).toInt()}%',
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.textSecondary));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          final date = points[index].date;
                          final label =
                              date.length >= 10 ? date.substring(5) : date;
                          return Text(
                            label,
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textSecondary),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: 1.0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: points.asMap().entries.map((e) {
                        return FlSpot(
                          e.key.toDouble(),
                          e.value.accuracyRate.clamp(0.0, 1.0),
                        );
                      }).toList(),
                      isCurved: true,
                      color: AppTheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: AppTheme.primary,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primary.withOpacity(0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeakSubjectsCard extends StatelessWidget {
  final Map<String, dynamic> subjectStats;
  const _WeakSubjectsCard({required this.subjectStats});

  Color _getColor(double accuracy) {
    if (accuracy >= 0.8) return AppTheme.success;
    if (accuracy >= 0.6) return AppTheme.accent;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final subjects = subjectStats.entries
        .map((entry) {
          final value = entry.value;
          final data = value is Map ? value : <String, dynamic>{};
          final name = (data['name'] ?? entry.key).toString();
          final category = (data['exam_category'] ?? '').toString();
          final displayName = category.isEmpty ? name : '$category · $name';
          return {
            'name': displayName,
            'accuracy': (data['accuracy_rate'] ?? 0.0).toDouble(),
            'total': data['total_questions'] ?? 0,
          };
        })
        .where((item) => (item['total'] as int) > 0)
        .toList()
      ..sort((a, b) =>
          (a['accuracy'] as double).compareTo(b['accuracy'] as double));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_rounded, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('薄弱章节',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          if (subjects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  '暂无薄弱科目数据，完成练习后会自动分析',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            ...subjects.take(5).map((s) {
              final acc = s['accuracy'] as double;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(s['name'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: acc,
                          minHeight: 8,
                          backgroundColor: AppTheme.divider,
                          valueColor: AlwaysStoppedAnimation(_getColor(acc)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${(acc * 100).toInt()}%',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _getColor(acc))),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
