import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/audio_playback_card.dart';
import '../stories_controller.dart';
import '../../domain/story.dart';
import 'delete_my_answer_button.dart';
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
      mine: StoryEntry(
        icon: AppIcons.childHead,
        label: '내 이야기',
        text: childAnswerText(story.childAnswer),
      ),
      theirs: StoryEntry(
        icon: AppIcons.heart,
        label: '부모님의 이야기',
        text: parentAnswerText(parent),
      ),
      children: [
        // 자녀는 자기 답만 지울 수 있다. 부모 녹음은 부모가 지운다.
        if (!story.childAnswer.isDeleted && story.childAnswer.answerId != null)
          DeleteMyAnswerButton(
            label: '내 답 지우기',
            confirmTitle: '내 답을 지울까요?',
            confirmMessage: childDeleteConfirmMessage,
            doneMessage: '답을 지웠어요.',
            onDelete: (deleter) => deleter.deleteChildAnswer(story),
          ),
      ],
    );
  }
}

/// Figma WF-022 진행 막대와 버튼: 부모님 목소리 재생. 부모님이 지운 녹음은 재생·재발급을
/// 시도하지 않으므로 [hasChildStoryAudio]가 거짓이면 그리지 않는다.
bool hasChildStoryAudio(Story story) =>
    !story.parentAnswer.isDeleted &&
    story.parentAnswer.originalAudioUrl != null;

class ChildStoryAudio extends ConsumerWidget {
  const ChildStoryAudio({super.key, required this.story});
  final Story story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parent = story.parentAnswer;
    if (!hasChildStoryAudio(story)) return const SizedBox.shrink();
    return AudioPlaybackCard(
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
    );
  }
}
