import '../../../core/network/api_exception.dart';
import '../domain/parent_answer.dart';
import '../domain/parent_answer_repository.dart';
import 'parent_answer_data_source.dart';

class ParentAnswerRepositoryImpl implements ParentAnswerRepository {
  ParentAnswerRepositoryImpl(this._source);
  final ParentAnswerDataSource _source;

  @override
  Future<ParentAnswer> getToday() async {
    final json = await _source.getToday();
    if (json['viewerRole'] != 'PARENT') {
      throw ApiException(statusCode: 403, errorCode: 'ROLE_NOT_ALLOWED');
    }
    final assignment = json['assignment'] as Map<String, dynamic>;
    final question = assignment['question'] as Map<String, dynamic>;
    final canView = json['canViewPartnerAnswer'] == true;
    // 서버가 비공개라고 하면 잘못 포함된 답변도 읽지 않는다.
    final partner = canView
        ? json['partnerAnswer'] as Map<String, dynamic>?
        : null;
    final my = json['myAnswer'] as Map<String, dynamic>?;
    return ParentAnswer(
      questionText: question['text'] as String,
      revealStatus: json['revealStatus'] as String,
      canView: canView,
      answerId: partner?['type'] == 'TEXT'
          ? partner!['answerId'] as String
          : null,
      text: partner?['type'] == 'TEXT' ? partner!['text'] as String : null,
      myText: my != null && my['type'] == 'VOICE'
          ? (my['summaryText'] ?? my['sttText']) as String?
          : null,
    );
  }

  @override
  Future<AnswerAudio> getAudio(String answerId) async {
    final json = await _source.getAudio(answerId);
    final expires = json['audioExpiresAt'] as String?;
    return AnswerAudio(
      status: AnswerTtsStatus.fromApi(json['ttsStatus'] as String),
      url: json['audioUrl'] as String?,
      expiresAt: expires == null ? null : DateTime.parse(expires),
    );
  }
}
