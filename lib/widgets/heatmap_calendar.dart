import 'package:flutter/material.dart';

/// 月度打卡热力图 (日历样式)
class HeatmapCalendar extends StatelessWidget {
  final int year;
  final int month;
  final Map<int, int> dailyCounts; // day -> count

  const HeatmapCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.dailyCounts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1=Mon..7=Sun

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 星期标题
        Row(
          children: ['一', '二', '三', '四', '五', '六', '日']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        // 日期格子
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: daysInMonth + firstWeekday - 1,
          itemBuilder: (context, index) {
            final dayOffset = index - firstWeekday + 1;
            if (dayOffset < 1) return const SizedBox.shrink();
            if (dayOffset > daysInMonth) return const SizedBox.shrink();

            final count = dailyCounts[dayOffset] ?? 0;
            final color = _cellColor(count, theme);

            return Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '$dayOffset',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
                    color: count > 0 ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _cellColor(int count, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    if (count == 0) {
      return isDark ? const Color(0xFF2A2A3C) : const Color(0xFFF0F0F0);
    }
    final base = theme.colorScheme.primary;
    if (count == 1) return base.withValues(alpha: 0.35);
    if (count <= 3) return base.withValues(alpha: 0.55);
    if (count <= 5) return base.withValues(alpha: 0.75);
    return base;
  }
}
