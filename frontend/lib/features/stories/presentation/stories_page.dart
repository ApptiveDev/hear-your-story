import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../onboarding/presentation/session.dart';
import 'stories_controller.dart';
import 'widgets/story_card.dart';

class StoriesPage extends ConsumerWidget {
  const StoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(storiesControllerProvider, (_, next) {
      final e = next.error;
      if (e != null) handleSessionExpired(context, ref, e);
    });

    final stories = ref.watch(storiesControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('지난 이야기'),
        actions: [
          if (AppConfig.storiesMonthApi)
            TextButton.icon(
              // push: 카드의 음성 새로고침이 이 화면의 목록 provider를 쓴다.
              onPressed: () => context.push('/stories/calendar'),
              icon: const Icon(Icons.calendar_month),
              label: const Text('달력'),
            ),
        ],
      ),
      body: SafeArea(
        child: stories.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetryView(
            message: e is ApiException
                ? e.userMessage
                : '문제가 생겼어요. 다시 시도해 주세요.',
            onRetry: () => ref.invalidate(storiesControllerProvider),
          ),
          data: (state) => RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: state.items.isEmpty
                ? const _EmptyView()
                : _StoryList(state: state),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    try {
      ref.invalidate(storiesControllerProvider);
      await ref.read(storiesControllerProvider.future);
    } catch (_) {
      // 실패하면 화면이 에러 상태로 바뀌므로 여기서는 따로 처리하지 않는다.
    }
  }
}

class _StoryList extends ConsumerWidget {
  const _StoryList({required this.state});
  final StoriesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // 바닥에서 400px 안쪽까지 내려오면 다음 페이지를 미리 불러온다.
        if (n.metrics.extentAfter < 400 && !state.loadMoreFailed) {
          ref.read(storiesControllerProvider.notifier).loadMore();
        }
        return false;
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: state.items.length + 1, // 마지막 칸은 footer
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, i) {
          if (i < state.items.length) return StoryCard(story: state.items[i]);
          return _Footer(state: state);
        },
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.state});
  final StoriesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!state.hasNext) return const SizedBox(height: 24);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          if (state.loadMoreFailed) ...[
            Text(
              '이야기를 더 불러오지 못했어요.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: () =>
                ref.read(storiesControllerProvider.notifier).loadMore(),
            child: Text(state.loadMoreFailed ? '다시 불러오기' : '이전 이야기 더 보기'),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // RefreshIndicator가 동작하려면 빈 화면도 스크롤 가능해야 한다.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.auto_stories_outlined, size: 64),
        const SizedBox(height: 16),
        Text(
          '아직 모인 이야기가 없어요.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          '두 분이 모두 답한 이야기가 여기에 차곡차곡 모여요.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}
