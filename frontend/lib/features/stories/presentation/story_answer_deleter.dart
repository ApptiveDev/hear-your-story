import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stories_providers.dart';
import '../domain/story.dart';
import 'stories_controller.dart';
import 'stories_month_provider.dart';

/// 지난 이야기에서 본인 답을 지운다.
///
/// 부모는 자기 녹음, 자녀는 자기 답만 각각 지운다. 하루치 이야기를 통째로 지우지
/// 않으므로 질문과 상대방 답은 남고, 지운 쪽만 `DELETED`로 보인다.
class StoryAnswerDeleter {
  StoryAnswerDeleter(this._ref);
  final Ref _ref;

  Future<void> deleteParentRecording(Story story) async {
    final recordingId = story.parentAnswer.recordingId;
    if (story.parentAnswer.isDeleted || recordingId == null) return;
    await _ref
        .read(storiesRepositoryProvider)
        .deleteParentRecording(recordingId);
    _apply(story.storyId, (s) => s.withParentAnswerDeleted());
  }

  Future<void> deleteChildAnswer(Story story) async {
    final answerId = story.childAnswer.answerId;
    if (story.childAnswer.isDeleted || answerId == null) return;
    await _ref.read(storiesRepositoryProvider).deleteChildAnswer(answerId);
    _apply(story.storyId, (s) => s.withChildAnswerDeleted());
  }

  /// 서버와 화면이 어긋났을 때(이미 지워진 기록 등) 목록과 달력을 다시 불러온다.
  void reloadAll() {
    _ref.invalidate(storiesControllerProvider);
    _ref.invalidate(storiesMonthProvider);
  }

  /// 목록은 그 카드만 바꾸고, 달력은 그 달을 다시 불러온다.
  void _apply(String storyId, Story Function(Story story) update) {
    if (_ref.exists(storiesControllerProvider)) {
      _ref
          .read(storiesControllerProvider.notifier)
          .replaceStory(storyId, update);
    }
    _ref.invalidate(storiesMonthProvider);
  }
}

final storyAnswerDeleterProvider = Provider<StoryAnswerDeleter>(
  StoryAnswerDeleter.new,
);
