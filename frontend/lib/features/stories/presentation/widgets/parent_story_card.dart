import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/note_paper.dart';
import '../../../../core/widgets/audio_playback_card.dart';
import '../../../parent_answer/data/parent_answer_providers.dart';
import '../../domain/story.dart';
import '../story_child_audio_provider.dart';
import 'delete_my_answer_button.dart';
import 'story_card_frame.dart';

/// 부모용: 자녀의 답을 목소리(TTS)로 듣는 카드
class ParentStoryCard extends StatelessWidget {
  const ParentStoryCard({super.key, required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    return StoryCardFrame(
      story: story,
      mine: NoteEntry(
        icon: AppIcons.heart,
        label: '내 이야기',
        text: parentAnswerText(story.parentAnswer),
      ),
      theirs: NoteEntry(
        icon: AppIcons.childHead,
        label: '자녀의 이야기',
        text: childAnswerText(story.childAnswer),
      ),
      children: [
        // 부모는 자기 녹음만 지울 수 있다. 자녀 답은 자녀가 지운다.
        if (!story.parentAnswer.isDeleted &&
            story.parentAnswer.recordingId != null)
          DeleteMyAnswerButton(
            label: '녹음 지우기',
            confirmTitle: '이 녹음을 지울까요?',
            confirmMessage: parentDeleteConfirmMessage,
            doneMessage: '녹음을 지웠어요.',
            onDelete: (deleter) => deleter.deleteParentRecording(story),
          ),
      ],
    );
  }
}

/// 자녀 답을 목소리로 들려줄 수 있거나 만드는 중인지. 지워진 답은 그리지 않는다.
bool hasParentStoryAudio(Story story) {
  final answer = story.childAnswer;
  return answer.answerId != null &&
      (answer.isTtsReady || answer.isTtsProcessing);
}

/// Figma WF-021·022 진행 막대와 버튼: 자녀 답을 목소리(TTS)로 듣는다. 만드는 중이면
/// 눌리지 않는 `목소리를 담고 있어요` 버튼을 보인다.
class ParentStoryAudio extends ConsumerWidget {
  const ParentStoryAudio({super.key, required this.story});
  final Story story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answer = story.childAnswer;
    if (answer.isTtsProcessing) {
      return const FilledButton(onPressed: null, child: Text('목소리를 담고 있어요'));
    }
    // 지워진 답(answerId == null)은 음성 주소를 요청하지 않는다.
    final answerId = answer.answerId;
    if (!answer.isTtsReady || answerId == null) return const SizedBox.shrink();

    final audio = ref.watch(storyChildAudioProvider(answerId));
    return audio.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (a) {
        final url = a.url;
        if (url == null) return const SizedBox.shrink();
        return AudioPlaybackCard(
          source: PlaybackSource(url, expiresAt: a.expiresAt),
          label: '자녀 답 들어보기',
          onRefresh: () async {
            final fresh = await ref
                .read(parentAnswerRepositoryProvider)
                .getAudio(answerId);
            final freshUrl = fresh.url;
            if (freshUrl == null) {
              throw StateError('음성을 다시 불러오지 못했어요');
            }
            return PlaybackSource(freshUrl, expiresAt: fresh.expiresAt);
          },
        );
      },
    );
  }
}
