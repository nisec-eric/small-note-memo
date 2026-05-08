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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showOneTimeCheckIn(context, ref),
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('单次打卡'),
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
                      // 只统计关联任务的打卡记录（排除单次打卡）
                      final taskDone = records.where((r) => r.taskId != null).length;
                      final total = tasks.length;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$taskDone/$total 已完成',
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
          // 今日单次打卡记录
          todayRecordsAsync.when(
            data: (records) {
              final oneTimeRecords = records.where((r) => r.taskId == null && r.topic != null).toList();
              if (oneTimeRecords.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: oneTimeRecords.map((r) {
                    return InkWell(
                      onTap: () {},
                      onLongPress: () => _confirmDeleteRecord(context, ref, r.id, r.topic!),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_rounded, size: 14, color: Theme.of(context).colorScheme.tertiary),
                            const SizedBox(width: 4),
                            Text(
                              r.topic!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
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
                      cycleDays: task.cycleDays,
                      cycleProgress: ref
                          .watch(cycleProgressProvider(task.id))
                          .valueOrNull,
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
                                 _confirmDeleteRecord(context, ref, recordId, '${task.icon} ${task.name}');
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

  void _showOneTimeCheckIn(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _OneTimeCheckInSheet(),
    );
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
}

class _OneTimeCheckInSheet extends ConsumerStatefulWidget {
  const _OneTimeCheckInSheet();

  @override
  ConsumerState<_OneTimeCheckInSheet> createState() => _OneTimeCheckInSheetState();
}

class _OneTimeCheckInSheetState extends ConsumerState<_OneTimeCheckInSheet> {
  final _topicCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _topicCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(pastTopicsProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '单次打卡',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Topic field
            TextField(
              controller: _topicCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '打卡主题 *',
                hintText: '例如：跑步5公里',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            // Past topic suggestions
            const SizedBox(height: 12),
            topicsAsync.when(
              data: (topics) {
                if (topics.isEmpty) return const SizedBox.shrink();
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: topics.map((t) {
                    return ActionChip(
                      label: Text(t),
                      onPressed: () {
                        _topicCtrl.text = t;
                        setState(() {});
                      },
                    );
                  }).toList(),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Note field
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: '备注（可选）',
                hintText: '记录一些细节...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _topicCtrl.text.trim().isEmpty ? null : _submit,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('记录', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) return;
    final note = _noteCtrl.text.trim();
    ref.read(todayRecordsProvider.notifier).oneTimeCheckIn(
          topic: topic,
          note: note.isEmpty ? null : note,
        );
    Navigator.pop(context);
  }
}
