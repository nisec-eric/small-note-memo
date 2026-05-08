import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../models/record.dart';
import '../services/storage_service.dart';

// ─── StorageService 单例 ──────────────────────

final storageProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// ─── 任务列表 ──────────────────────────────────

final tasksProvider = AsyncNotifierProvider<TasksNotifier, List<CheckInTask>>(
  TasksNotifier.new,
);

class TasksNotifier extends AsyncNotifier<List<CheckInTask>> {
  @override
  Future<List<CheckInTask>> build() async {
    final storage = ref.read(storageProvider);
    return storage.getAllTasks();
  }

  Future<void> createTask({
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
    final storage = ref.read(storageProvider);
    await storage.createTask(
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
    ref.invalidateSelf();
  }

  Future<void> updateTask(CheckInTask task) async {
    final storage = ref.read(storageProvider);
    await storage.updateTask(task);
    ref.invalidateSelf();
  }

  Future<void> deleteTask(String taskId) async {
    final storage = ref.read(storageProvider);
    await storage.deleteTask(taskId);
    ref.invalidateSelf();
    // 同时刷新记录
    ref.invalidate(todayRecordsProvider);
  }
}

// ─── 今日打卡记录 ──────────────────────────────

final todayRecordsProvider =
    AsyncNotifierProvider<TodayRecordsNotifier, List<CheckInRecord>>(
  TodayRecordsNotifier.new,
);

class TodayRecordsNotifier extends AsyncNotifier<List<CheckInRecord>> {
  @override
  Future<List<CheckInRecord>> build() async {
    final storage = ref.read(storageProvider);
    final now = DateTime.now();
    return storage.getRecordsByDate(
      DateTime(now.year, now.month, now.day),
    );
  }

  Future<void> checkIn(String taskId) async {
    final storage = ref.read(storageProvider);
    await storage.checkIn(taskId);
    ref.invalidateSelf();
    _invalidateStats(taskId);
  }

  Future<void> undoCheckIn(String recordId) async {
    // 先找到对应 taskId 再删除，用于刷新统计
    final records = state.valueOrNull ?? [];
    final taskId = records
        .where((r) => r.id == recordId)
        .map((r) => r.taskId)
        .firstOrNull;

    final storage = ref.read(storageProvider);
    await storage.undoCheckIn(recordId);
    ref.invalidateSelf();
    if (taskId != null) _invalidateStats(taskId);
  }

  Future<void> oneTimeCheckIn({required String topic, String? note}) async {
    final storage = ref.read(storageProvider);
    await storage.oneTimeCheckIn(topic: topic, note: note);
    ref.invalidateSelf();
    ref.invalidate(oneTimeRecordsProvider);
    ref.invalidate(pastTopicsProvider);
    ref.invalidate(topicsAggregatedProvider);
    final now = DateTime.now();
    ref.invalidate(monthlyStatsProvider((year: now.year, month: now.month)));
  }

  /// 删除任意打卡记录，自动级联刷新相关 provider
  Future<void> deleteRecord(String recordId) async {
    final storage = ref.read(storageProvider);
    // 先查记录信息用于级联刷新
    final allRecords = await storage.getAllRecords();
    final record = allRecords.where((r) => r.id == recordId).firstOrNull;
    final taskId = record?.taskId;
    final recordDate = record?.checkedAt;

    await storage.deleteRecord(recordId);
    ref.invalidateSelf();
    // 刷新单次打卡相关
    ref.invalidate(oneTimeRecordsProvider);
    ref.invalidate(pastTopicsProvider);
    ref.invalidate(topicsAggregatedProvider);
    // 刷新月度统计（记录所在月 + 当前月）
    if (recordDate != null) {
      ref.invalidate(monthlyStatsProvider((year: recordDate.year, month: recordDate.month)));
    }
    final now = DateTime.now();
    ref.invalidate(monthlyStatsProvider((year: now.year, month: now.month)));
    // 如果关联了任务，刷新任务相关统计
    if (taskId != null) {
      _invalidateStats(taskId);
      ref.invalidate(taskRecordsProvider(taskId));
    }
  }

  void _invalidateStats(String taskId) {
    ref.invalidate(streakProvider(taskId));
    ref.invalidate(cycleProgressProvider(taskId));
    ref.invalidate(cycleHistoryProvider(taskId));
    ref.invalidate(dailyHistoryProvider(taskId));
    final now = DateTime.now();
    ref.invalidate(monthlyStatsProvider((year: now.year, month: now.month)));
  }

  /// 判断某任务今天是否已打卡
  bool isCheckedInToday(String taskId) {
    final records = state.valueOrNull ?? [];
    return records.any((r) => r.taskId == taskId);
  }

  /// 获取某任务今天的打卡记录ID (用于撤销)
  String? getTodayRecordId(String taskId) {
    final records = state.valueOrNull ?? [];
    try {
      return records.firstWhere((r) => r.taskId == taskId).id;
    } catch (_) {
      return null;
    }
  }
}

// ─── 今日需要打卡的任务 ────────────────────────

final todayTasksProvider = Provider<AsyncValue<List<CheckInTask>>>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  return tasksAsync.whenData((tasks) {
    final now = DateTime.now();
    return tasks.where((t) => t.shouldCheckIn(now)).toList();
  });
});

// ─── 统计数据 ──────────────────────────────────

final streakProvider =
    FutureProvider.family<int, String>((ref, taskId) async {
  final storage = ref.read(storageProvider);
  final tasks = ref.read(tasksProvider).valueOrNull ?? [];
  final task = tasks.where((t) => t.id == taskId).firstOrNull;
  if (task == null) return 0;
  return storage.getStreak(taskId, task);
});

final monthlyStatsProvider =
    FutureProvider.family<Map<int, int>, ({int year, int month})>(
  (ref, params) async {
    final storage = ref.read(storageProvider);
    return storage.getMonthlyStats(params.year, params.month);
  },
);

final cycleProgressProvider =
    FutureProvider.family<(int, int, DateTime, DateTime), String>(
        (ref, taskId) async {
  final storage = ref.read(storageProvider);
  final tasks = ref.read(tasksProvider).valueOrNull ?? [];
  final task = tasks.where((t) => t.id == taskId).firstOrNull;
  if (task == null) return (0, 0, DateTime.now(), DateTime.now());
  return storage.getCycleProgress(taskId, task);
});

final cycleHistoryProvider =
    FutureProvider.family<List<(int, DateTime, DateTime, int, bool)>, String>(
        (ref, taskId) async {
  final storage = ref.read(storageProvider);
  final tasks = ref.read(tasksProvider).valueOrNull ?? [];
  final task = tasks.where((t) => t.id == taskId).firstOrNull;
  if (task == null) return [];
  final records = await storage.getRecordsByTask(taskId);
  return storage.getCycleHistorySync(task, records);
});

final dailyHistoryProvider =
    FutureProvider.family<List<DateTime>, String>((ref, taskId) async {
  final storage = ref.read(storageProvider);
  return storage.getDailyCheckInDates(taskId);
});

/// 获取某任务所有打卡记录（含 ID，用于删除）
final taskRecordsProvider =
    FutureProvider.family<List<CheckInRecord>, String>((ref, taskId) async {
  final storage = ref.read(storageProvider);
  return storage.getRecordsByTask(taskId);
});

// ─── One-time Check-in ──────────────────────────

final oneTimeRecordsProvider =
    FutureProvider<List<CheckInRecord>>((ref) async {
  final storage = ref.read(storageProvider);
  return storage.getOneTimeRecords();
});

final pastTopicsProvider = FutureProvider<List<String>>((ref) async {
  final storage = ref.read(storageProvider);
  return storage.getPastTopics();
});

final topicsAggregatedProvider =
    FutureProvider<List<(String, int, DateTime)>>((ref) async {
  final storage = ref.read(storageProvider);
  return storage.getTopicsAggregated();
});
