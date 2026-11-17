import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/retry_policy.dart';
import '../data/stories_providers.dart';
import '../domain/story.dart';

/// 달력 한 달치 이야기. 인자는 `YYYY-MM`.
final storiesMonthProvider = AsyncNotifierProvider.autoDispose
    .family<StoriesMonth, List<Story>, String>(
      StoriesMonth.new,
      retry: retryTransientOnly,
    );

class StoriesMonth extends AsyncNotifier<List<Story>> {
  StoriesMonth(this.month);
  final String month;

  @override
  Future<List<Story>> build() =>
      ref.read(storiesRepositoryProvider).fetchMonth(month);

  /// 불러온 달에서 이야기 하나만 바꾼다.
  /// 내 답을 지운 뒤 다시 불러오지 않아도, 실패해도 바로 반영되게 한다.
  void replaceStory(String storyId, Story Function(Story story) update) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final story in current)
        story.storyId == storyId ? update(story) : story,
    ]);
  }
}

/// 예: 2026-11
String monthKey(DateTime month) =>
    '${month.year}-${month.month.toString().padLeft(2, '0')}';
