/// 답변을 아직 볼 수 있는지, 작성자가 지워서 없는지 (계약 `AnswerAvailability`, 초안)
enum AnswerAvailability {
  available,
  deleted;

  /// 서버 값을 읽는다. 필드가 없던 이전 응답은 볼 수 있는 답으로 본다.
  static AnswerAvailability fromJson(String? value) =>
      value == 'DELETED' ? deleted : available;
}

/// 공개가 끝난 하루치 이야기 (질문 + 부모 답 + 자녀 답)
class Story {
  const Story({
    required this.storyId,
    required this.assignmentId,
    required this.assignedDate,
    required this.questionText,
    required this.questionCategory,
    required this.parentAnswer,
    required this.childAnswer,
    required this.revealedAt,
  });

  final String storyId;
  final String assignmentId;
  final DateTime assignedDate;
  final String questionText;
  final String questionCategory;
  final StoryParentAnswer parentAnswer;
  final StoryChildAnswer childAnswer;
  final DateTime revealedAt;
}

class StoryParentAnswer {
  const StoryParentAnswer({
    this.availability = AnswerAvailability.available,
    required this.recordingId,
    required this.processingStatus,
    this.originalAudioUrl,
    this.originalAudioExpiresAt,
    this.sttText,
    this.summaryText,
    this.processingNotice,
  });

  final AnswerAvailability availability;

  /// 부모가 녹음을 지웠거나 탈퇴했으면 `null`이다.
  final String? recordingId;
  final String? processingStatus;
  final String? originalAudioUrl;
  final DateTime? originalAudioExpiresAt;
  final String? sttText;
  final String? summaryText;
  final String? processingNotice;

  /// 부모가 지워서 음성·글을 더 볼 수 없는지
  bool get isDeleted => availability == AnswerAvailability.deleted;

  /// 음성을 글로 정리하는 중인지 (READY·FAILED가 아니면 처리 중).
  /// 지워진 답은 상태가 `null`로 오므로 처리 중으로 보지 않는다.
  bool get isProcessing =>
      !isDeleted && processingStatus != 'READY' && processingStatus != 'FAILED';

  /// 화면에 보여줄 글: 정리본 → 원문 → 안내 문구 순
  String? get displayText => summaryText ?? sttText ?? processingNotice;
}

class StoryChildAnswer {
  const StoryChildAnswer({
    this.availability = AnswerAvailability.available,
    required this.answerId,
    required this.text,
    required this.ttsStatus,
  });

  final AnswerAvailability availability;

  /// 자녀가 탈퇴해 답이 지워졌으면 셋 다 `null`이다.
  final String? answerId;
  final String? text;
  final String? ttsStatus;

  /// 자녀 답이 지워져 글·음성을 더 볼 수 없는지
  bool get isDeleted => availability == AnswerAvailability.deleted;

  /// 부모에게 TTS 재생 버튼을 보여줘도 되는지
  bool get isTtsReady => !isDeleted && answerId != null && ttsStatus == 'READY';

  /// 서버가 아직 음성을 만드는 중인지
  bool get isTtsProcessing => !isDeleted && ttsStatus == 'PROCESSING';
}

/// 한 번에 불러온 목록 한 페이지
class StoryPage {
  const StoryPage({
    required this.items,
    required this.nextCursor,
    required this.hasNext,
  });

  final List<Story> items;
  final String? nextCursor;
  final bool hasNext;
}
