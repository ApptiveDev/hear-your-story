import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// 한 달 달력. 이야기가 있는 날만 누를 수 있다.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.storyDays,
    required this.selectedDay,
    required this.onSelect,
  });

  /// 표시할 달의 1일
  final DateTime month;
  final Set<int> storyDays;
  final int? selectedDay;
  final ValueChanged<int> onSelect;

  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = month.weekday % 7; // 일요일부터 시작
    final weeks = ((leading + daysInMonth) / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            for (final weekday in _weekdays)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    weekday,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var week = 0; week < weeks; week++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: _dayAt(week * 7 + column - leading + 1, daysInMonth),
                ),
            ],
          ),
      ],
    );
  }

  Widget _dayAt(int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
    return _DayCell(
      month: month.month,
      day: day,
      hasStory: storyDays.contains(day),
      selected: day == selectedDay,
      onTap: () => onSelect(day),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.month,
    required this.day,
    required this.hasStory,
    required this.selected,
    required this.onTap,
  });

  final int month;
  final int day;
  final bool hasStory;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.bg : AppColors.font;
    return Semantics(
      button: hasStory,
      selected: selected,
      excludeSemantics: true, // 안쪽 InkWell의 탭도 지워지므로 여기에 다시 연결한다
      onTap: hasStory ? onTap : null,
      label: '$month월 $day일${hasStory ? ', 이야기 있음' : ''}',
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: selected
              ? AppColors.font
              : hasStory
              ? AppColors.card
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: hasStory ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$day',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: hasStory ? color : AppColors.dark,
                        fontWeight: hasStory ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                  // 색만으로 구분하지 않도록 점도 찍는다. 칸 높이는 같게 둔다.
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: hasStory ? color : Colors.transparent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
