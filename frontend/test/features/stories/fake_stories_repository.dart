import 'dart:async';

import 'package:life_record/features/stories/domain/stories_repository.dart';
import 'package:life_record/features/stories/domain/story.dart';

/// 테스트용 이야기 하나를 만든다.
Story testStory(
  String id, {
  DateTime? assignedDate,
  String? summaryText = '정리된 부모님 답',
  String processingStatus = 'READY',
  String? processingNotice,
  String? originalAudioUrl,
  String ttsStatus = 'READY',
  bool parentDeleted = false,
  bool childDeleted = false,
}) {
  return Story(
    storyId: 'story_$id',
    assignmentId: 'asg_$id',
    assignedDate: assignedDate ?? DateTime(2026, 9, 24),
    questionText: '질문 $id',
    questionCategory: 'CHILDHOOD',
    parentAnswer: parentDeleted
        ? StoryParentAnswer(
            availability: AnswerAvailability.deleted,
            recordingId: null,
            processingStatus: null,
            processingNotice: processingNotice,
            originalAudioUrl: originalAudioUrl,
          )
        : StoryParentAnswer(
            recordingId: 'rec_$id',
            processingStatus: processingStatus,
            summaryText: summaryText,
            processingNotice: processingNotice,
            originalAudioUrl: originalAudioUrl,
          ),
    childAnswer: childDeleted
        ? const StoryChildAnswer(
            availability: AnswerAvailability.deleted,
            answerId: null,
            text: null,
            ttsStatus: null,
          )
        : StoryChildAnswer(
            answerId: 'ans_$id',
            text: '자녀 답 $id',
            ttsStatus: ttsStatus,
          ),
    revealedAt: DateTime(2026, 9, 24, 21),
  );
}

class FakeStoriesRepository implements StoriesRepository {
  FakeStoriesRepository(this.pages, {this.months = const {}});

  /// cursor → 돌려줄 페이지. 첫 페이지의 키는 null.
  final Map<String?, StoryPage> pages;

  /// `YYYY-MM` → 그 달의 이야기. 없는 달은 빈 목록이다.
  final Map<String, List<Story>> months;

  /// 값이 있으면 fetchPage와 fetchMonth에서 이 에러를 던진다.
  Object? error;

  /// 값이 있으면 complete될 때까지 응답을 멈춘다. (불러오는 중 상태 테스트용)
  Completer<void>? gate;

  /// 요청된 cursor 기록 (중복 요청 확인용)
  final List<String?> requestedCursors = [];

  /// 요청된 달 기록
  final List<String> requestedMonths = [];

  @override
  Future<StoryPage> fetchPage({String? cursor}) async {
    requestedCursors.add(cursor);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return pages[cursor]!;
  }

  @override
  Future<List<Story>> fetchMonth(String month) async {
    requestedMonths.add(month);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return months[month] ?? const [];
  }
}
