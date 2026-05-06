import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
import '../widgets/task_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayTasksAsync = ref.watch(todayTasksProvider);
    final todayRecordsAsync = ref.watch(todayRecordsProvider);
    final now = DateTime.now();
    final dateStr = DateFormat('M月d日 EEEE', 'zh_CN').format(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('打卡记录'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日期概览
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Text(
                  dateStr,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                const Spacer(),
                todayTasksAsync.when(
                  data: (tasks) => todayRecordsAsync.when(
                    data: (records) {
                      final done = records.length;
                      final total = tasks.length;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$done/$total 已完成',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 任务列表
          Expanded(
            child: todayTasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available_rounded,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '今天没有打卡任务',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '在设置页添加打卡任务',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                        ),
                      ],
                    ),
                  );
                }
                final checkedTaskIds = todayRecordsAsync.when(
                  data: (records) => records.map((r) => r.taskId).toSet(),
                  loading: () => <String>{},
                  error: (e, s) => <String>{},
                );

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final checkedIn = checkedTaskIds.contains(task.id);
                    return TaskCard(
                      task: task,
                      checkedIn: checkedIn,
                      colorIndex: index,
                      onCheckIn: () async {
                        await ref.read(todayRecordsProvider.notifier).checkIn(task.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${task.icon} ${task.name} 打卡成功！'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      },
                      onLongPress: checkedIn
                          ? () {
                              final recordId = ref
                                  .read(todayRecordsProvider.notifier)
                                  .getTodayRecordId(task.id);
                              if (recordId != null) {
                                ref.read(todayRecordsProvider.notifier).undoCheckIn(recordId);
                              }
                            }
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
