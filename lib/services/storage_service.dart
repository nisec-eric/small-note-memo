import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import '../models/record.dart';

class StorageService {
  static const _tasksBox = 'check_in_tasks';
  static const _recordsBox = 'check_in_records';
  static const _maxStreakDays = 365;

  final _uuid = const Uuid();

  // ─── Task CRUD ───────────────────────────────

  Future<List<CheckInTask>> getAllTasks() async {
    final box = await Hive.openBox(_tasksBox);
    return box.values
        .map((e) => CheckInTask.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<CheckInTask> createTask({
    required String name,
    required String icon,
    List<int> repeatDays = const [],
    int? startMinutes,
    int? endMinutes,
    bool reminderOn = false,
    int? reminderMinutes,
  }) async {
    final box = await Hive.openBox(_tasksBox);
    final task = CheckInTask(
      id: _uuid.v4(),
      name: name,
      icon: icon,
      repeatDays: repeatDays,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      reminderOn: reminderOn,
      reminderMinutes: reminderMinutes,
    );
    await box.put(task.id, task.toMap());
    return task;
  }

  Future<CheckInTask> updateTask(CheckInTask task) async {
    final box = await Hive.openBox(_tasksBox);
    await box.put(task.id, task.toMap());
    return task;
  }

  Future<void> deleteTask(String taskId) async {
    final box = await Hive.openBox(_tasksBox);
    await box.delete(taskId);
    // 同时删除该任务的所有打卡记录
    await deleteRecordsByTask(taskId);
  }

  // ─── Record CRUD ─────────────────────────────

  Future<List<CheckInRecord>> getAllRecords() async {
    final box = await Hive.openBox(_recordsBox);
    return box.values
        .map((e) => CheckInRecord.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<CheckInRecord>> getRecordsByTask(String taskId) async {
    final all = await getAllRecords();
    return all.where((r) => r.taskId == taskId).toList()
      ..sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
  }

  Future<List<CheckInRecord>> getRecordsByDate(DateTime date) async {
    final all = await getAllRecords();
    return all.where((r) {
      return r.checkedAt.year == date.year &&
          r.checkedAt.month == date.month &&
          r.checkedAt.day == date.day;
    }).toList();
  }

  /// 获取某任务在指定日期范围内的记录
  Future<List<CheckInRecord>> getRecordsByTaskAndDateRange(
    String taskId,
    DateTime start,
    DateTime end,
  ) async {
    final all = await getAllRecords();
    return all.where((r) {
      if (r.taskId != taskId) return false;
      final d = r.date;
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();
  }

  Future<CheckInRecord> checkIn(String taskId) async {
    final box = await Hive.openBox(_recordsBox);
    final record = CheckInRecord(
      id: _uuid.v4(),
      taskId: taskId,
    );
    await box.put(record.id, record.toMap());
    return record;
  }

  Future<void> undoCheckIn(String recordId) async {
    final box = await Hive.openBox(_recordsBox);
    await box.delete(recordId);
  }

  Future<void> deleteRecordsByTask(String taskId) async {
    final box = await Hive.openBox(_recordsBox);
    final records = await getRecordsByTask(taskId);
    await box.deleteAll(records.map((r) => r.id));
  }

  // ─── 统计辅助 ────────────────────────────────

  /// 获取某任务的连续打卡天数 (从今天往前数)
  Future<int> getStreak(String taskId, CheckInTask task) async {
    final records = await getRecordsByTask(taskId);
    final checkedDates = records.map((r) => r.date).toSet();

    int streak = 0;
    var day = DateTime.now();
    // 去掉时分秒
    day = DateTime(day.year, day.month, day.day);

    // 最多往前看
    for (int i = 0; i < _maxStreakDays; i++) {
      if (task.shouldCheckIn(day)) {
        if (checkedDates.contains(day)) {
          streak++;
        } else {
          break;
        }
      }
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// 获取某月每天的打卡情况 { day: count }
  Future<Map<int, int>> getMonthlyStats(int year, int month) async {
    final all = await getAllRecords();
    final result = <int, int>{};
    for (final r in all) {
      if (r.checkedAt.year == year && r.checkedAt.month == month) {
        result[r.checkedAt.day] = (result[r.checkedAt.day] ?? 0) + 1;
      }
    }
    return result;
  }

  // ─── 导入导出 ────────────────────────────────

  /// 导出所有数据为 JSON 字符串
  Future<String> exportData() async {
    final tasks = await getAllTasks();
    final records = await getAllRecords();
    final data = {
      'version': 1,
      'app': 'check_in_memo',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tasks': tasks.map((t) => t.toMap()).toList(),
      'records': records.map((r) => r.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 导出为临时文件，返回文件路径
  Future<File> exportToFile() async {
    final json = await exportData();
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/check_in_memo_$timestamp.json');
    await file.writeAsString(json);
    return file;
  }

  /// 导入数据（合并模式：跳过已存在的 task/record）
  /// 返回 (导入任务数, 导入记录数, 跳过任务数, 跳过记录数)
  Future<(int, int, int, int)> importData(String json) async {
    final data = jsonDecode(json) as Map<String, dynamic>;

    if (data['app'] != 'check_in_memo') {
      throw const FormatException('不是有效的打卡记录导出文件');
    }

    final version = data['version'] as int? ?? 0;
    if (version != 1) {
      throw FormatException('不支持的导出文件版本: $version');
    }

    final importedTasks = data['tasks'] as List? ?? [];
    final importedRecords = data['records'] as List? ?? [];

    // 加载现有数据用于去重
    final tasksBox = await Hive.openBox(_tasksBox);
    final recordsBox = await Hive.openBox(_recordsBox);
    final existingTaskIds = tasksBox.keys.toSet();
    final existingRecordIds = recordsBox.keys.toSet();

    int taskImported = 0;
    int taskSkipped = 0;
    int recordImported = 0;
    int recordSkipped = 0;

    // 导入任务（按 id 去重）
    for (final raw in importedTasks) {
      final map = Map<String, dynamic>.from(raw as Map);
      final id = map['id'] as String;
      if (existingTaskIds.contains(id)) {
        taskSkipped++;
      } else {
        await tasksBox.put(id, map);
        taskImported++;
      }
    }

    // 导入记录（按 id 去重）
    for (final raw in importedRecords) {
      final map = Map<String, dynamic>.from(raw as Map);
      final id = map['id'] as String;
      if (existingRecordIds.contains(id)) {
        recordSkipped++;
      } else {
        await recordsBox.put(id, map);
        recordImported++;
      }
    }

    return (taskImported, recordImported, taskSkipped, recordSkipped);
  }

  /// 获取最近7天每天的打卡次数
  Future<List<int>> getWeeklyCounts() async {
    final all = await getAllRecords();
    final now = DateTime.now();
    final counts = List.filled(7, 0);

    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      for (final r in all) {
        if (r.checkedAt.year == day.year &&
            r.checkedAt.month == day.month &&
            r.checkedAt.day == day.day) {
          counts[6 - i]++;
        }
      }
    }
    return counts;
  }
}
