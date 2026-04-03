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
      context.read<StudyProvider>().loadStatsOverview();
      context.read<StudyProvider>().loadTodayStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据统计'),
      ),
      body: Consumer<StudyProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final overview = provider.overview;
          final todayStats = provider.todayStats;

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadStatsOverview();
              await provider.loadTodayStats();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 总体概况
                  _OverviewCard(overview: overview),
                  const SizedBox(height: 16),
                  // 今日数据
                  _TodayStatsCard(stats: todayStats),
                  const SizedBox(height: 16),
                  // 正确率趋势
                  const _AccuracyChart(),
                  const SizedBox(height: 16),
                  // 薄弱科目
                  _WeakSubjectsCard(subjectStats: overview?.subjectStats ?? {}),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '学习概况',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _OverviewItem(
                  icon: Icons.edit,
                  value: '${overview?.totalQuestions ?? 0}',
                  label: '总做题数',
                  color: AppTheme.primaryColor,
                ),
                _OverviewItem(
                  icon: Icons.check_circle,
                  value: '${overview?.totalCorrect ?? 0}',
                  label: '做对题数',
                  color: AppTheme.secondaryColor,
                ),
                _OverviewItem(
                  icon: Icons.local_fire_department,
                  value: '${overview?.currentStreak ?? 0}',
                  label: '连续学习',
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 总正确率
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '总正确率',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: overview?.overallAccuracy ?? 0,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(
                                _getAccuracyColor(overview?.overallAccuracy ?? 0),
                              ),
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${((overview?.overallAccuracy ?? 0) * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _getAccuracyColor(overview?.overallAccuracy ?? 0),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.8) return AppTheme.secondaryColor;
    if (accuracy >= 0.6) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}

class _OverviewItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _OverviewItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
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

class _TodayStatsCard extends StatelessWidget {
  final StudyStats? stats;

  const _TodayStatsCard({this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '今日数据',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  stats?.date ?? '',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: '做题',
                    value: '${stats?.totalQuestions ?? 0}',
                    icon: Icons.edit_note,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: '正确',
                    value: '${stats?.correctCount ?? 0}',
                    icon: Icons.check,
                    color: AppTheme.secondaryColor,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: '错误',
                    value: '${stats?.wrongCount ?? 0}',
                    icon: Icons.close,
                    color: AppTheme.errorColor,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'AI提问',
                    value: '${stats?.aiQuestions ?? 0}',
                    icon: Icons.smart_toy,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _AccuracyChart extends StatelessWidget {
  const _AccuracyChart();

  @override
  Widget build(BuildContext context) {
    // 模拟近7天的数据
    final data = [
      0.65, 0.72, 0.68, 0.75, 0.70, 0.78, 0.82,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '正确率趋势',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 0.2,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[200],
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value * 100).toInt()}%',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final days = ['一', '二', '三', '四', '五', '六', '日'];
                          return Text(
                            days[value.toInt()],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: 1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value);
                      }).toList(),
                      isCurved: true,
                      color: AppTheme.primaryColor,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: AppTheme.primaryColor,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeakSubjectsCard extends StatelessWidget {
  final Map<String, dynamic> subjectStats;

  const _WeakSubjectsCard({required this.subjectStats});

  @override
  Widget build(BuildContext context) {
    // 模拟数据
    final subjects = [
      {'name': '内科学', 'accuracy': 0.65},
      {'name': '外科学', 'accuracy': 0.72},
      {'name': '妇产科学', 'accuracy': 0.68},
      {'name': '儿科学', 'accuracy': 0.75},
      {'name': '基础医学', 'accuracy': 0.80},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '薄弱科目',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...subjects.take(3).map((s) {
              final accuracy = s['accuracy'] as double;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        s['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: accuracy,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(
                          _getAccuracyColor(accuracy),
                        ),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(accuracy * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getAccuracyColor(accuracy),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.8) return AppTheme.secondaryColor;
    if (accuracy >= 0.6) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}
