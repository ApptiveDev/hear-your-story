import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/parent_answer/data/parent_answer_data_source.dart';
import 'package:life_record/features/parent_answer/data/parent_answer_repository_impl.dart';

class _Source implements ParentAnswerDataSource {
  Map<String, dynamic> json = {
    'viewerRole': 'PARENT',
    'assignment': {
      'question': {'text': '질문'},
    },
    'revealStatus': 'WAITING_FOR_CHILD',
    'canViewPartnerAnswer': false,
    'partnerAnswer': {'type': 'TEXT', 'answerId': 'ans_1', 'text': '비공개 답변'},
  };
  @override
  Future<Map<String, dynamic>> getToday() async => json;
  @override
  Future<Map<String, dynamic>> getAudio(String answerId) async => {
    'ttsStatus': 'READY',
    'audioUrl': 'https://example.test',
    'audioExpiresAt': '2026-09-25T12:00:00+09:00',
  };
}

void main() {
  test('삭제된 양쪽 답은 안내로 읽고 TTS 요청용 ID를 만들지 않는다', () async {
    final source = _Source()
      ..json['canViewPartnerAnswer'] = true
      ..json['revealStatus'] = 'REVEALED'
      ..json['myAnswer'] = {
        'type': 'DELETED',
        'availability': 'DELETED',
        'message': '부모님이 이 음성 기록을 삭제했어요.',
      }
      ..json['partnerAnswer'] = {
        'type': 'DELETED',
        'availability': 'DELETED',
        'message': '삭제된 답이에요.',
      };
    final result = await ParentAnswerRepositoryImpl(source).getToday();
    expect(result.answerId, isNull);
    expect(result.text, '삭제된 답이에요.');
    expect(result.myText, '부모님이 이 음성 기록을 삭제했어요.');
  });
  test('서버가 비공개로 표시하면 포함된 답변도 노출하지 않는다', () async {
    final result = await ParentAnswerRepositoryImpl(_Source()).getToday();
    expect(result.canView, isFalse);
    expect(result.text, isNull);
    expect(result.answerId, isNull);
  });

  test('내 음성 답은 정리본을, 없으면 받아쓴 글을 쓴다', () async {
    final source = _Source()
      // null을 넣어 볼 수 있게 값 타입을 dynamic으로 둔다
      ..json['myAnswer'] = <String, dynamic>{
        'type': 'VOICE',
        'sttText': '받아쓴 글',
        'summaryText': '정리한 글',
      };
    final repository = ParentAnswerRepositoryImpl(source);
    expect((await repository.getToday()).myText, '정리한 글');

    (source.json['myAnswer'] as Map<String, dynamic>)['summaryText'] = null;
    expect((await repository.getToday()).myText, '받아쓴 글');

    source.json.remove('myAnswer');
    expect((await repository.getToday()).myText, isNull);
  });

  test('자녀 관점의 응답은 부모 화면에서 거절한다', () async {
    final source = _Source()..json['viewerRole'] = 'CHILD';
    await expectLater(
      ParentAnswerRepositoryImpl(source).getToday(),
      throwsA(isA<ApiException>()),
    );
  });

  test('음성 URL 만료 시각의 시간대를 보존한다', () async {
    final audio = await ParentAnswerRepositoryImpl(_Source()).getAudio('ans_1');
    expect(audio.expiresAt, DateTime.utc(2026, 9, 25, 3));
  });
}
