import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/audio_playback_card.dart';
import '../stories_controller.dart';
import '../../domain/story.dart';
import 'story_card_frame.dart';

/// 자녀용: 부모님 목소리를 듣는 카드
class ChildStoryCard extends ConsumerWidget {
  const ChildStoryCard({super.key, required this.story});
  final Story story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parent = story.parentAnswer;
    return StoryCardFrame(
      story: story,
      children: [
        // 부모님이 지운 녹음은 재생·재발급을 시도하지 않는다.
        if (!parent.isDeleted && parent.originalAudioUrl != null) ...[
          AudioPlaybackCard(
            source: PlaybackSource(
              parent.originalAudioUrl!,
              expiresAt: parent.originalAudioExpiresAt,
            ),
            label: '부모님 목소리 듣기',
            onRefresh: () async {
              final fresh = await ref
                  .read(storiesControllerProvider.notifier)
                  .fetchLatestParentAnswer(story.storyId);
              if (fresh.originalAudioUrl == null) {
                throw StateError('음성을 다시 불러오지 못했어요');
              }
              return PlaybackSource(
                fresh.originalAudioUrl!,
                expiresAt: fresh.originalAudioExpiresAt,
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        AnswerSection(label: '부모님의 답', text: parentAnswerText(parent)),
        const SizedBox(height: 16),
        AnswerSection(
          label: '내가 쓴 답',
          text: childAnswerText(story.childAnswer),
        ),
      ],
    );
  }
}
