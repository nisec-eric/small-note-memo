/// 打卡记录
class CheckInRecord {
  final String id;
  final String? taskId; // null for one-time check-ins
  final DateTime checkedAt;
  final String? topic; // one-time check-in topic (null for regular check-ins)
  final String? note; // optional note (display only)

  CheckInRecord({
    required this.id,
    this.taskId,
    DateTime? checkedAt,
    this.topic,
    this.note,
  }) : checkedAt = checkedAt ?? DateTime.now();

  /// 获取打卡日期 (去掉时分秒)
  DateTime get date => DateTime(
        checkedAt.year,
        checkedAt.month,
        checkedAt.day,
      );

  /// 序列化为 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'checkedAt': checkedAt.toIso8601String(),
      'topic': topic,
      'note': note,
    };
  }

  factory CheckInRecord.fromMap(Map<String, dynamic> map) {
    return CheckInRecord(
      id: map['id'] as String,
      taskId: map['taskId'] as String?,
      checkedAt: DateTime.parse(map['checkedAt'] as String),
      topic: map['topic'] as String?,
      note: map['note'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckInRecord && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
