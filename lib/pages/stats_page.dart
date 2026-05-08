import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../models/record.dart';
import '../providers/app_providers.dart';
import '../services/storage_service.dart';
import '../widgets/heatmap_calendar.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _previousMonth() {
    setState(() {
      _month--;
      if (_month < 1) {
        _month = 12;
        _year--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      _month++;
      if (_month > 12) {
        _month = 1;
        _year++;
      }
    });
  }

  Future<void> _showDayDetail(int day) async {
    final date = DateTime(_year, _month, day);
    final dateStr = DateFormat('M月d日 EEEE', 'zh_CN').format(date);
    final storage = StorageService();

    // 获取该日所有记录
    final records = await storage.getRecordsByDate(date);
    if (!mounted) return;

    // 获取任务信息用于显示
    final tasks = ref.read(tasksProvider).valueOrNull ?? [];

    // 分离任务打卡和单次打卡
    var taskRecords = records.where((r) => r.taskId != null).toList();
    var oneTimeRecords = records.where((r) => r.taskId == null && r.topic != null).toList();

    if (taskRecords.isEmpty && oneTimeRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$dateStr 无打卡记录'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => _DayDetailDialog(
        dateStr: dateStr,
        taskRecords: taskRecords,
        oneTimeRecords: oneTimeRecords,
        tasks: tasks,
        onDelete: (recordId) {
          ref.read(todayRecordsProvider.notifier).deleteRecord(recordId);
          Navigator.pop(context);
          // Refresh heatmap for this month
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    final now = DateTime.now();
    final currentMonthStats = ref.watch(monthlyStatsProvider((year: now.year, month: now.month)));
    final monthlyStatsAsync = ref.watch(monthlyStatsProvider((year: _year, month: _month)));

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
              child: currentMonthStats.when(
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
                loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('加载失败: $e'),
                data: (stats) => HeatmapCalendar(
                  year: _year,
                  month: _month,
                  dailyCounts: stats,
                  onPreviousMonth: _previousMonth,
                  onNextMonth: _nextMonth,
                  onDayTap: _showDayDetail,
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
            const SizedBox(height: 16),

            // ── 单次记录 ──
            _SectionCard(
              title: '单次记录',
              child: ref.watch(topicsAggregatedProvider).when(
                    loading: () => const SizedBox(
                        height: 60,
                        child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => Text('加载失败: $e'),
                    data: (topics) {
                      if (topics.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('暂无单次记录',
                              style: TextStyle(color: Colors.grey)),
                        );
                      }
                      return Column(
                        children: topics.map((item) {
                          final (topic, count, latestDate) = item;
                          return _OneTimeTopicRow(
                            topic: topic,
                            count: count,
                            latestDate: latestDate,
                          );
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

void _confirmDeleteRecord(BuildContext context, WidgetRef ref, String recordId, String label) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('删除记录'),
      content: Text('确定删除「$label」的打卡记录？'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            ref.read(todayRecordsProvider.notifier).deleteRecord(recordId);
          },
          child: Text('删除', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
        ),
      ],
    ),
  );
}

class _DayDetailDialog extends StatelessWidget {
  final String dateStr;
  final List<CheckInRecord> taskRecords;
  final List<CheckInRecord> oneTimeRecords;
  final List<CheckInTask> tasks;
  final ValueChanged<String> onDelete;

  const _DayDetailDialog({
    required this.dateStr,
    required this.taskRecords,
    required this.oneTimeRecords,
    required this.tasks,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(dateStr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 任务打卡
          if (taskRecords.isNotEmpty) ...[
            Text('任务打卡', style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            )),
            const SizedBox(height: 4),
            ...taskRecords.map((r) {
              final task = tasks.where((t) => t.id == r.taskId).firstOrNull;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(task?.icon ?? '📌', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(task?.name ?? '未知任务')),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: theme.colorScheme.error.withValues(alpha: 0.7)),
                      onPressed: () => onDelete(r.id),
                      tooltip: '删除',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              );
            }),
          ],
          // 单次打卡
          if (oneTimeRecords.isNotEmpty) ...[
            if (taskRecords.isNotEmpty) const SizedBox(height: 12),
            Text('单次打卡', style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            )),
            const SizedBox(height: 4),
            ...oneTimeRecords.map((r) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bookmark_outline_rounded, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(r.topic!, style: const TextStyle(fontWeight: FontWeight.w500)),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 18, color: theme.colorScheme.error.withValues(alpha: 0.7)),
                          onPressed: () => onDelete(r.id),
                          tooltip: '删除',
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    if (r.note != null && r.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 22),
                        child: Text(
                          r.note!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
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
    final recordsAsync = ref.watch(taskRecordsProvider(widget.task.id));
    final theme = Theme.of(context);

    return recordsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('加载失败: $e', style: const TextStyle(color: Colors.grey)),
      ),
      data: (records) {
        // Deduplicate by date, keep latest record per date
        final seenDates = <DateTime>{};
        final uniqueRecords = <CheckInRecord>[];
        for (final r in records) {
          final d = r.date;
          if (!seenDates.contains(d)) {
            seenDates.add(d);
            uniqueRecords.add(r);
          }
        }

        if (uniqueRecords.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${widget.task.icon} ${widget.task.name} — 暂无打卡记录',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          );
        }

        final displayRecords = _expanded ? uniqueRecords : uniqueRecords.take(7).toList();
        final total = uniqueRecords.length;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              InkWell(
                onTap: uniqueRecords.length > 7
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
                      if (uniqueRecords.length > 7) ...[
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
              // Date chips with long-press delete
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: displayRecords.map((r) {
                  final d = r.date;
                  return InkWell(
                    onLongPress: () => _confirmDeleteRecord(
                      context, ref, r.id, '${widget.task.icon} ${widget.task.name} ${d.month}/${d.day}',
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        '${d.month}/${d.day}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
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

class _OneTimeTopicRow extends ConsumerStatefulWidget {
  final String topic;
  final int count;
  final DateTime latestDate;

  const _OneTimeTopicRow({
    required this.topic,
    required this.count,
    required this.latestDate,
  });

  @override
  ConsumerState<_OneTimeTopicRow> createState() => _OneTimeTopicRowState();
}

class _OneTimeTopicRowState extends ConsumerState<_OneTimeTopicRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recordsAsync = ref.watch(oneTimeRecordsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.bookmark_outline_rounded,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.topic,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.count}次',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            recordsAsync.when(
              data: (records) {
                final topicRecords =
                    records.where((r) => r.topic == widget.topic).toList();
                return Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Column(
                    children: topicRecords.map((r) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text(
                              '${r.checkedAt.month}/${r.checkedAt.day}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            if (r.note != null && r.note!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r.note!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ] else
                              const Spacer(),
                            IconButton(
                              icon: Icon(Icons.close_rounded, size: 16,
                                  color: theme.colorScheme.error.withValues(alpha: 0.6)),
                              onPressed: () => _confirmDeleteRecord(context, ref, r.id, '${r.topic} ${r.checkedAt.month}/${r.checkedAt.day}'),
                              tooltip: '删除',
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const SizedBox(
                  height: 20,
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2))),
              error: (_, _) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}
