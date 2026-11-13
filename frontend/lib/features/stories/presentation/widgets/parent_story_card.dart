import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      children: [
        _ChildVoiceSection(answer: story.childAnswer),
        const SizedBox(height: 12),
        AnswerSection(label: '자녀의 답', text: childAnswerText(story.childAnswer)),
        const SizedBox(height: 16),
        AnswerSection(
          label: '내가 남긴 답',
          text: parentAnswerText(story.parentAnswer),
        ),
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

/// 부모에게 자녀 답을 목소리(TTS)로 들려주는 영역
class _ChildVoiceSection extends ConsumerWidget {
  const _ChildVoiceSection({required this.answer});
  final StoryChildAnswer answer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (answer.isTtsProcessing) {
      return Text(
        '자녀의 답을 목소리로 바꾸고 있어요.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
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
