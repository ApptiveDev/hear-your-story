import '../../onboarding/domain/app_user.dart';

enum SubmissionStatus {
  notSubmitted('NOT_SUBMITTED'),
  submitted('SUBMITTED'),
  skipped('SKIPPED');

  const SubmissionStatus(this.apiValue);
  final String apiValue;

  static SubmissionStatus fromApi(String value) =>
      values.firstWhere((s) => s.apiValue == value);
}

enum RevealStatus {
  waitingForParent('WAITING_FOR_PARENT'),
  waitingForChild('WAITING_FOR_CHILD'),
  waitingForBoth('WAITING_FOR_BOTH'),
  revealed('REVEALED');

  const RevealStatus(this.apiValue);
  final String apiValue;

  static RevealStatus fromApi(String value) =>
      values.firstWhere((s) => s.apiValue == value);
}

class TodayQuestion {
  const TodayQuestion({
    required this.id,
    required this.text,
    required this.category,
    this.audioUrl,
  });

  final String id;
  final String text;
  final String category;

  /// 질문 안내 음성. TTS가 준비되기 전에는 null이다.
  final String? audioUrl;

  factory TodayQuestion.fromJson(Map<String, dynamic> json) => TodayQuestion(
    id: json['id'] as String,
    text: json['text'] as String,
    category: json['category'] as String,
    audioUrl: json['audioUrl'] as String?,
  );
}

/// 부모의 음성 답변 또는 자녀의 텍스트 답변
sealed class TodayAnswer {
  const TodayAnswer();

  factory TodayAnswer.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'DELETED':
        return DeletedAnswer(json['message'] as String);
      case 'VOICE':
        return VoiceAnswer.fromJson(json);
      case 'TEXT':
        return TextAnswer.fromJson(json);
      default:
        throw FormatException('알 수 없는 답변 type: ${json['type']}');
    }
  }
}

class DeletedAnswer extends TodayAnswer {
  const DeletedAnswer(this.message);
  final String message;
}

class VoiceAnswer extends TodayAnswer {
  const VoiceAnswer({
    required this.recordingId,
    required this.processingStatus,
    this.originalAudioUrl,
    this.originalAudioExpiresAt,
    this.sttText,
    this.summaryText,
    this.processingNotice,
  });

  final String recordingId;
  final String processingStatus;
  final String? originalAudioUrl;

  /// 서명 URL 만료 시각. 재생 위젯(AudioPlaybackCard)이 만료 전에 새로 받아올 때 쓴다.
  final DateTime? originalAudioExpiresAt;
  final String? sttText;
  final String? summaryText;
  final String? processingNotice;

  /// 화면에 보여줄 자막. 정리본이 없으면 받아쓰기 원문을 쓴다.
  String? get displayText => summaryText ?? sttText;

  factory VoiceAnswer.fromJson(Map<String, dynamic> json) => VoiceAnswer(
    recordingId: json['recordingId'] as String,
    processingStatus: json['processingStatus'] as String,
    originalAudioUrl: json['originalAudioUrl'] as String?,
    originalAudioExpiresAt: _parseDate(json['originalAudioExpiresAt']),
    sttText: json['sttText'] as String?,
    summaryText: json['summaryText'] as String?,
    processingNotice: json['processingNotice'] as String?,
  );
}

class TextAnswer extends TodayAnswer {
  const TextAnswer({
    required this.answerId,
    required this.text,
    required this.ttsStatus,
  });

  final String answerId;
  final String text;
  final String ttsStatus;

  factory TextAnswer.fromJson(Map<String, dynamic> json) => TextAnswer(
    answerId: json['answerId'] as String,
    text: json['text'] as String,
    ttsStatus: json['ttsStatus'] as String,
  );
}

/// `GET /today` 응답 (API 계약 5.4). 공개 여부는 서버가 계산한 값만 쓴다.
class Today {
  const Today({
    required this.assignmentId,
    required this.assignedDate,
    required this.question,
    required this.viewerRole,
    required this.parentSubmissionStatus,
    required this.childSubmissionStatus,
    required this.revealStatus,
    required this.canViewPartnerAnswer,
    this.myAnswer,
    this.partnerAnswer,
  });

  final String assignmentId;
  final DateTime assignedDate;
  final TodayQuestion question;
  final UserRole viewerRole;
  final SubmissionStatus parentSubmissionStatus;
  final SubmissionStatus childSubmissionStatus;
  final RevealStatus revealStatus;
  final bool canViewPartnerAnswer;
  final TodayAnswer? myAnswer;
  final TodayAnswer? partnerAnswer;

  bool get isRevealed => revealStatus == RevealStatus.revealed;

  /// 보는 사람이 오늘 답했는지
  bool get iAnswered =>
      (viewerRole == UserRole.parent
          ? parentSubmissionStatus
          : childSubmissionStatus) ==
      SubmissionStatus.submitted;

  factory Today.fromJson(Map<String, dynamic> json) {
    final assignment = json['assignment'] as Map<String, dynamic>;
    final my = json['myAnswer'] as Map<String, dynamic>?;
    final partner = json['partnerAnswer'] as Map<String, dynamic>?;
    return Today(
      assignmentId: assignment['id'] as String,
      assignedDate: DateTime.parse(assignment['assignedDate'] as String),
      question: TodayQuestion.fromJson(
        assignment['question'] as Map<String, dynamic>,
      ),
      viewerRole: UserRole.fromApi(json['viewerRole'] as String),
      parentSubmissionStatus: SubmissionStatus.fromApi(
        json['parentSubmissionStatus'] as String,
      ),
      childSubmissionStatus: SubmissionStatus.fromApi(
        json['childSubmissionStatus'] as String,
      ),
      revealStatus: RevealStatus.fromApi(json['revealStatus'] as String),
      canViewPartnerAnswer: json['canViewPartnerAnswer'] as bool,
      myAnswer: my == null ? null : TodayAnswer.fromJson(my),
      partnerAnswer: partner == null ? null : TodayAnswer.fromJson(partner),
    );
  }
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.parse(value) : null;
