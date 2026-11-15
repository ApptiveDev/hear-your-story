import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/app/app.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/onboarding/data/auth_providers.dart';
import 'package:life_record/features/onboarding/data/kakao_sign_in.dart';
import 'package:life_record/features/onboarding/presentation/onboarding_page.dart';
import 'package:life_record/features/pairing/data/pairing_providers.dart';
import 'package:life_record/features/today/data/today_providers.dart';

import '../pairing/fake_pairing_data_source.dart';
import '../today/today_fixtures.dart';
import 'fake_auth_data_source.dart';
import '../../helpers/phone_size.dart';

Future<void> _pumpApp(
  WidgetTester tester,
  FakeAuthDataSource dataSource,
) async {
  usePhoneSize(tester);
  dataSource.kakao = kakaoLoginJson(status: 'REGISTRATION_REQUIRED');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authDataSourceProvider.overrideWithValue(dataSource),
        kakaoSignInProvider.overrideWithValue(FakeKakao()),
        pairingDataSourceProvider.overrideWithValue(
          FakePairingDataSource(pairedAfterChecks: 99),
        ),
        todayDataSourceProvider.overrideWithValue(
          FakeTodayDataSource(json: todayFixture('waiting_for_both')),
        ),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('카카오로 시작하기'));
  await tester.pumpAndSettle();
}

FilledButton _startButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('역할을 고르면 이름 입력으로 넘어가고, 뒤로 가면 다시 고를 수 있다', (tester) async {
    await _pumpApp(tester, FakeAuthDataSource());

    await tester.tap(find.text('부모님이에요'));
    await tester.pumpAndSettle();
    expect(find.text('성함을 알려주세요'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('누구로 시작할까요?'), findsOneWidget);
  });

  testWidgets('역할을 고르기 전에 가족끼리만 공유된다고 알려준다', (tester) async {
    await _pumpApp(tester, FakeAuthDataSource());

    expect(find.text(privacyNote), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('이름이 비어 있거나 공백뿐이면 시작하기를 누를 수 없다', (tester) async {
    await _pumpApp(tester, FakeAuthDataSource());
    await tester.tap(find.text('자녀예요'));
    await tester.pumpAndSettle();

    expect(_startButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(_startButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '김민지');
    await tester.pump();
    expect(_startButton(tester).onPressed, isNotNull);
  });

  testWidgets('가입하면 페어링 화면으로 이동한다', (tester) async {
    final dataSource = FakeAuthDataSource();
    await _pumpApp(tester, dataSource);

    await tester.tap(find.text('자녀예요'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '김민지');
    await tester.pump();
    await tester.tap(find.text('시작하기'));
    // 페어링 화면은 연결 대기 표시가 계속 돌아서 pumpAndSettle 대신 시간을 넘긴다
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(dataSource.requests.single['role'], 'CHILD');
    expect(find.text('부모님을\n초대해 주세요'), findsOneWidget);
  });

  testWidgets('이미 연결된 사용자는 오늘 질문으로 이동한다', (tester) async {
    await _pumpApp(tester, FakeAuthDataSource(pairingStatus: 'PAIRED'));

    await tester.tap(find.text('부모님이에요'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '김영희');
    await tester.pump();
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('어릴 때 가장 좋아했던 놀이는 무엇이었나요?'), findsOneWidget);
  });

  testWidgets('서버가 400을 주면 안내하고 입력한 이름을 유지한다', (tester) async {
    await _pumpApp(
      tester,
      FakeAuthDataSource(error: ApiException(statusCode: 400)),
    );

    await tester.tap(find.text('자녀예요'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '김민지');
    await tester.pump();
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('이름을 다시 확인해 주세요.'), findsOneWidget);
    expect(find.text('김민지'), findsOneWidget);
    expect(_startButton(tester).onPressed, isNotNull); // 다시 시도 가능
  });

  testWidgets('가입은 완료됐지만 응답을 못 받았으면 카카오 재로그인으로 복구한다', (tester) async {
    await _pumpApp(
      tester,
      FakeAuthDataSource(
        error: ApiException(
          statusCode: 409,
          errorCode: 'KAKAO_ACCOUNT_ALREADY_REGISTERED',
        ),
      ),
    );

    await tester.tap(find.text('자녀예요'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '김민지');
    await tester.pump();
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.textContaining('같은 카카오 계정으로 다시 로그인해 주세요.'), findsOneWidget);
  });

  testWidgets('네트워크가 끊기면 연결 확인 안내를 보여준다', (tester) async {
    await _pumpApp(tester, FakeAuthDataSource(error: ApiException()));

    await tester.tap(find.text('부모님이에요'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '김영희');
    await tester.pump();
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('인터넷 연결을 확인해 주세요.'), findsOneWidget);
  });
}
