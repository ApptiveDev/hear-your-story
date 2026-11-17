import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_tokens.dart';
import '../../onboarding/presentation/session.dart';
import '../domain/story.dart';
import 'stories_month_provider.dart';
import 'widgets/month_calendar.dart';

/// Figma 달력(WF-029 ~ WF-032). 달을 옮기며 날짜를 고르면 그날의 이야기가 보인다.
/// 이야기를 누르면 이야기 상세에서 두 답과 듣기·지우기를 본다.
class StoriesCalendarPage extends ConsumerStatefulWidget {
  const StoriesCalendarPage({super.key, this.now});

  /// 테스트에서 "오늘"을 고정할 때 쓴다.
  final DateTime Function()? now;

  @override
  ConsumerState<StoriesCalendarPage> createState() =>
      _StoriesCalendarPageState();
}

class _StoriesCalendarPageState extends ConsumerState<StoriesCalendarPage> {
  late final DateTime _today;
  late final DateTime _thisMonth;
  late DateTime _month;
  final _selectedDays = <String, int>{}; // 달마다 고른 날짜

  @override
  void initState() {
    super.initState();
    // 계약의 month 기준 시간대는 Asia/Seoul이다.
    _today =
        widget.now?.call() ??
        DateTime.now().toUtc().add(const Duration(hours: 9));
    _thisMonth = DateTime(_today.year, _today.month);
    _month = _thisMonth;
  }

  String get _monthKey => monthKey(_month);

  void _moveMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _goThisMonth() => setState(() => _month = _thisMonth);

  /// 이 달에서 고른 날짜. 고른 적이 없으면 가장 최근 이야기를 보여준다.
  int? _selectedDay(List<Story> stories) {
    if (stories.isEmpty) return null;
    return _selectedDays[_monthKey] ??
        stories
            .map((story) => story.assignedDate.day)
            .reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final provider = storiesMonthProvider(_monthKey);
    ref.listen(provider, (_, next) {
      final e = next.error;
      if (e != null) handleSessionExpired(context, ref, e);
    });

    final month = ref.watch(provider);
    final stories = month.value ?? const <Story>[];
    final selectedDay = _selectedDay(stories);
    final ready = month.hasValue && !month.isLoading;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            32,
            AppSizes.screenPadding,
            AppSizes.screenPadding,
          ),
          children: [
            Semantics(
              header: true,
              child: const Text('달력', style: AppText.headingXL),
            ),
            const SizedBox(height: 16),
            _MonthNav(
              month: _month,
              onPrevious: () => _moveMonth(-1),
              onNext: _month.isBefore(_thisMonth) ? () => _moveMonth(1) : null,
            ),
            const SizedBox(height: 16),
            MonthCalendar(
              month: _month,
              storyDays: {for (final s in stories) s.assignedDate.day},
              selectedDay: selectedDay,
              today: _today,
              skeleton: !ready,
              onSelect: (day) => setState(() => _selectedDays[_monthKey] = day),
            ),
            const SizedBox(height: 24),
            month.when(
              skipLoadingOnRefresh: false,
              loading: () => Semantics(
                liveRegion: true,
                child: const Text('달력을 불러오고 있어요', style: AppText.bodyS),
              ),
              error: (_, _) =>
                  _ErrorCard(onRetry: () => ref.invalidate(provider)),
              data: (_) => selectedDay == null
                  ? _EmptyMonth(
                      onThisMonth: _month == _thisMonth ? null : _goThisMonth,
                    )
                  : _SelectedDay(
                      month: _month,
                      day: selectedDay,
                      stories: stories
                          .where((s) => s.assignedDate.day == selectedDay)
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 예: 2026-11
String monthKey(DateTime month) =>
    '${month.year}-${month.month.toString().padLeft(2, '0')}';

/// Figma `Calendar/Nav`: 둥근 이전·다음 버튼 사이에 연·월
class _MonthNav extends StatelessWidget {
  const _MonthNav({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;

  /// 이번 달이면 null이라 앞으로 가지 못한다.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NavButton(
          icon: AppIcons.arrowLeft,
          tooltip: '이전 달',
          onPressed: onPrevious,
        ),
        Expanded(
          // 글씨를 키워도 "11"과 "월"이 줄바꿈으로 갈라지지 않게 한 줄로 둔다
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${month.year}년 ${month.month}월',
              style: AppText.headingM,
            ),
          ),
        ),
        _NavButton(
          icon: AppIcons.arrowRight,
          tooltip: '다음 달',
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 24),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(48),
        backgroundColor: AppColors.surfaceWhite,
        disabledBackgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.textBrand,
        disabledForegroundColor: AppColors.borderSoft,
        side: BorderSide(
          color: enabled ? AppColors.borderSoft : AppColors.bgUnder,
          width: 2,
        ),
      ),
    );
  }
}

/// Figma WF-029 아래: `12일  11월 12일의 이야기`와 이야기 카드
class _SelectedDay extends StatelessWidget {
  const _SelectedDay({
    required this.month,
    required this.day,
    required this.stories,
  });

  final DateTime month;
  final int day;
  final List<Story> stories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 10,
            children: [
              Text('$day일', style: AppText.headingXL),
              Text(
                '${month.month}월 $day일의 이야기',
                style: AppText.bodyM.copyWith(color: AppColors.textSub),
              ),
            ],
          ),
        ),
        for (final story in stories) ...[
          const SizedBox(height: 12),
          _StoryRow(story: story, month: monthKey(month)),
        ],
      ],
    );
  }
}

/// Figma `Card/Record`: 날짜 상자와 질문. 누르면 이야기 상세로 간다.
class _StoryRow extends StatelessWidget {
  const _StoryRow({required this.story, required this.month});
  final Story story;

  /// 상세가 같은 달 데이터를 읽도록 넘긴다.
  final String month;

  @override
  Widget build(BuildContext context) {
    final day = story.assignedDate.day;
    final radius = BorderRadius.circular(AppRadius.cardSmall);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: AppColors.bgUnder,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/stories/${story.storyId}?month=$month'),
          child: Semantics(
            button: true,
            label: '$day일, ${story.questionText}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppRadius.codeCell),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        children: [
                          Text(
                            '$day',
                            style: AppText.headingL.copyWith(
                              color: AppColors.textBrand,
                            ),
                          ),
                          Text(
                            '일',
                            style: AppText.labelM.copyWith(
                              color: AppColors.textBrand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      story.questionText,
                      style: AppText.bodyM.copyWith(
                        color: AppColors.textStrong,
                      ),
                    ),
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

/// Figma WF-031 빈 달
class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth({required this.onThisMonth});

  /// 이번 달이면 null이라 버튼을 그리지 않는다.
  final VoidCallback? onThisMonth;

  @override
  Widget build(BuildContext context) {
    final onThisMonth = this.onThisMonth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: const Text(
            '이 달에는 아직 이야기가 없어요',
            textAlign: TextAlign.center,
            style: AppText.headingM,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '다른 달의 이야기를 둘러볼까요?',
          textAlign: TextAlign.center,
          style: AppText.bodyM.copyWith(color: AppColors.textSub),
        ),
        if (onThisMonth != null) ...[
          const SizedBox(height: 32),
          FilledButton(onPressed: onThisMonth, child: const Text('이번 달로 가기')),
        ],
      ],
    );
  }
}

/// Figma WF-032 월 조회 오류
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        border: Border.all(color: AppColors.borderSoft, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: const Text(
              '달력을 불러오지 못했어요',
              textAlign: TextAlign.center,
              style: AppText.headingM,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '선택한 달은 그대로예요',
            textAlign: TextAlign.center,
            style: AppText.bodyS,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.buttonM),
              textStyle: AppText.buttonM,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.buttonM),
              ),
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
