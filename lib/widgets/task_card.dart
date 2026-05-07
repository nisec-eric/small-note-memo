import 'package:flutter/material.dart';

import '../models/task.dart';

/// 任务颜色池 — 根据索引自动分配颜色
class TaskColors {
  static const _palette = [
    Color(0xFFFF6B6B), // 珊瑚红
    Color(0xFF4ECDC4), // 青绿
    Color(0xFFFFBE0B), // 琥珀黄
    Color(0xFF845EF7), // 紫罗兰
    Color(0xFF51CF66), // 翠绿
    Color(0xFF339AF0), // 天蓝
    Color(0xFFF06595), // 玫粉
    Color(0xFFFF922B), // 橙色
  ];

  static Color forIndex(int index) => _palette[index % _palette.length];
}

/// 打卡任务卡片
class TaskCard extends StatelessWidget {
  final CheckInTask task;
  final bool checkedIn;
  final VoidCallback onCheckIn;
  final VoidCallback? onLongPress;
  final int colorIndex;
  final (int, int, DateTime, DateTime)? cycleProgress; // (completed, remaining, periodStart, periodEnd)
  final int cycleDays;

  const TaskCard({
    super.key,
    required this.task,
    required this.checkedIn,
    required this.onCheckIn,
    this.onLongPress,
    this.colorIndex = 0,
    this.cycleProgress,
    this.cycleDays = 1,
  });

  @override
  Widget build(BuildContext context) {
    final color = TaskColors.forIndex(colorIndex);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: checkedIn ? null : onCheckIn,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: checkedIn
                      ? color.withValues(alpha: 0.15)
                      : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    task.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: checkedIn ? TextDecoration.lineThrough : null,
                        color: checkedIn
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.timeWindowText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.repeat_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.repeatText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    if (cycleProgress != null &&
                        (cycleDays > 1 || task.cycleTarget > 1)) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '本周期 ${cycleProgress!.$1}/${task.cycleTarget}次',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          if (cycleDays > 1) ...[
                            const Spacer(),
                            Builder(builder: (context) {
                              final remainingDays = cycleProgress!.$4
                                      .difference(DateTime.now())
                                      .inDays +
                                  1;
                              if (remainingDays > 0) {
                                return Text(
                                  '剩余$remainingDays天',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (cycleProgress!.$1 / task.cycleTarget)
                              .clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor:
                              color.withValues(alpha: 0.12),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 打卡按钮
              _CheckInButton(
                checkedIn: checkedIn,
                color: color,
                onTap: onCheckIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckInButton extends StatefulWidget {
  final bool checkedIn;
  final Color color;
  final VoidCallback onTap;

  const _CheckInButton({
    required this.checkedIn,
    required this.color,
    required this.onTap,
  });

  @override
  State<_CheckInButton> createState() => _CheckInButtonState();
}

class _CheckInButtonState extends State<_CheckInButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(covariant _CheckInButton old) {
    super.didUpdateWidget(old);
    if (!old.checkedIn && widget.checkedIn) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.checkedIn ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: widget.checkedIn ? widget.color : Colors.transparent,
            shape: BoxShape.circle,
            border: widget.checkedIn
                ? null
                : Border.all(color: widget.color, width: 2.5),
          ),
          child: widget.checkedIn
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 26)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
