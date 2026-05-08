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
    int cycleDays = 1,
    int cycleTarget = 1,
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
      cycleDays: cycleDays,
      cycleTarget: cycleTarget,
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

  // ─── One-time Check-in ─────────────────────────

  Future<CheckInRecord> oneTimeCheckIn({
    required String topic,
    String? note,
  }) async {
    final box = await Hive.openBox(_recordsBox);
    final record = CheckInRecord(
      id: _uuid.v4(),
      topic: topic,
      note: note,
    );
    await box.put(record.id, record.toMap());
    return record;
  }

  Future<List<CheckInRecord>> getOneTimeRecords() async {
    final all = await getAllRecords();
    return all.where((r) => r.taskId == null && r.topic != null).toList()
      ..sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
  }

  Future<List<String>> getPastTopics() async {
    final records = await getOneTimeRecords();
    final topics = records.map((r) => r.topic!).toSet().toList();
    topics.sort(); // alphabetical
    return topics;
  }

  /// Returns list of (topic, count, latestDate)
  Future<List<(String, int, DateTime)>> getTopicsAggregated() async {
    final records = await getOneTimeRecords();
    final topicMap = <String, (int, DateTime)>{};
    for (final r in records) {
      final t = r.topic!;
      final existing = topicMap[t];
      if (existing != null) {
        topicMap[t] = (
          existing.$1 + 1,
          r.checkedAt.isAfter(existing.$2) ? r.checkedAt : existing.$2,
        );
      } else {
        topicMap[t] = (1, r.checkedAt);
      }
    }
    final result = topicMap.entries
        .map((e) => (e.key, e.value.$1, e.value.$2))
        .toList();
    result.sort((a, b) => b.$3.compareTo(a.$3)); // sort by latest date
    return result;
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

  /// 删除任意打卡记录，返回其 taskId（可能为 null）
  Future<String?> deleteRecord(String recordId) async {
    final box = await Hive.openBox(_recordsBox);
    final data = box.get(recordId);
    if (data == null) return null;
    final taskId = data['taskId'] as String?;
    await box.delete(recordId);
    return taskId;
  }

  Future<void> deleteRecordsByTask(String taskId) async {
    final box = await Hive.openBox(_recordsBox);
    final records = await getRecordsByTask(taskId);
    await box.deleteAll(records.map((r) => r.id));
  }

  // ─── 统计辅助 ────────────────────────────────

  /// 获取当前周期内的打卡进度 (completed, remaining, periodStart, periodEnd)
  Future<(int, int, DateTime, DateTime)> getCycleProgress(
      String taskId, CheckInTask task) async {
    final records = await getRecordsByTask(taskId);
    final cycleIndex = task.currentCycleIndex;
    final (periodStart, periodEnd) = task.cyclePeriod(cycleIndex);

    final checkedDates = <DateTime>{};
    for (final r in records) {
      final d = r.date;
      if (!d.isBefore(periodStart) && !d.isAfter(periodEnd)) {
        checkedDates.add(d);
      }
    }

    final completed = checkedDates.length;
    var remaining = task.cycleTarget - completed;
    if (remaining < 0) remaining = 0;
    return (completed, remaining, periodStart, periodEnd);
  }

  /// 获取某任务的连续打卡天数 (从今天往前数)
  Future<int> getStreak(String taskId, CheckInTask task) async {
    // 每天1次的简单模式, 保持原有逻辑
    if (task.cycleDays == 1 && task.cycleTarget == 1) {
      final records = await getRecordsByTask(taskId);
      final checkedDates = records.map((r) => r.date).toSet();

      int streak = 0;
      var day = DateTime.now();
      day = DateTime(day.year, day.month, day.day);

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

    // 周期模式: 计算连续完成的周期数 (从当前周期往前)
    final records = await getRecordsByTask(taskId);
    final checkedDates = records.map((r) => r.date).toSet();

    int streak = 0;
    final currentCycle = task.currentCycleIndex;

    for (int i = currentCycle; i >= 0; i--) {
      final (cycleStart, _) = task.cyclePeriod(i);

      int daysChecked = 0;
      for (int d = 0; d < task.cycleDays; d++) {
        final date = cycleStart.add(Duration(days: d));
        if (checkedDates.contains(date)) {
          daysChecked++;
        }
      }

      if (daysChecked >= task.cycleTarget) {
        streak++;
      } else {
        // 如果是当前周期, 可能还在进行中 - 不中断连续计数
        if (i == currentCycle) continue;
        break;
      }
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

  /// 获取某任务的所有历史周期记录
  /// Returns list of (cycleIndex, startDate, endDate, completedCount, isCompleted)
  List<(int, DateTime, DateTime, int, bool)> getCycleHistorySync(
    CheckInTask task,
    List<CheckInRecord> records,
  ) {
    final checkedDates = records
        .where((r) => r.taskId == task.id)
        .map((r) => r.date)
        .toSet();

    final currentCycle = task.currentCycleIndex;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final result = <(int, DateTime, DateTime, int, bool)>[];

    for (int i = 0; i <= currentCycle; i++) {
      final (start, end) = task.cyclePeriod(i);

      int daysChecked = 0;
      for (int d = 0; d < task.cycleDays; d++) {
        final date = start.add(Duration(days: d));
        if (checkedDates.contains(date)) {
          daysChecked++;
        }
      }

      // isCompleted: the cycle's end date has passed (or is today)
      final isCompleted = !end.isAfter(today);

      result.add((i, start, end, daysChecked, isCompleted));
    }

    // Return in reverse order (newest first)
    return result.reversed.toList();
  }

  // ─── 导入导出 ────────────────────────────────

  /// 导出所有数据为 JSON 字符串
  Future<String> exportData({bool includeRecords = true}) async {
    final tasks = await getAllTasks();
    final data = {
      'version': 1,
      'app': 'check_in_memo',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tasks': tasks.map((t) => t.toMap()).toList(),
      'records': includeRecords
          ? (await getAllRecords()).map((r) => r.toMap()).toList()
          : <Map<String, dynamic>>[],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 导出为临时文件，返回文件路径
  Future<File> exportToFile({bool includeRecords = true}) async {
    final json = await exportData(includeRecords: includeRecords);
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/check_in_memo_$timestamp.json');
    await file.writeAsString(json);
    return file;
  }

  /// 导入数据（合并模式：跳过已存在的 task/record）
  /// 返回 (导入任务数, 导入记录数, 跳过任务数, 跳过记录数)
  Future<(int, int, int, int)> importData(String json, {bool includeRecords = true}) async {
    final data = jsonDecode(json) as Map<String, dynamic>;

    if (data['app'] != 'check_in_memo') {
      throw const FormatException('不是有效的打卡记录导出文件');
    }

    final version = data['version'] as int? ?? 0;
    if (version != 1) {
      throw FormatException('不支持的导出文件版本: $version');
    }

    final importedTasks = data['tasks'] as List? ?? [];
    final importedRecords = includeRecords
        ? (data['records'] as List? ?? [])
        : <dynamic>[];

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

  /// 获取每日任务的打卡日期列表 (normalized dates, newest first)
  Future<List<DateTime>> getDailyCheckInDates(String taskId) async {
    final records = await getRecordsByTask(taskId);
    return records.map((r) => r.date).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
  }
}
