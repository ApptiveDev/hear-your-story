import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/app/app.dart';
import 'package:life_record/core/config/auth_flags.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/core/network/session_expired_signal.dart';
import 'package:life_record/features/onboarding/data/auth_providers.dart';
import 'package:life_record/features/onboarding/data/kakao_sign_in.dart';
import 'package:life_record/features/pairing/data/pairing_providers.dart';
import 'package:life_record/features/today/data/today_providers.dart';

import '../../helpers/phone_size.dart';
import '../pairing/fake_pairing_data_source.dart';
import '../today/today_fixtures.dart';
import 'fake_auth_data_source.dart';

const _storage = FlutterSecureStorage();
const _question = '어릴 때 가장 좋아했던 놀이는 무엇이었나요?';

Future<void> _pumpApp(
  WidgetTester tester, {
  required FakeAuthDataSource auth,
  FakeKakao? kakao,
  Map<String, String> stored = const {},
  bool kakaoAuth = true,
  FakeTodayDataSource? today,
}) async {
  usePhoneSize(tester);
  FlutterSecureStorage.setMockInitialValues(Map.of(stored));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        kakaoAuthEnabledProvider.overrideWithValue(kakaoAuth),
        authDataSourceProvider.overrideWithValue(auth),
        kakaoSignInProvider.overrideWithValue(kakao ?? FakeKakao()),
        pairingDataSourceProvider.overrideWithValue(
          FakePairingDataSource(pairedAfterChecks: 99),
        ),
        todayDataSourceProvider.overrideWithValue(
          today ?? FakeTodayDataSource(json: todayFixture('waiting_for_both')),
        ),
      ],
      child: const App(),
    ),
  );
  await _settle(tester);
}

/// 페어링 화면은 대기 표시가 계속 돌아서 pumpAndSettle 대신 시간을 넘긴다
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _tapLogin(WidgetTester tester) async {
  await tester.tap(find.text('카카오로 시작하기'));
  await _settle(tester);
}

Map<String, String> _signedIn({String role = 'CHILD'}) => {
  'access_token': 'kakao-access',
  'refresh_token': 'kakao-refresh',
  'device_id': 'device-1',
  'current_user': jsonEncode({
    'id': 'usr_kakao',
    'name': '김민지',
    'role': role,
    'pairingStatus': 'PAIRED',
  }),
};

void main() {
  testWidgets('로그인 전이면 카카오 로그인부터 보여준다', (tester) async {
    await _pumpApp(tester, auth: FakeAuthDataSource());

    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.text('누구로 시작할까요?'), findsNothing);
  });

  testWidgets('카카오 로그인을 끄면 기존처럼 역할 선택부터 시작한다', (tester) async {
    await _pumpApp(tester, auth: FakeAuthDataSource(), kakaoAuth: false);

    expect(find.text('누구로 시작할까요?'), findsOneWidget);
    expect(find.text('카카오로 시작하기'), findsNothing);
  });

  testWidgets('기존 계정이면 로그인하자마자 오늘 질문으로 간다', (tester) async {
    final auth = FakeAuthDataSource()..kakao = kakaoLoginJson(role: 'CHILD');

    await _pumpApp(tester, auth: auth);
    await _tapLogin(tester);

    expect(find.text(_question), findsOneWidget);
    expect(await _storage.read(key: 'refresh_token'), 'kakao-refresh');
  });

  testWidgets('기존 계정이 연결 전이면 페어링으로 간다', (tester) async {
    final auth = FakeAuthDataSource()
      ..kakao = kakaoLoginJson(role: 'CHILD', pairingStatus: 'UNPAIRED');

    await _pumpApp(tester, auth: auth);
    await _tapLogin(tester);

    expect(find.text('부모님을\n초대해 주세요'), findsOneWidget);
  });

  testWidgets('처음이면 역할·이름을 받아 가입을 마친다', (tester) async {
    final auth = FakeAuthDataSource()..kakao = kakaoLoginJson(status: 'NEW');

    await _pumpApp(tester, auth: auth);
    await _tapLogin(tester);
    expect(find.text('누구로 시작할까요?'), findsOneWidget);

    await tester.tap(find.text('자녀예요'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '김민지');
    await tester.pump(); // 이름이 들어가야 시작하기가 켜진다
    await tester.tap(find.text('시작하기'));
    await _settle(tester);

    expect(auth.requests.single['role'], 'CHILD');
    expect(find.text('부모님을\n초대해 주세요'), findsOneWidget);
    expect(await _storage.read(key: 'refresh_token'), 'kakao-refresh');
  });

  testWidgets('로그인만 하고 가입을 마치지 않았으면 다시 켤 때 역할 선택부터 한다', (tester) async {
    await _pumpApp(
      tester,
      auth: FakeAuthDataSource(),
      stored: {
        'access_token': 'kakao-access',
        'refresh_token': 'kakao-refresh',
      },
    );

    expect(find.text('누구로 시작할까요?'), findsOneWidget);
    expect(find.text('카카오로 시작하기'), findsNothing);
  });

  testWidgets('카카오 창을 닫으면 안내 없이 로그인 화면에 머문다', (tester) async {
    final kakao = FakeKakao(error: const KakaoSignInCancelled());

    await _pumpApp(tester, auth: FakeAuthDataSource(), kakao: kakao);
    await _tapLogin(tester);

    expect(kakao.signInCalls, 1);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  for (final (label, kakaoError, serverError, message) in [
    (
      '카카오 로그인이 실패하면',
      const KakaoSignInFailed('test') as Object?,
      null as Object?,
      '카카오 로그인에 실패했어요. 다시 시도해 주세요.',
    ),
    (
      '서버가 본인 확인을 거절하면',
      null,
      ApiException(statusCode: 400, errorCode: 'INVALID_ID_TOKEN'),
      '카카오 로그인에 실패했어요. 다시 시도해 주세요.',
    ),
    ('인터넷이 끊기면', null, ApiException(), '인터넷 연결을 확인해 주세요.'),
  ]) {
    testWidgets('$label 안내하고 다시 누를 수 있다', (tester) async {
      final auth = FakeAuthDataSource()..kakaoError = serverError;
      final kakao = FakeKakao(error: kakaoError);

      await _pumpApp(tester, auth: auth, kakao: kakao);
      await _tapLogin(tester);

      expect(find.text(message), findsOneWidget);
      // 고쳐지면 다시 눌러서 들어갈 수 있다
      kakao.error = null;
      auth
        ..kakaoError = null
        ..kakao = kakaoLoginJson(role: 'CHILD');
      await _tapLogin(tester);
      expect(find.text(_question), findsOneWidget);
    });
  }

  testWidgets('로그아웃하면 확인을 받고 로그인 정보를 지운 뒤 로그인 화면으로 간다', (tester) async {
    final kakao = FakeKakao();
    await _pumpApp(
      tester,
      auth: FakeAuthDataSource(),
      kakao: kakao,
      stored: _signedIn(),
    );
    expect(find.text(_question), findsOneWidget);

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃할까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(await _storage.read(key: 'access_token'), 'kakao-access');

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '로그아웃').last);
    await _settle(tester);

    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(await _storage.read(key: 'access_token'), isNull);
    expect(await _storage.read(key: 'refresh_token'), isNull);
    expect(await _storage.read(key: 'current_user'), isNull);
    expect(await _storage.read(key: 'device_id'), 'device-1');
    expect(kakao.signOutCalls, 1);
  });

  testWidgets('페어링 화면에서도 로그아웃할 수 있다', (tester) async {
    final auth = FakeAuthDataSource()
      ..kakao = kakaoLoginJson(role: 'CHILD', pairingStatus: 'UNPAIRED');
    await _pumpApp(tester, auth: auth);
    await _tapLogin(tester);

    await tester.tap(find.text('로그아웃'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(TextButton, '로그아웃').last);
    await _settle(tester);

    expect(find.text('카카오로 시작하기'), findsOneWidget);
  });

  testWidgets('카카오 로그인을 끄면 로그아웃 버튼을 두지 않는다', (tester) async {
    await _pumpApp(
      tester,
      auth: FakeAuthDataSource(),
      stored: _signedIn(),
      kakaoAuth: false,
    );

    expect(find.text(_question), findsOneWidget);
    expect(find.text('로그아웃'), findsNothing);
  });

  testWidgets('로그인이 만료되면 다시 로그인하라고 안내한다', (tester) async {
    await _pumpApp(
      tester,
      auth: FakeAuthDataSource(),
      stored: _signedIn(),
      today: FakeTodayDataSource(
        error: ApiException(statusCode: 401, errorCode: 'TOKEN_EXPIRED'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.textContaining('다시 로그인해 주세요.'), findsOneWidget);
    expect(await _storage.read(key: 'refresh_token'), isNull);
  });

  testWidgets('가입을 마치기 전에 로그인이 만료되면 카카오 로그인으로 돌아간다', (tester) async {
    final auth = FakeAuthDataSource()..kakao = kakaoLoginJson(status: 'NEW');
    await _pumpApp(tester, auth: auth);
    await _tapLogin(tester);
    expect(find.text('누구로 시작할까요?'), findsOneWidget);

    // 가입 요청이 401을 받고 refresh도 실패한 상황 (interceptor가 보내는 신호)
    ProviderScope.containerOf(tester.element(find.byType(App)))
        .read(sessionExpiredSignalProvider.notifier)
        .emit();
    await tester.pumpAndSettle();

    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(await _storage.read(key: 'refresh_token'), isNull);
  });

  testWidgets('로그인하는 동안 카카오 확인 → 기록 찾기 단계를 알려준다', (tester) async {
    final kakaoGate = Completer<void>();
    final serverGate = Completer<void>();
    final kakao = FakeKakao()..gate = kakaoGate.future;
    final auth = FakeAuthDataSource()
      ..kakao = kakaoLoginJson(role: 'CHILD')
      ..kakaoGate = serverGate.future;

    await _pumpApp(tester, auth: auth, kakao: kakao);
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pump();
    expect(find.text('카카오에서 확인하고 있어요'), findsOneWidget);

    kakaoGate.complete();
    await tester.pump();
    expect(find.text('이전 기록을 찾고 있어요'), findsOneWidget);

    serverGate.complete();
    await _settle(tester);
    expect(find.text(_question), findsOneWidget);
  });

  group('이전 기록을 찾지 못했을 때', () {
    Future<void> reachFailure(
      WidgetTester tester,
      FakeAuthDataSource auth,
      FakeKakao kakao,
    ) async {
      await _pumpApp(tester, auth: auth, kakao: kakao);
      await _tapLogin(tester);
      expect(find.text('이전 기록을 찾지 못했어요'), findsOneWidget);
    }

    testWidgets('이 계정으로 새로 시작하면 역할·이름을 받아 가입한다', (tester) async {
      final auth = FakeAuthDataSource()
        ..kakao = kakaoLoginJson(status: 'RECOVERY_FAILED');
      await reachFailure(tester, auth, FakeKakao());

      await tester.tap(find.text('이 계정으로 새로 시작하기'));
      await tester.pumpAndSettle();
      expect(find.text('누구로 시작할까요?'), findsOneWidget);

      await tester.tap(find.text('자녀예요'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '김민지');
      await tester.pump();
      await tester.tap(find.text('시작하기'));
      await _settle(tester);

      expect(find.text('부모님을\n초대해 주세요'), findsOneWidget);
      expect(await _storage.read(key: 'refresh_token'), 'kakao-refresh');
    });

    testWidgets('다른 카카오 계정을 고르면 그 계정의 기록으로 들어간다', (tester) async {
      final kakao = FakeKakao();
      final auth = FakeAuthDataSource()
        ..kakaoQueue.addAll([
          kakaoLoginJson(status: 'RECOVERY_FAILED'),
          kakaoLoginJson(role: 'CHILD'),
        ]);
      await reachFailure(tester, auth, kakao);

      await tester.tap(find.text('다른 카카오 계정으로 로그인'));
      await _settle(tester);

      expect(find.text(_question), findsOneWidget);
      // 앞 계정은 로그아웃하고, 계정 선택부터 다시 했다
      expect(kakao.signOutCalls, 1);
      expect(kakao.chooseAccount, [false, true]);
      expect(auth.kakaoRequests.map((r) => r['idToken']), [
        'id-token-1',
        'id-token-2',
      ]);
    });

    testWidgets('다른 계정 고르기를 닫으면 앞 계정 토큰 없이 로그인 화면으로 간다', (tester) async {
      final kakao = FakeKakao();
      final auth = FakeAuthDataSource()
        ..kakao = kakaoLoginJson(status: 'RECOVERY_FAILED');
      await reachFailure(tester, auth, kakao);

      kakao.error = const KakaoSignInCancelled();
      await tester.tap(find.text('다른 카카오 계정으로 로그인'));
      await _settle(tester);

      expect(find.text('카카오로 시작하기'), findsOneWidget);
      expect(await _storage.read(key: 'access_token'), isNull);
      expect(await _storage.read(key: 'refresh_token'), isNull);
    });
  });
}
