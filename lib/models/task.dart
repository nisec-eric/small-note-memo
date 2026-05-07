/// 打卡任务
class CheckInTask {
  final String id;
  final String name;
  final String icon; // emoji
  final List<int> repeatDays; // 1=周一 ... 7=周日, 空列表=每天
  final int? startMinutes; // 时间窗口开始(一天中的第几分钟), null=任意时段
  final int? endMinutes; // 时间窗口结束
  final bool reminderOn;
  final int? reminderMinutes; // 提醒时间(一天中的第几分钟)
  final int cycleDays; // 统计周期天数, 默认1(每天)
  final int cycleTarget; // 周期内需打卡天数, 默认1
  final DateTime cycleStartDate; // 周期起始日，默认与 createdAt 相同
  final DateTime createdAt;

  CheckInTask({
    required this.id,
    required this.name,
    required this.icon,
    this.repeatDays = const [],
    this.startMinutes,
    this.endMinutes,
    this.reminderOn = false,
    this.reminderMinutes,
    this.cycleDays = 1,
    this.cycleTarget = 1,
    DateTime? cycleStartDate,
    DateTime? createdAt,
  })  : cycleStartDate = cycleStartDate ?? createdAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// 判断某天是否需要打卡
  bool shouldCheckIn(DateTime date) {
    if (repeatDays.isEmpty) return true;
    // DateTime.monday=1 ... DateTime.sunday=7
    return repeatDays.contains(date.weekday);
  }

  /// 格式化时间窗口
  String get timeWindowText {
    if (startMinutes == null || endMinutes == null) return '任意时段';
    final start = _formatMinutes(startMinutes!);
    final end = _formatMinutes(endMinutes!);
    return '$start - $end';
  }

  /// 格式化周期规则
  String get cycleText {
    if (cycleDays == 1 && cycleTarget == 1) return '每天';
    return '$cycleTarget/$cycleDays天';
  }

  /// 格式化重复规则
  String get repeatText {
    if (repeatDays.isEmpty) return '每天';
    const dayLabels = ['', '一', '二', '三', '四', '五', '六', '日'];
    return repeatDays.map((d) => '周${dayLabels[d]}').join('、');
  }

  static String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  CheckInTask copyWith({
    String? name,
    String? icon,
    List<int>? repeatDays,
    Object? startMinutes = _sentinel,
    Object? endMinutes = _sentinel,
    bool? reminderOn,
    Object? reminderMinutes = _sentinel,
    int? cycleDays,
    int? cycleTarget,
    DateTime? cycleStartDate,
  }) {
    return CheckInTask(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      repeatDays: repeatDays ?? this.repeatDays,
      startMinutes: startMinutes == _sentinel
          ? this.startMinutes
          : startMinutes as int?,
      endMinutes: endMinutes == _sentinel
          ? this.endMinutes
          : endMinutes as int?,
      reminderOn: reminderOn ?? this.reminderOn,
      reminderMinutes: reminderMinutes == _sentinel
          ? this.reminderMinutes
          : reminderMinutes as int?,
      cycleDays: cycleDays ?? this.cycleDays,
      cycleTarget: cycleTarget ?? this.cycleTarget,
      cycleStartDate: cycleStartDate ?? this.cycleStartDate,
      createdAt: createdAt,
    );
  }

  static const _sentinel = Object();

  /// 序列化为 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'repeatDays': repeatDays,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'reminderOn': reminderOn,
      'reminderMinutes': reminderMinutes,
      'cycleDays': cycleDays,
      'cycleTarget': cycleTarget,
      'cycleStartDate': cycleStartDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CheckInTask.fromMap(Map<String, dynamic> map) {
    return CheckInTask(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      repeatDays: List<int>.from(map['repeatDays'] as List),
      startMinutes: map['startMinutes'] as int?,
      endMinutes: map['endMinutes'] as int?,
      reminderOn: map['reminderOn'] as bool? ?? false,
      reminderMinutes: map['reminderMinutes'] as int?,
      cycleDays: map['cycleDays'] as int? ?? 1,
      cycleTarget: map['cycleTarget'] as int? ?? 1,
      cycleStartDate: map['cycleStartDate'] != null
          ? DateTime.parse(map['cycleStartDate'] as String)
          : DateTime.parse(map['createdAt'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// 计算第 [cycleIndex] 个周期的起止日期 (0-indexed, 0=first cycle)
  (DateTime start, DateTime end) cyclePeriod(int cycleIndex) {
    final start = DateTime(
      cycleStartDate.year,
      cycleStartDate.month,
      cycleStartDate.day,
    ).add(Duration(days: cycleIndex * cycleDays));
    final end = start.add(Duration(days: cycleDays - 1));
    return (start, end);
  }

  /// 今天属于第几个周期 (0-indexed)
  int get currentCycleIndex {
    final start = DateTime(
        cycleStartDate.year, cycleStartDate.month, cycleStartDate.day);
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    final diff = todayNormalized.difference(start).inDays;
    if (diff < 0) return 0;
    return diff ~/ cycleDays;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckInTask && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
