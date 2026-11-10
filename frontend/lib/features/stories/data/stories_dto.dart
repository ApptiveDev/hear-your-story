import '../domain/story.dart';

/// `GET /stories` 응답 JSON을 domain 모델로 바꾼다.
class StoriesDto {
  const StoriesDto._();

  static StoryPage pageFromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>)
        .map((e) => _story(e as Map<String, dynamic>))
        .toList();
    return StoryPage(
      items: items,
      nextCursor: json['nextCursor'] as String?,
      hasNext: json['hasNext'] as bool,
    );
  }

  static Story _story(Map<String, dynamic> json) {
    final question = json['question'] as Map<String, dynamic>;
    return Story(
      storyId: json['storyId'] as String,
      assignmentId: json['assignmentId'] as String,
      assignedDate: DateTime.parse(json['assignedDate'] as String),
      questionText: question['text'] as String,
      questionCategory: question['category'] as String,
      parentAnswer: _parent(json['parentAnswer'] as Map<String, dynamic>),
      childAnswer: _child(json['childAnswer'] as Map<String, dynamic>),
      revealedAt: DateTime.parse(json['revealedAt'] as String),
    );
  }

  static StoryParentAnswer _parent(Map<String, dynamic> json) {
    final expiresAt = json['originalAudioExpiresAt'] as String?;
    return StoryParentAnswer(
      availability: AnswerAvailability.fromJson(
        json['availability'] as String?,
      ),
      recordingId: json['recordingId'] as String?,
      processingStatus: json['processingStatus'] as String?,
      originalAudioUrl: json['originalAudioUrl'] as String?,
      originalAudioExpiresAt: expiresAt == null
          ? null
          : DateTime.parse(expiresAt),
      sttText: json['sttText'] as String?,
      summaryText: json['summaryText'] as String?,
      processingNotice: json['processingNotice'] as String?,
    );
  }

  static StoryChildAnswer _child(Map<String, dynamic> json) {
    return StoryChildAnswer(
      availability: AnswerAvailability.fromJson(
        json['availability'] as String?,
      ),
      answerId: json['answerId'] as String?,
      text: json['text'] as String?,
      ttsStatus: json['ttsStatus'] as String?,
    );
  }
}
