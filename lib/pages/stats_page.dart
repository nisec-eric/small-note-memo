import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../providers/app_providers.dart';
import '../widgets/heatmap_calendar.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
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
                                task.cycleDays == 1 && task.cycleTarget == 1
                                    ? '$streak 天'
                                    : '$streak 周期',
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

            // ── 打卡历史 ──
            _SectionCard(
              title: '打卡历史',
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
                      final isCycleTask = task.cycleDays > 1 || task.cycleTarget > 1;
                      if (isCycleTask) {
                        return _TaskCycleHistory(task: task);
                      } else {
                        return _TaskDailyHistory(task: task);
                      }
                    }).toList(),
                  );
                },
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

class _TaskDailyHistory extends ConsumerStatefulWidget {
  final CheckInTask task;

  const _TaskDailyHistory({required this.task});

  @override
  ConsumerState<_TaskDailyHistory> createState() => _TaskDailyHistoryState();
}

class _TaskDailyHistoryState extends ConsumerState<_TaskDailyHistory> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(dailyHistoryProvider(widget.task.id));
    final theme = Theme.of(context);

    return historyAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('加载失败: $e', style: const TextStyle(color: Colors.grey)),
      ),
      data: (dates) {
        if (dates.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${widget.task.icon} ${widget.task.name} — 暂无打卡记录',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          );
        }

        final displayDates = _expanded ? dates : dates.take(7).toList();
        final total = dates.length;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              InkWell(
                onTap: dates.length > 7
                    ? () => setState(() => _expanded = !_expanded)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(widget.task.icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.task.name,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '共$total次',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (dates.length > 7) ...[
                        const SizedBox(width: 8),
                        Icon(
                          _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Date chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: displayDates.map((date) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      '${date.month}/${date.day}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskCycleHistory extends ConsumerStatefulWidget {
  final CheckInTask task;

  const _TaskCycleHistory({required this.task});

  @override
  ConsumerState<_TaskCycleHistory> createState() => _TaskCycleHistoryState();
}

class _TaskCycleHistoryState extends ConsumerState<_TaskCycleHistory> {
  bool _expanded = false;

  String _statusIcon(int count, bool isCompleted) {
    if (!isCompleted) return '🔄';
    return count >= widget.task.cycleTarget ? '✅' : '❌';
  }

  Color _progressColor(int count, bool isCompleted, Color primary) {
    if (!isCompleted) return primary.withValues(alpha: 0.6);
    return count >= widget.task.cycleTarget ? primary : Colors.red.shade300;
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(cycleHistoryProvider(widget.task.id));
    final theme = Theme.of(context);

    return historyAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('加载失败: $e', style: const TextStyle(color: Colors.grey)),
      ),
      data: (cycles) {
        if (cycles.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${widget.task.icon} ${widget.task.name} — 暂无周期记录',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          );
        }

        final displayCycles = _expanded ? cycles : cycles.take(1).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: task icon + name + expand toggle
              InkWell(
                onTap: cycles.length > 1
                    ? () => setState(() => _expanded = !_expanded)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(widget.task.icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.task.name,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (cycles.length > 1)
                        Icon(
                          _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Cycle rows
              ...displayCycles.map((cycle) {
                final (cycleIndex, startDate, endDate, count, isCompleted) = cycle;
                final icon = _statusIcon(count, isCompleted);
                final progressColor = _progressColor(count, isCompleted, theme.colorScheme.primary);
                final progressValue = (count / widget.task.cycleTarget).clamp(0.0, 1.0);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            '${startDate.month}/${startDate.day} - ${endDate.month}/${endDate.day}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$count/${widget.task.cycleTarget}次',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progressValue,
                          minHeight: 3,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
