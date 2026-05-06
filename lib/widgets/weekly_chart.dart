import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 周打卡柱状图
class WeeklyChart extends StatefulWidget {
  final List<int> weeklyCounts; // 长度7: 6天前..今天

  const WeeklyChart({super.key, required this.weeklyCounts});

  @override
  State<WeeklyChart> createState() => _WeeklyChartState();
}

class _WeeklyChartState extends State<WeeklyChart> {
  int _touchedIndex = -1;

  static const _weekdayLabels = ['', '一', '二', '三', '四', '五', '六', '日'];

  /// 根据 bar 索引获取对应的星期标签
  /// counts[0] = 6天前, counts[6] = 今天
  String _dayLabel(int barIndex) {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: 6 - barIndex));
    return _weekdayLabels[date.weekday]; // weekday: 1=Mon..7=Sun
  }

  @override
  Widget build(BuildContext context) {
    final maxY = _calcMaxY();
    final theme = Theme.of(context);
    final barColor = theme.colorScheme.primary;

    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            touchCallback: (event, response) {
              setState(() {
                _touchedIndex = (response != null && event.isInterestedForInteractions)
                    ? response.spot?.touchedBarGroupIndex ?? -1
                    : -1;
              });
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) =>
                  theme.brightness == Brightness.dark
                      ? const Color(0xFF374151)
                      : const Color(0xFF2D2D2D),
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.toInt()} 次',
                  TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= 7) return const SizedBox.shrink();
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      _dayLabel(idx),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: idx == _touchedIndex
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: idx == _touchedIndex
                            ? barColor
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: List.generate(7, (i) => _buildGroup(i, widget.weeklyCounts[i].toDouble(), barColor)),
        ),
        duration: const Duration(milliseconds: 250),
      ),
    );
  }

  double _calcMaxY() {
    if (widget.weeklyCounts.isEmpty) return 5;
    final max = widget.weeklyCounts.reduce((a, b) => a > b ? a : b);
    return (max + 2).toDouble().clamp(3, 30);
  }

  BarChartGroupData _buildGroup(int x, double y, Color color) {
    final isTouched = x == _touchedIndex;
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: isTouched ? y + 0.5 : y,
          color: color.withValues(alpha: isTouched ? 1.0 : 0.75),
          width: 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: _calcMaxY(),
            color: color.withValues(alpha: 0.08),
          ),
        ),
      ],
      showingTooltipIndicators: isTouched ? [0] : [],
    );
  }
}
