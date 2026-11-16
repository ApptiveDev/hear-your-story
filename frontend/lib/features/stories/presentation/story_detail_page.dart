import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/step_layout.dart';
import 'stories_controller.dart';
import 'widgets/story_card.dart';

/// 질문 책장에서 고른 이야기 하나. 두 답과 듣기·내 답 지우기를 보여준다.
///
/// Figma에 상세 화면 시안이 없어 `Note/Page` 모양의 이야기 카드를 그대로 쓴다.
/// 목록 provider에 이미 불러온 이야기를 읽으므로 따로 요청하지 않는다.
class StoryDetailPage extends ConsumerWidget {
  const StoryDetailPage({super.key, required this.storyId});
  final String storyId;

  void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/stories');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = ref.watch(storiesControllerProvider);
    final story = stories.value?.items
        .where((s) => s.storyId == storyId)
        .firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: StepLayout(
          onBack: () => _back(context),
          actions: const [],
          children: [
            if (story != null)
              StoryCard(key: ValueKey(story.storyId), story: story)
            else if (stories.isLoading)
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
                '질문 책장에서 다시 골라 주세요.',
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
