import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_tokens.dart';
import '../../onboarding/presentation/session.dart';
import '../domain/story.dart';
import 'stories_controller.dart';

/// Figma 질문 책장(WF-024 ~ WF-028): 공개된 이야기를 달마다 겹친 카드로 모은다.
///
/// 카드를 누르면 이야기 상세(`/stories/:storyId`)에서 두 답과 듣기·지우기를 본다.
class StoriesPage extends ConsumerWidget {
  const StoriesPage({super.key});

  static const title = '질문 책장';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(storiesControllerProvider, (_, next) {
      final e = next.error;
      if (e != null) handleSessionExpired(context, ref, e);
    });

    final stories = ref.watch(storiesControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: stories.when(
          loading: () => const _Skeleton(),
          error: (e, _) => _ErrorView(
            message: e is ApiException ? e.userMessage : null,
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

/// 화면 위 `질문 책장` 제목 (Figma `Title/Tab`)
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: const Text(StoriesPage.title, style: AppText.headingXL),
  );
}

const _padding = EdgeInsets.fromLTRB(
  AppSizes.screenPadding,
  32,
  AppSizes.screenPadding,
  AppSizes.screenPadding,
);

/// 같은 달 이야기 묶음. 목록은 최신순이라 달도 최신 달부터 나온다.
class StoryMonth {
  const StoryMonth(this.year, this.month, this.stories);
  final int year;
  final int month;
  final List<Story> stories;
}

/// 목록 순서를 지키며 달별로 묶는다.
List<StoryMonth> groupByMonth(List<Story> stories) {
  final groups = <StoryMonth>[];
  for (final story in stories) {
    final d = story.assignedDate;
    final last = groups.isEmpty ? null : groups.last;
    if (last != null && last.year == d.year && last.month == d.month) {
      last.stories.add(story);
    } else {
      groups.add(StoryMonth(d.year, d.month, [story]));
    }
  }
  return groups;
}

class _StoryList extends ConsumerWidget {
  const _StoryList({required this.state});
  final StoriesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = groupByMonth(state.items);
    final thisYear = DateTime.now().year;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // 바닥에서 400px 안쪽까지 내려오면 다음 페이지를 미리 불러온다.
        if (n.metrics.extentAfter < 400 && !state.loadMoreFailed) {
          ref.read(storiesControllerProvider.notifier).loadMore();
        }
        return false;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _padding,
        children: [
          const _Title(),
          for (final month in months) ...[
            const SizedBox(height: 32),
            _MonthHeader(
              label: month.year == thisYear
                  ? '${month.month}월'
                  : '${month.year}년 ${month.month}월',
              count: month.stories.length,
            ),
            const SizedBox(height: 12),
            _CardStack(stories: month.stories),
          ],
          const SizedBox(height: 24),
          _Footer(state: state),
        ],
      ),
    );
  }
}

/// Figma `Month/Header`: `11월  4개의 이야기`
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 10,
        children: [
          Text(label, style: AppText.headingXL),
          Text(
            '$count개의 이야기',
            style: AppText.bodyM.copyWith(color: AppColors.textSub),
          ),
        ],
      ),
    );
  }
}

/// Figma `Stack`: 카드가 아래로 겹쳐 쌓인 묶음. 뒤 카드가 앞 카드 아래쪽을 덮는다.
class _CardStack extends StatelessWidget {
  const _CardStack({required this.stories});
  final List<Story> stories;

  /// 글씨 크기 1배에서 다음 카드에 덮이지 않고 보이는 높이 (150 - 52)
  static const visible = 98.0;

  /// 다음 카드가 덮는 높이. 글씨를 키워도 겹친 모양은 같게 둔다.
  static const overlap = 52.0;
  static const colors = [
    AppColors.surfaceCard,
    AppColors.cardStack,
    AppColors.actionPrimaryLight,
  ];

  @override
  Widget build(BuildContext context) {
    // 글씨를 키우면 질문 두 줄과 날짜 상자도 커지므로 보이는 부분을 같이 늘린다.
    // 그렇지 않으면 다음 카드가 질문 아래쪽을 덮는다.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 4.0);
    final shown = visible * scale;
    final height = shown + overlap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, story) in stories.indexed)
          if (i < stories.length - 1)
            SizedBox(
              height: shown,
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: height,
                maxHeight: height,
                child: _StackCard(story: story, color: colors[i % 3]),
              ),
            )
          else
            SizedBox(
              height: height,
              child: _StackCard(story: story, color: colors[i % 3]),
            ),
      ],
    );
  }
}

/// Figma `Card/Stack`: 날짜 상자와 질문
class _StackCard extends StatelessWidget {
  const _StackCard({required this.story, required this.color});
  final Story story;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final day = story.assignedDate.day;
    final radius = BorderRadius.circular(AppRadius.cardSmall);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppShadows.stack,
      ),
      child: Material(
        color: color,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/stories/${story.storyId}'),
          child: Semantics(
            button: true,
            label: '${story.assignedDate.month}월 $day일, ${story.questionText}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

/// 목록 끝: 더 불러오는 중 / 더 보기 / Figma WF-027 더 보기 실패
class _Footer extends ConsumerWidget {
  const _Footer({required this.state});
  final StoriesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void loadMore() => ref.read(storiesControllerProvider.notifier).loadMore();
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!state.hasNext) return const SizedBox.shrink();
    if (!state.loadMoreFailed) {
      // 화면이 짧아 스크롤로 불러오지 못할 때를 위해 남겨 둔다
      return TextButton(onPressed: loadMore, child: const Text('이전 이야기 더 보기'));
    }
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
              '이야기를 더 불러오지 못했어요',
              textAlign: TextAlign.center,
              style: AppText.headingM,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '위의 이야기는 그대로 있어요',
            textAlign: TextAlign.center,
            style: AppText.bodyS,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: loadMore,
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

/// Figma WF-024 목록 로딩: 자리만 잡아 둔 회색 카드
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height, Color color) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
    return ListView(
      padding: _padding,
      children: [
        const _Title(),
        const SizedBox(height: 32),
        Semantics(
          liveRegion: true,
          child: const Text('이야기를 불러오고 있어요', style: AppText.bodyS),
        ),
        const SizedBox(height: 32),
        ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  bar(80, 30, AppColors.borderSoft),
                  const SizedBox(width: 10),
                  bar(110, 16, AppColors.borderSoft),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < 4; i++)
                Container(
                  height: 98,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppRadius.cardSmall),
                    boxShadow: AppShadows.stack,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        height: 66,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(
                            AppRadius.codeCell,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            bar(double.infinity, 16, AppColors.borderSoft),
                            const SizedBox(height: 12),
                            bar(150, 16, AppColors.borderSoft),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Figma WF-025 빈 목록
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    // RefreshIndicator가 동작하려면 빈 화면도 스크롤 가능해야 한다.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _padding,
      children: [
        const _Title(),
        const SizedBox(height: 72),
        const ExcludeSemantics(child: _GhostStack()),
        const SizedBox(height: 24),
        const Text(
          '아직 공개된 이야기가 없어요',
          textAlign: TextAlign.center,
          style: AppText.headingM,
        ),
        const SizedBox(height: 16),
        Text(
          '오늘의 질문에 이야기를 남기면\n여기에 차곡차곡 쌓여요',
          textAlign: TextAlign.center,
          style: AppText.bodyM.copyWith(color: AppColors.textSub),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => context.go('/today'),
          child: const Text('오늘의 질문 보러 가기'),
        ),
      ],
    );
  }
}

/// Figma `Stack/Ghost`: 점선으로 그린 빈 카드 두 장
class _GhostStack extends StatelessWidget {
  const _GhostStack();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 248,
      child: CustomPaint(painter: _GhostPainter()),
    );
  }
}

class _GhostPainter extends CustomPainter {
  const _GhostPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textBrand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const radius = Radius.circular(AppRadius.cardSmall);
    for (final top in [0.0, 98.0]) {
      final rect = Rect.fromLTWH(1, top + 1, size.width - 2, 148);
      _dashed(
        canvas,
        Path()..addRRect(RRect.fromRectAndRadius(rect, radius)),
        paint,
      );
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Figma WF-028 전체 오류
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  /// 서버나 연결 상태에 따른 안내. 없으면 기본 안내를 쓴다.
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _padding,
      children: [
        const _Title(),
        const SizedBox(height: 120),
        const Icon(AppIcons.smileWink, size: 72, color: AppColors.textBrand),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: const Text(
            '이야기를 불러오지 못했어요',
            textAlign: TextAlign.center,
            style: AppText.headingM,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${message ?? '잠시 후 다시 불러와 주세요.'}\n지금까지의 이야기는 사라지지 않았어요.',
          textAlign: TextAlign.center,
          style: AppText.bodyM.copyWith(color: AppColors.textSub),
        ),
        const SizedBox(height: 32),
        FilledButton(onPressed: onRetry, child: const Text('다시 불러오기')),
      ],
    );
  }
}
