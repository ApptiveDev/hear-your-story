import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../onboarding/presentation/session.dart';
import '../domain/story.dart';
import 'stories_month_provider.dart';
import 'widgets/month_calendar.dart';
import 'widgets/story_card.dart';

/// 지난 이야기를 달력으로 찾는 화면. 달을 옮기며 날짜를 고르면 그날의 이야기가 보인다.
class StoriesCalendarPage extends ConsumerStatefulWidget {
  const StoriesCalendarPage({super.key, this.now});

  /// 테스트에서 "이번 달"을 고정할 때 쓴다.
  final DateTime Function()? now;

  @override
  ConsumerState<StoriesCalendarPage> createState() =>
      _StoriesCalendarPageState();
}

class _StoriesCalendarPageState extends ConsumerState<StoriesCalendarPage> {
  late final DateTime _thisMonth;
  late DateTime _month;
  final _selectedDays = <String, int>{}; // 달마다 고른 날짜

  @override
  void initState() {
    super.initState();
    // 계약의 month 기준 시간대는 Asia/Seoul이다.
    final seoul =
        widget.now?.call() ??
        DateTime.now().toUtc().add(const Duration(hours: 9));
    _thisMonth = DateTime(seoul.year, seoul.month);
    _month = _thisMonth;
  }

  String get _monthKey =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  void _moveMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

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

    return Scaffold(
      appBar: AppBar(title: const Text('달력으로 보기')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _MonthHeader(
              month: _month,
              onPrevious: () => _moveMonth(-1),
              onNext: _month.isBefore(_thisMonth) ? () => _moveMonth(1) : null,
            ),
            const SizedBox(height: 16),
            MonthCalendar(
              month: _month,
              storyDays: {for (final s in stories) s.assignedDate.day},
              selectedDay: selectedDay,
              onSelect: (day) => setState(() => _selectedDays[_monthKey] = day),
            ),
            const SizedBox(height: 24),
            month.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorRetryView(
                message: e is ApiException
                    ? e.userMessage
                    : '문제가 생겼어요. 다시 시도해 주세요.',
                onRetry: () => ref.invalidate(provider),
              ),
              data: (_) => _SelectedStories(
                stories: stories
                    .where((story) => story.assignedDate.day == selectedDay)
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
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
        IconButton(
          onPressed: onPrevious,
          tooltip: '이전 달',
          iconSize: 40,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          // 글씨를 키워도 "11"과 "월"이 줄바꿈으로 갈라지지 않게 한 줄로 둔다
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${month.year}년 ${month.month}월',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          tooltip: '다음 달',
          iconSize: 40,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _SelectedStories extends StatelessWidget {
  const _SelectedStories({required this.stories});
  final List<Story> stories;

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return Text(
        '이 달에는 모인 이야기가 없어요.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final story in stories)
          StoryCard(key: ValueKey(story.storyId), story: story),
      ],
    );
  }
}
