import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 月度打卡热力图 (日历样式，支持月份切换 + 点击查看详情)
class HeatmapCalendar extends StatelessWidget {
  final int year;
  final int month;
  final Map<int, int> dailyCounts; // day -> count
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
  final ValueChanged<int>? onDayTap; // callback with day number

  const HeatmapCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.dailyCounts,
    this.onPreviousMonth,
    this.onNextMonth,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1=Mon..7=Sun
    final monthLabel = DateFormat('y年M月', 'zh_CN').format(DateTime(year, month));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 月份导航
        Row(
          children: [
            IconButton(
              onPressed: onPreviousMonth,
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Expanded(
              child: Center(
                child: Text(
                  monthLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onNextMonth,
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 星期标题
        Row(
          children: ['一', '二', '三', '四', '五', '六', '日']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        // 日期格子
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: daysInMonth + firstWeekday - 1,
          itemBuilder: (context, index) {
            final dayOffset = index - firstWeekday + 1;
            if (dayOffset < 1) return const SizedBox.shrink();
            if (dayOffset > daysInMonth) return const SizedBox.shrink();

            final count = dailyCounts[dayOffset] ?? 0;
            final color = _cellColor(count, theme);
            final isToday = _isToday(dayOffset);

            return GestureDetector(
              onTap: onDayTap != null ? () => onDayTap!(dayOffset) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  border: isToday
                      ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$dayOffset',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
                      color: count > 0
                          ? Colors.white
                          : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  bool _isToday(int day) {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  Color _cellColor(int count, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    if (count == 0) {
      return isDark ? const Color(0xFF2A2A3C) : const Color(0xFFF0F0F0);
    }
    final base = theme.colorScheme.primary;
    if (count == 1) return base.withValues(alpha: 0.35);
    if (count <= 3) return base.withValues(alpha: 0.55);
    return base.withValues(alpha: 0.75);
  }
}
