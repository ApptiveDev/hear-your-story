import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/step_layout.dart';
import '../domain/story.dart';
import '../../onboarding/data/auth_providers.dart';
import 'stories_controller.dart';
import 'stories_month_provider.dart';
import 'widgets/story_card.dart';

/// 질문 책장에서 고른 이야기 하나. 두 답과 듣기·내 답 지우기를 보여준다.
///
/// Figma WF-021·022 구성: 위에 질문, 가운데 `Note/Page` 공책.
/// 내 답 지우기는 공책 바로 아래, 듣기는 그 아래 내용 끝에 둔다(고정하지 않는다).
/// 질문 책장에서 오면 목록을, 달력에서 오면([month]) 그 달 데이터를 읽는다.
/// 이미 불러온 이야기를 읽으므로 따로 요청하지 않는다.
class StoryDetailPage extends ConsumerWidget {
  const StoryDetailPage({super.key, required this.storyId, this.month});
  final String storyId;

  /// 달력에서 열었을 때의 달 (`YYYY-MM`)
  final String? month;

  void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/stories');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = this.month;
    // 내 답을 지우면 목록은 카드만, 달력은 그 달을 다시 불러와 여기에도 반영된다
    final AsyncValue<List<Story>> stories = month == null
        ? ref.watch(storiesControllerProvider).whenData((s) => s.items)
        : ref.watch(storiesMonthProvider(month));
    final story = stories.value?.where((s) => s.storyId == storyId).firstOrNull;
    final role = ref.watch(currentUserProvider).value?.role;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StepLayout(
          onBack: () => _back(context),
          actions: const [],
          children: [
            if (story != null) ...[
              StoryCard(key: ValueKey(story.storyId), story: story),
              // 듣기는 아래 고정 영역이 아니라 내용 끝에 두어 스크롤해서 닿는다
              if (hasStoryAudio(story, role)) ...[
                const SizedBox(height: 24),
                StoryAudio(
                  key: ValueKey('audio_${story.storyId}'),
                  story: story,
                ),
              ],
            ] else if (stories.isLoading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              const SizedBox(height: 72),
              const Text(
                '이야기를 찾지 못했어요',
                textAlign: TextAlign.center,
                style: AppText.headingM,
              ),
              const SizedBox(height: 16),
              Text(
                month == null ? '질문 책장에서 다시 골라 주세요.' : '달력에서 다시 골라 주세요.',
                textAlign: TextAlign.center,
                style: AppText.bodyM.copyWith(color: AppColors.textSub),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
