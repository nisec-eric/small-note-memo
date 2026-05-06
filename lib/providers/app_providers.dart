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
  }

  Future<void> undoCheckIn(String recordId) async {
    final storage = ref.read(storageProvider);
    await storage.undoCheckIn(recordId);
    ref.invalidateSelf();
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

final weeklyCountsProvider = FutureProvider<List<int>>((ref) async {
  final storage = ref.read(storageProvider);
  return storage.getWeeklyCounts();
});
