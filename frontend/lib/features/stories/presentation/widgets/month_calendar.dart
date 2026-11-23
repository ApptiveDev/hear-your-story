import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// Figma `Calendar/Month`: 한 달 달력. 이야기가 있는 날만 누를 수 있다.
///
/// 날짜 칸(`Calendar/Day`) 상태: 이야기 있음(크림 원·굵은 글자·점), 고름(주황 원),
/// 오늘(갈색 테두리), 앞으로 올 날(흐린 글자), 불러오는 중(빈 회색 원).
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.storyDays,
    required this.selectedDay,
    required this.onSelect,
    this.today,
    this.skeleton = false,
  });

  /// 표시할 달의 1일
  final DateTime month;
  final Set<int> storyDays;
  final int? selectedDay;
  final ValueChanged<int> onSelect;

  /// 오늘 날짜. 이 달이 아니면 null이고, 이후 날짜를 흐리게 그리는 기준이 된다.
  final DateTime? today;

  /// 이 달을 불러오는 중이거나 불러오지 못했을 때 모든 날짜를 회색 원으로 그린다.
  final bool skeleton;

  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = month.weekday % 7; // 일요일부터 시작
    final weeks = ((leading + daysInMonth) / 7).ceil();

    return Column(
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              for (final weekday in _weekdays)
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      weekday,
                      style: AppText.labelM.copyWith(color: AppColors.textSub),
                    ),
                  ),
                ),
            ],
          ),
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
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 56);
    final today = this.today;
    final isToday =
        today != null &&
        today.year == month.year &&
        today.month == month.month &&
        today.day == day;
    final future =
        today != null &&
        DateTime(
          month.year,
          month.month,
          day,
        ).isAfter(DateTime(today.year, today.month, today.day));
    return _DayCell(
      month: month.month,
      day: day,
      hasStory: !skeleton && storyDays.contains(day),
      selected: !skeleton && day == selectedDay,
      isToday: !skeleton && isToday,
      future: !skeleton && future,
      skeleton: skeleton,
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
    required this.isToday,
    required this.future,
    required this.skeleton,
    required this.onTap,
  });

  final int month;
  final int day;
  final bool hasStory;
  final bool selected;
  final bool isToday;
  final bool future;
  final bool skeleton;
  final VoidCallback onTap;

  static const circle = 40.0;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color textColor;
    if (selected) {
      fill = AppColors.actionPrimary;
      textColor = AppColors.textOnPrimary;
    } else if (skeleton) {
      fill = AppColors.borderSoft;
      textColor = AppColors.textStrong;
    } else if (hasStory) {
      fill = AppColors.surfaceCard;
      textColor = AppColors.textStrong;
    } else {
      fill = Colors.transparent;
      textColor = future ? AppColors.borderDisabled : AppColors.textStrong;
    }
    final bold = hasStory || selected || isToday;

    return Semantics(
      button: hasStory,
      selected: selected,
      excludeSemantics: true, // 안쪽 InkWell의 탭도 지워지므로 여기에 다시 연결한다
      onTap: hasStory ? onTap : null,
      label: '$month월 $day일${hasStory ? ', 이야기 있음' : ''}',
      child: InkWell(
        onTap: hasStory ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: circle,
                height: circle,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: isToday && !selected
                      ? Border.all(color: AppColors.actionPrimaryDark, width: 2)
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$day',
                    style: AppText.bodyM.copyWith(
                      color: textColor,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // 색만으로 구분하지 않도록 점도 찍는다. 칸 높이는 같게 둔다.
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasStory
                      ? AppColors.actionPrimaryDark
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
