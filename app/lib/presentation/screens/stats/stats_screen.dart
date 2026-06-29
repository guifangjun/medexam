import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../data/providers/study_provider.dart';
import '../../../data/models/study.dart';
import '../../../core/theme/app_theme.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<StudyProvider>();
      p.loadStatsOverview();
      p.loadTodayStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据统计')),
      body: Consumer<StudyProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadStatsOverview();
              await provider.loadTodayStats();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _OverviewCard(overview: provider.overview),
                  const SizedBox(height: 16),
                  _TodayStatsCard(stats: provider.todayStats),
                  const SizedBox(height: 16),
                  const _AccuracyChart(),
                  const SizedBox(height: 16),
                  _WeakSubjectsCard(
                      subjectStats:
                          provider.overview?.subjectStats ?? {}),
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
  const _OverviewCard({this.overview});

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
          const Text('学习概况',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                  style: TextStyle(
                      color: Colors.white70, fontSize: 13)),
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
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
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
            style: TextStyle(
                fontSize: 12, color: Colors.white.withOpacity(0.7))),
      ],
    );
  }
}

class _TodayStatsCard extends StatelessWidget {
  final StudyStats? stats;
  const _TodayStatsCard({this.stats});

  @override
  Widget build(BuildContext context) {
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
              Icon(Icons.today_rounded,
                  color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('今日数据',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _TodayItem(
                label: '正确率',
                value:
                    '${((stats?.accuracyRate ?? 0) * 100).toInt()}%',
                color: AppTheme.success,
              ),
              _TodayItem(
                label: '做题数',
                value: '${stats?.totalQuestions ?? 0}',
                color: AppTheme.primary,
              ),
              _TodayItem(
                label: '学习时长',
                value: '${stats?.timeSpent ?? 0}min',
                color: AppTheme.accent,
              ),
            ],
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

  const _TodayItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _AccuracyChart extends StatelessWidget {
  const _AccuracyChart();

  @override
  Widget build(BuildContext context) {
    final data = [0.72, 0.75, 0.68, 0.82, 0.78, 0.85, 0.80];

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
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
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
                                fontSize: 10,
                                color: AppTheme.textSecondary));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final days = [
                          '一', '二', '三', '四', '五', '六', '日'
                        ];
                        return Text(
                          days[value.toInt() % days.length],
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary),
                        );
                      },
                    ),
                  ),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0.3,
                maxY: 1.0,
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value);
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
    final subjects = [
      {'name': '内科学', 'accuracy': 0.65},
      {'name': '外科学', 'accuracy': 0.72},
      {'name': '妇产科学', 'accuracy': 0.68},
      {'name': '儿科学', 'accuracy': 0.75},
      {'name': '基础医学', 'accuracy': 0.80},
    ];

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
              Icon(Icons.analytics_rounded,
                  color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('薄弱科目',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          ...subjects.take(3).map((s) {
            final acc = s['accuracy'] as double;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(s['name'] as String,
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
                        valueColor: AlwaysStoppedAnimation(
                            _getColor(acc)),
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
