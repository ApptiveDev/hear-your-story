import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_record/app/app.dart';
import 'package:life_record/features/onboarding/data/auth_providers.dart';
import 'package:life_record/features/onboarding/domain/app_user.dart';
import 'package:life_record/features/pairing/data/pairing_providers.dart';
import 'package:life_record/features/pairing/presentation/pairing_page.dart';
import 'package:life_record/features/today/data/today_providers.dart';
import 'package:life_record/features/today/presentation/today_page.dart';

import 'onboarding/fake_auth_data_source.dart';
import 'pairing/fake_pairing_data_source.dart';
import 'today/today_fixtures.dart';

/// 부모님 휴대폰처럼 글씨를 키워도 A 화면(가입·페어링·홈)이 넘치지 않는지 본다.
/// 넘치면 Flutter가 overflow 오류를 내서 테스트가 실패한다.
///
/// 화면은 흔한 안드로이드 폰 크기(411x914dp)로 맞춘다.
void _phoneWithTextScale(WidgetTester tester, double scale) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1080 / 411;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

AppUser _user(UserRole role) => AppUser(
  id: 'usr_test',
  name: '김영희',
  role: role,
  pairingStatus: PairingStatus.unpaired,
);

Future<void> _pumpPairing(
  WidgetTester tester,
  UserRole role, {
  int pairedAfterChecks = 99,
}) async {
  final router = GoRouter(
    initialLocation: '/pairing',
    routes: [
      GoRoute(path: '/pairing', builder: (_, _) => const PairingPage()),
      GoRoute(path: '/today', builder: (_, _) => const Text('오늘 화면')),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) async => _user(role)),
        pairingDataSourceProvider.overrideWithValue(
          FakePairingDataSource(pairedAfterChecks: pairedAfterChecks),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpToday(WidgetTester tester, Map<String, dynamic> json) async {
  final router = GoRouter(
    initialLocation: '/today',
    routes: [GoRoute(path: '/today', builder: (_, _) => const TodayPage())],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todayDataSourceProvider.overrideWithValue(
          FakeTodayDataSource(json: json),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  // 안드로이드 글꼴 크기 설정의 "크게"와 최대값
  for (final scale in [1.3, 2.0]) {
    group('글씨 $scale배', () {
      testWidgets('역할 선택과 이름 입력', (tester) async {
        _phoneWithTextScale(tester, scale);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authDataSourceProvider.overrideWithValue(FakeAuthDataSource()),
            ],
            child: const App(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('누구로 시작할까요?'), findsOneWidget);

        // 글씨가 크면 카드가 화면 아래로 밀리지만 스크롤로 닿아야 한다
        await tester.ensureVisible(find.text('부모님이에요'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('부모님이에요'));
        await tester.pumpAndSettle();
        expect(find.text('성함을 알려주세요'), findsOneWidget);
      });

      testWidgets('자녀 초대 숫자', (tester) async {
        _phoneWithTextScale(tester, scale);
        await _pumpPairing(tester, UserRole.child);
        expect(find.text('482 913'), findsOneWidget);
      });

      testWidgets('연결 완료', (tester) async {
        _phoneWithTextScale(tester, scale);
        await _pumpPairing(tester, UserRole.child, pairedAfterChecks: 1);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        expect(find.text('연결 되었어요!'), findsOneWidget);
        await tester.ensureVisible(find.text('시작하기'));
      });

      testWidgets('부모 숫자 입력', (tester) async {
        _phoneWithTextScale(tester, scale);
        await _pumpPairing(tester, UserRole.parent);
        await tester.enterText(find.byType(TextField), '482913');
        await tester.pump();
        expect(find.text('자녀와 연결해요'), findsOneWidget);
      });

      final todayCases = <String, Map<String, dynamic> Function()>{
        '자녀 답하기 전': () => todayFixture('waiting_for_both'),
        '자녀 답한 뒤': () => todayFixture('waiting_for_parent'),
        '자녀 공개': () => todayFixture('revealed'),
        '부모 답하기 전': () =>
            todayFixture('waiting_for_both')..['viewerRole'] = 'PARENT',
        '부모 보낸 뒤': () => todayFixture('waiting_for_child'),
        '부모 공개': parentRevealedFixture,
      };
      for (final MapEntry(key: name, value: json) in todayCases.entries) {
        testWidgets('오늘 홈: $name', (tester) async {
          _phoneWithTextScale(tester, scale);
          await _pumpToday(tester, json());
          // 글씨가 크면 화면 아래로 밀리지만 스크롤로 닿아야 한다
          await tester.scrollUntilVisible(find.text('지난 이야기 보기'), 200);
          expect(find.text('지난 이야기 보기'), findsOneWidget);
        });
      }
    });
  }
}
