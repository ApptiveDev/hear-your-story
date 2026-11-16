enum AnswerTtsStatus {
  notRequested('NOT_REQUESTED'),
  processing('PROCESSING'),
  ready('READY'),
  failed('FAILED');

  const AnswerTtsStatus(this.apiValue);
  final String apiValue;
  static AnswerTtsStatus fromApi(String value) => values.firstWhere(
    (status) => status.apiValue == value,
    orElse: () => throw const FormatException('알 수 없는 음성 상태'),
  );
}

class ParentAnswer {
  const ParentAnswer({
    required this.questionText,
    required this.revealStatus,
    required this.canView,
    this.answerId,
    this.text,
    this.myText,
  });
  final String questionText;
  final String revealStatus;
  final bool canView;
  final String? answerId;
  final String? text;

  /// 부모 자신의 답(음성을 글로 정리한 것). 정리 전이면 null.
  final String? myText;
}

class AnswerAudio {
  const AnswerAudio({required this.status, this.url, this.expiresAt});
  final AnswerTtsStatus status;
  final String? url;
  final DateTime? expiresAt;
}
