import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/features/onboarding/domain/app_user.dart';
import 'package:life_record/features/today/domain/today.dart';
import 'package:life_record/features/today/presentation/today_page.dart';

import 'today_fixtures.dart';

void main() {
  test('아무도 답하지 않은 상태: 내 답이 없다', () {
    final today = Today.fromJson(todayFixture('waiting_for_both'));

    expect(today.revealStatus, RevealStatus.waitingForBoth);
    expect(today.iAnswered, isFalse);
    expect(today.myAnswer, isNull);
    expect(today.question.audioUrl, isNull);
  });

  test('부모만 답한 상태: 부모의 음성 답과 처리 상태를 읽는다', () {
    final today = Today.fromJson(todayFixture('waiting_for_child'));

    expect(today.viewerRole, UserRole.parent);
    expect(today.iAnswered, isTrue);
    final my = today.myAnswer as VoiceAnswer;
    expect(my.processingStatus, 'LLM_PROCESSING');
    expect(my.displayText, '어릴 때는 동네에서 고무줄 놀이를...'); // 정리본이 없으면 원문
    expect(
      my.originalAudioExpiresAt,
      DateTime.parse('2026-09-24T10:20:00+09:00'),
    );
  });

  test('음성 링크 만료 시각이 없으면 null로 둔다', () {
    final json = todayFixture('waiting_for_child');
    (json['myAnswer'] as Map<String, dynamic>)
      ..remove('originalAudioExpiresAt')
      ..['originalAudioUrl'] = null;
    final my = Today.fromJson(json).myAnswer as VoiceAnswer;

    expect(my.originalAudioUrl, isNull);
    expect(my.originalAudioExpiresAt, isNull);
  });

  test('공개 상태: 상대 답을 읽고 정리본을 우선 보여준다', () {
    final today = Today.fromJson(todayFixture('revealed'));

    expect(today.isRevealed, isTrue);
    expect(today.canViewPartnerAnswer, isTrue);
    expect((today.myAnswer as TextAnswer).text, startsWith('저는 놀이터에서'));
    expect(
      (today.partnerAnswer as VoiceAnswer).displayText,
      '어린 시절 동네 친구들과 고무줄 놀이를 즐겼어요.',
    );
  });

  test('날짜를 월·일로 보여준다', () {
    expect(formatAssignedDate(DateTime(2026, 9, 24)), '9월 24일');
    expect(formatAssignedDate(DateTime(2026, 10, 10)), '10월 10일');
  });
}
