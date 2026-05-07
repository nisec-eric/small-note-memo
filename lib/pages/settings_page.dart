import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/task.dart';
import '../providers/app_providers.dart';
import '../services/storage_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (tasks) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // 任务列表
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '打卡任务',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${tasks.length} 个任务',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                    ),
                  ],
                ),
              ),
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.playlist_add_check_rounded,
                        size: 56,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '还没有打卡任务',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '点击右下角 + 添加',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                      ),
                    ],
                  ),
                )
              else
                ...tasks.map((task) => _TaskListTile(
                      task: task,
                      onEdit: () => _showTaskDialog(context, ref, task: task),
                      onDelete: () => _confirmDelete(context, ref, task),
                    )),

              // 数据管理
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  '数据管理',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.upload_file_rounded,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('导出数据', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('导出任务配置和打卡记录，便于分享或迁移'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _export(context),
              ),
              ListTile(
                leading: Icon(Icons.file_download_outlined,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('导入数据', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('从文件导入，已有数据会保留（合并模式）'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _import(context, ref),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(context, ref),
        tooltip: '添加任务',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CheckInTask task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除「${task.name}」吗？所有打卡记录也会被删除。'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(tasksProvider.notifier).deleteTask(task.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final includeRecords = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ExportDialog(),
    );
    if (includeRecords == null) return;

    try {
      final storage = StorageService();
      final file = await storage.exportToFile(includeRecords: includeRecords);

      if (context.mounted) {
        if (Platform.isAndroid) {
          await Share.shareXFiles(
            [XFile(file.path)],
            text: includeRecords ? '打卡记录导出（含打卡日志）' : '打卡记录导出（仅任务配置）',
          );
        } else {
          final json = await file.readAsString();
          await Share.share(json);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null) return;

      final file = result.files.first;
      String content;
      if (file.path == null) {
        final bytes = file.bytes;
        if (bytes == null) return;
        content = String.fromCharCodes(bytes);
      } else {
        content = await File(file.path!).readAsString();
      }

      final includeRecords = await showDialog<bool>(
        context: context,
        builder: (ctx) => _ImportDialog(content: content),
      );
      if (includeRecords == null) return;

      await _doImport(context, ref, content, includeRecords: includeRecords);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  Future<void> _doImport(
      BuildContext context, WidgetRef ref, String json, {bool includeRecords = true}) async {
    final storage = StorageService();
    final (taskImported, recordImported, taskSkipped, recordSkipped) =
        await storage.importData(json, includeRecords: includeRecords);

    // 刷新 providers
    ref.invalidate(tasksProvider);
    ref.invalidate(todayRecordsProvider);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入完成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ 导入任务: $taskImported 个'),
              if (includeRecords) ...[
                Text('✅ 导入记录: $recordImported 条'),
              ] else ...[
                Text('ℹ️ 仅导入任务配置（不含打卡日志）',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
              if (taskSkipped > 0 || (includeRecords && recordSkipped > 0)) ...[
                const SizedBox(height: 8),
                if (taskSkipped > 0)
                  Text('⏭ 跳过任务: $taskSkipped 个（已存在）',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5))),
                if (includeRecords && recordSkipped > 0)
                  Text('⏭ 跳过记录: $recordSkipped 条（已存在）',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5))),
              ],
            ],
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('好的'),
            ),
          ],
        ),
      );
    }
  }

  void _showTaskDialog(BuildContext context, WidgetRef ref, {CheckInTask? task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TaskForm(task: task),
    );
  }
}

class _TaskListTile extends StatelessWidget {
  final CheckInTask task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskListTile({
    required this.task,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(task.icon, style: const TextStyle(fontSize: 26)),
      title: Text(task.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${task.repeatText}  ·  ${task.timeWindowText}${task.cycleDays > 1 ? '  ·  ${task.cycleTarget}/${task.cycleDays}天' : ''}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.withValues(alpha: 0.7)),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _TaskForm extends ConsumerStatefulWidget {
  final CheckInTask? task;

  const _TaskForm({this.task});

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  late TextEditingController _nameCtrl;
  static const _defaultIcon = '⭐';
  String _icon = _defaultIcon;
  final _selectedDays = <int>[];
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int _cycleDays = 1;
  int _cycleTarget = 1;

  static const _emojiOptions = [
    '⭐', '☀️', '📖', '🏃', '💪', '🎯', '📝', '🎵',
    '🧘', '💤', '🍎', '💊', '🎨', '💻', '📚', '🏊',
  ];

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _icon = t?.icon ?? _defaultIcon;
    if (t != null) {
      _selectedDays.addAll(t.repeatDays);
      _cycleDays = t.cycleDays;
      _cycleTarget = t.cycleTarget;
      if (t.startMinutes != null) {
        _startTime = TimeOfDay(hour: t.startMinutes! ~/ 60, minute: t.startMinutes! % 60);
      }
      if (t.endMinutes != null) {
        _endTime = TimeOfDay(hour: t.endMinutes! ~/ 60, minute: t.endMinutes! % 60);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isEdit ? '编辑任务' : '新建任务',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 任务名称
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: '任务名称',
                hintText: '例如：早起打卡',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // 选择图标
            Text('选择图标', style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojiOptions.map((e) {
                final selected = e == _icon;
                return GestureDetector(
                  onTap: () => setState(() => _icon = e),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      border: selected
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                          : Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 重复日期
            Text('重复日期', style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            )),
            const SizedBox(height: 8),
            Row(
              children: List.generate(7, (i) {
                final day = i + 1; // 1=Mon..7=Sun
                const labels = ['一', '二', '三', '四', '五', '六', '日'];
                final selected = _selectedDays.contains(day);
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedDays.remove(day);
                        } else {
                          _selectedDays.add(day);
                        }
                      });
                    },
                    child: Container(
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (_selectedDays.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '未选择 = 每天',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // 时间窗口
            Text('时间窗口 (可选)', style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            )),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _startTime ?? const TimeOfDay(hour: 6, minute: 0));
                      if (t != null) setState(() => _startTime = t);
                    },
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text(_startTime != null ? _startTime!.format(context) : '开始时间'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('~'),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _endTime ?? const TimeOfDay(hour: 22, minute: 0));
                      if (t != null) setState(() => _endTime = t);
                    },
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text(_endTime != null ? _endTime!.format(context) : '结束时间'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // 统计周期
            Text('统计周期', style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            )),
            const SizedBox(height: 8),
            // 目标次数
            _buildStepper(
              label: '目标次数',
              value: _cycleTarget,
              onChanged: (v) => setState(() => _cycleTarget = v),
              min: 1,
              max: 30,
            ),
            const SizedBox(height: 8),
            // 周期天数
            _buildStepper(
              label: '周期天数',
              value: _cycleDays,
              onChanged: (v) => setState(() => _cycleDays = v),
              min: 1,
              max: 30,
            ),
            if (_cycleDays == 1 && _cycleTarget == 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '每天打卡模式',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              )
            else if (_cycleTarget > _cycleDays)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '目标不能大于周期',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 28),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_isEdit ? '保存修改' : '创建任务', style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required int min,
    required int max,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          )),
        ),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: Icon(Icons.remove_circle_outline, size: 28,
            color: value > min
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          visualDensity: VisualDensity.compact,
        ),
        SizedBox(
          width: 36,
          child: Center(
            child: Text('$value', style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            )),
          ),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: Icon(Icons.add_circle_outline, size: 28,
            color: value < max
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final startMinutes = _startTime != null ? _startTime!.hour * 60 + _startTime!.minute : null;
    final endMinutes = _endTime != null ? _endTime!.hour * 60 + _endTime!.minute : null;

    if (_isEdit) {
      final updated = widget.task!.copyWith(
        name: name,
        icon: _icon,
        repeatDays: _selectedDays.toList(),
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        cycleDays: _cycleDays,
        cycleTarget: _cycleTarget,
      );
      ref.read(tasksProvider.notifier).updateTask(updated);
    } else {
      ref.read(tasksProvider.notifier).createTask(
        name: name,
        icon: _icon,
        repeatDays: _selectedDays.toList(),
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        cycleDays: _cycleDays,
        cycleTarget: _cycleTarget,
      );
    }
    Navigator.pop(context);
  }
}

class _ExportDialog extends StatefulWidget {
  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  bool _includeRecords = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导出数据'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选择导出内容：'),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: true,
            onChanged: null,
            title: const Text('任务配置'),
            subtitle: const Text('打卡任务的名称、图标、周期等设置'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _includeRecords,
            onChanged: (v) => setState(() => _includeRecords = v ?? true),
            title: const Text('打卡日志'),
            subtitle: Text(
              _includeRecords ? '包含所有打卡记录' : '仅导出任务配置，不含打卡记录',
              style: TextStyle(
                color: _includeRecords ? null : Colors.orange.shade700,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _includeRecords),
          child: const Text('导出'),
        ),
      ],
    );
  }
}

class _ImportDialog extends StatefulWidget {
  final String content;
  const _ImportDialog({required this.content});

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  bool _includeRecords = true;

  @override
  Widget build(BuildContext context) {
    int taskCount = 0;
    int recordCount = 0;
    try {
      final data = jsonDecode(widget.content) as Map<String, dynamic>;
      taskCount = (data['tasks'] as List?)?.length ?? 0;
      recordCount = (data['records'] as List?)?.length ?? 0;
    } catch (_) {}

    return AlertDialog(
      title: const Text('导入数据'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('文件包含 $taskCount 个任务、$recordCount 条打卡记录'),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _includeRecords,
            onChanged: (v) => setState(() => _includeRecords = v ?? true),
            title: const Text('导入打卡日志'),
            subtitle: Text(
              _includeRecords ? '合并所有打卡记录' : '仅导入任务配置',
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _includeRecords),
          child: const Text('导入'),
        ),
      ],
    );
  }
}
