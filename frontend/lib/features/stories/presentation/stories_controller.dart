import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/stories_providers.dart';
import '../domain/story.dart';
import '../../../core/network/retry_policy.dart';

/// 지금까지 불러온 이야기 목록과 다음 페이지 상태
class StoriesState {
  const StoriesState({
    required this.items,
    required this.nextCursor,
    required this.hasNext,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  factory StoriesState.fromPage(StoryPage page) => StoriesState(
    items: page.items,
    nextCursor: page.nextCursor,
    hasNext: page.hasNext,
  );

  final List<Story> items;
  final String? nextCursor;
  final bool hasNext;

  /// 다음 페이지를 불러오는 중
  final bool isLoadingMore;

  /// 다음 페이지 불러오기 실패 (목록은 그대로 두고 아래에 다시 시도 버튼)
  final bool loadMoreFailed;
}

class StoriesController extends AsyncNotifier<StoriesState> {
  @override
  Future<StoriesState> build() async {
    final page = await ref.read(storiesRepositoryProvider).fetchPage();
    return StoriesState.fromPage(page);
  }

  /// 서명 URL이 만료됐을 때 새 URL을 받기 위해 해당 이야기를 다시 찾는다.
  /// 목록 state는 바꾸지 않는다(재생 중인 카드가 다시 그려지지 않게).
  Future<StoryParentAnswer> fetchLatestParentAnswer(String storyId) async {
    final repo = ref.read(storiesRepositoryProvider);
    String? cursor;
    while (true) {
      final page = await repo.fetchPage(cursor: cursor);
      for (final story in page.items) {
        if (story.storyId == storyId) return story.parentAnswer;
      }
      if (!page.hasNext) break;
      cursor = page.nextCursor;
    }
    throw StateError('이야기를 다시 찾지 못했어요');
  }

  /// 불러온 목록에서 이야기 하나만 바꾼다.
  /// 내 답을 지운 뒤 목록을 처음부터 다시 불러오지 않고 그 카드만 반영한다.
  void replaceStory(String storyId, Story Function(Story story) update) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      StoriesState(
        items: [
          for (final story in current.items)
            story.storyId == storyId ? update(story) : story,
        ],
        nextCursor: current.nextCursor,
        hasNext: current.hasNext,
        isLoadingMore: current.isLoadingMore,
        loadMoreFailed: current.loadMoreFailed,
      ),
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNext || current.isLoadingMore) return;

    state = AsyncData(
      StoriesState(
        items: current.items,
        nextCursor: current.nextCursor,
        hasNext: current.hasNext,
        isLoadingMore: true,
      ),
    );

    try {
      final page = await ref
          .read(storiesRepositoryProvider)
          .fetchPage(cursor: current.nextCursor);
      if (!ref.mounted) return; // 기다리는 사이 화면이 닫혔으면 무시
      state = AsyncData(
        StoriesState(
          // 기다리는 사이 지운 카드가 되살아나지 않게 지금 목록에 붙인다
          items: [...(state.value?.items ?? current.items), ...page.items],
          nextCursor: page.nextCursor,
          hasNext: page.hasNext,
        ),
      );
    } on ApiException catch (e, st) {
      if (!ref.mounted) return;
      // 로그인 만료는 화면이 가입 화면으로 보내도록 에러 상태로 둔다
      if (e.statusCode == 401) {
        state = AsyncError(e, st);
        return;
      }
      state = AsyncData(
        StoriesState(
          items: state.value?.items ?? current.items,
          nextCursor: current.nextCursor,
          hasNext: current.hasNext,
          loadMoreFailed: true,
        ),
      );
    }
  }
}

final storiesControllerProvider =
    AsyncNotifierProvider.autoDispose<StoriesController, StoriesState>(
      StoriesController.new,
      // Riverpod 3 기본 재시도 대신, 일시적인 오류만 다시 시도한다.
      retry: retryTransientOnly,
    );
