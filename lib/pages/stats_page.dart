import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../widgets/weekly_chart.dart';
import '../widgets/heatmap_calendar.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final weeklyAsync = ref.watch(weeklyCountsProvider);
    final now = DateTime.now();
    final monthlyStatsAsync = ref.watch(monthlyStatsProvider((year: now.year, month: now.month)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 本月概览 ──
            _SectionCard(
              title: '本月概览',
              child: monthlyStatsAsync.when(
                loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('加载失败: $e'),
                data: (stats) {
                  final totalDays = DateTime(now.year, now.month + 1, 0).day;
                  final checkedDays = stats.length;
                  final rate = totalDays > 0 ? (checkedDays / totalDays * 100).round() : 0;
                  return Column(
                    children: [
                      Row(
                        children: [
                          _StatBox(label: '打卡率', value: '$rate%', highlight: true),
                          _StatBox(label: '已打卡天数', value: '$checkedDays'),
                          _StatBox(label: '本月天数', value: '$totalDays'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: rate / 100,
                          minHeight: 8,
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // ── 连续打卡天数 ──
            _SectionCard(
              title: '连续打卡',
              child: tasksAsync.when(
                loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('加载失败: $e'),
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('暂无任务', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return Column(
                    children: tasks.map((task) {
                      final streakAsync = ref.watch(streakProvider(task.id));
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: Text(task.icon, style: const TextStyle(fontSize: 22)),
                        title: Text(task.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        trailing: streakAsync.when(
                          loading: () => const SizedBox(width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          error: (e, s) => const Text('-'),
                          data: (streak) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (streak > 0) ...[
                                const Text('🔥', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                '$streak 天',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: streak > 0
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // ── 月度热力图 ──
            _SectionCard(
              title: '月度热力图',
              child: monthlyStatsAsync.when(
                loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('加载失败: $e'),
                data: (stats) => HeatmapCalendar(
                  year: now.year,
                  month: now.month,
                  dailyCounts: stats,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 周趋势图 ──
            _SectionCard(
              title: '近7天趋势',
              child: weeklyAsync.when(
                loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('加载失败: $e'),
                data: (counts) => WeeklyChart(weeklyCounts: counts),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatBox({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 28 : 22,
              fontWeight: FontWeight.bold,
              color: highlight ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
          ),
        ],
      ),
    );
  }
}
