import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/onboarding/data/auth_providers.dart';
import 'package:life_record/features/onboarding/domain/app_user.dart';
import 'package:life_record/features/pairing/data/pairing_providers.dart';
import 'package:life_record/features/pairing/domain/pairing_repository.dart';
import 'package:life_record/features/pairing/presentation/expiry_format.dart';
import 'package:life_record/features/pairing/presentation/invite_share.dart';
import 'package:life_record/features/pairing/presentation/pairing_page.dart';

import 'fake_pairing_data_source.dart';
import '../../helpers/phone_size.dart';

AppUser _user(UserRole role) => AppUser(
  id: 'usr_test',
  name: '테스트',
  role: role,
  pairingStatus: PairingStatus.unpaired,
);

Future<void> _pump(
  WidgetTester tester, {
  required AppUser? user,
  required FakePairingDataSource dataSource,
  Future<void> Function(String text)? share,
}) async {
  usePhoneSize(tester);
  final router = GoRouter(
    initialLocation: '/pairing',
    routes: [
      GoRoute(path: '/pairing', builder: (_, _) => const PairingPage()),
      GoRoute(path: '/today', builder: (_, _) => const Text('오늘 화면')),
      GoRoute(path: '/onboarding', builder: (_, _) => const Text('가입 화면')),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) async => user),
        pairingDataSourceProvider.overrideWithValue(dataSource),
        shareTextProvider.overrideWithValue(share ?? (_) async {}),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
}

FilledButton _button(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('가입 정보가 없으면 가입 화면으로 보낸다', (tester) async {
    await _pump(tester, user: null, dataSource: FakePairingDataSource());
    await tester.pumpAndSettle();

    expect(find.text('가입 화면'), findsOneWidget);
  });

  group('자녀', () {
    testWidgets('초대 숫자를 세 자리씩 띄워 보여준다', (tester) async {
      await _pump(
        tester,
        user: _user(UserRole.child),
        dataSource: FakePairingDataSource(pairedAfterChecks: 99),
      );

      expect(find.text('482 913'), findsOneWidget);
      expect(find.text('연결되면 자동으로 넘어가요.'), findsOneWidget);
    });

    testWidgets('부모님께 보내기를 누르면 숫자와 방법을 담아 공유 창을 연다', (tester) async {
      final shared = <String>[];
      await _pump(
        tester,
        user: _user(UserRole.child),
        dataSource: FakePairingDataSource(pairedAfterChecks: 99),
        share: (text) async => shared.add(text),
      );

      await tester.tap(find.text('부모님께 보내기'));
      await tester.pump();

      expect(shared, hasLength(1));
      expect(shared.single, contains('482 913'));
      expect(shared.single, contains('"부모님"을 고른 뒤'));
    });

    testWidgets('공유 창을 못 열면 복사해서 보내라고 안내한다', (tester) async {
      await _pump(
        tester,
        user: _user(UserRole.child),
        dataSource: FakePairingDataSource(pairedAfterChecks: 99),
        share: (_) async => throw Exception('no share sheet'),
      );

      await tester.tap(find.text('부모님께 보내기'));
      await tester.pump();

      expect(find.text('보내기를 열지 못했어요. 숫자를 복사해서 보내 주세요.'), findsOneWidget);
    });

    testWidgets('부모님이 연결하면 연결 완료 화면을 거쳐 오늘 화면으로 넘어간다', (tester) async {
      final dataSource = FakePairingDataSource(pairedAfterChecks: 2);
      await _pump(tester, user: _user(UserRole.child), dataSource: dataSource);

      await tester.pump(const Duration(seconds: 3)); // 첫 확인: 아직
      expect(find.text('연결 되었어요!'), findsNothing);

      await tester.pump(const Duration(seconds: 3)); // 두 번째 확인: 연결됨
      await tester.pumpAndSettle();
      expect(find.text('연결 되었어요!'), findsOneWidget);
      expect(find.textContaining('이제 부모님과'), findsOneWidget);
      expect(find.text('오늘 화면'), findsNothing);

      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();
      expect(find.text('오늘 화면'), findsOneWidget);
    });

    testWidgets('숫자의 유효 시간이 지나면 새 숫자를 받아 보여준다', (tester) async {
      final dataSource = FakePairingDataSource(
        inviteCode: '111111',
        expiresAt: '2020-01-01T00:00:00+09:00',
        nextInvitations: [('222222', '2099-01-01T00:00:00+09:00')],
        pairedAfterChecks: 99,
      );
      await _pump(tester, user: _user(UserRole.child), dataSource: dataSource);
      expect(find.text('111 111'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump();

      expect(find.text('222 222'), findsOneWidget);
      expect(find.textContaining('새 숫자로 바뀌었어요'), findsOneWidget);
    });

    testWidgets('기기 시각이 틀려 새 숫자도 지나 보이면 계속 다시 받지 않는다', (tester) async {
      final dataSource = FakePairingDataSource(
        inviteCode: '111111',
        expiresAt: '2020-01-01T00:00:00+09:00',
        pairedAfterChecks: 99,
      ); // 서버가 같은 숫자를 돌려줌
      await _pump(tester, user: _user(UserRole.child), dataSource: dataSource);

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 3));
      }

      expect(dataSource.invitationCalls, 2); // 처음 1번 + 만료로 1번
      expect(find.text('111 111'), findsOneWidget);
    });

    testWidgets('앱으로 돌아오면 바로 연결됐는지 확인한다', (tester) async {
      final dataSource = FakePairingDataSource(pairedAfterChecks: 1);
      await _pump(tester, user: _user(UserRole.child), dataSource: dataSource);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('연결 되었어요!'), findsOneWidget);
    });

    testWidgets('이미 연결된 자녀는 바로 오늘 화면으로 넘어간다', (tester) async {
      await _pump(
        tester,
        user: _user(UserRole.child),
        dataSource: FakePairingDataSource(
          invitationError: ApiException(
            statusCode: 409,
            errorCode: 'ALREADY_PAIRED',
          ),
          pairedAfterChecks: 99,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('오늘 화면'), findsOneWidget);
    });
  });

  group('부모님', () {
    testWidgets('6자리를 다 넣어야 연결하기를 누를 수 있다', (tester) async {
      await _pump(
        tester,
        user: _user(UserRole.parent),
        dataSource: FakePairingDataSource(),
      );

      expect(_button(tester).onPressed, isNull);
      await tester.enterText(find.byType(TextField), '48291');
      await tester.pump();
      expect(_button(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '482913');
      await tester.pump();
      expect(_button(tester).onPressed, isNotNull);
    });

    testWidgets('연결에 성공하면 연결 완료 화면을 거쳐 오늘 화면으로 넘어간다', (tester) async {
      final dataSource = FakePairingDataSource();
      await _pump(tester, user: _user(UserRole.parent), dataSource: dataSource);

      await tester.enterText(find.byType(TextField), '482913');
      await tester.pump();
      await tester.tap(find.text('연결하기'));
      await tester.pumpAndSettle();

      expect(dataSource.joinedCodes, ['482913']);
      expect(find.text('연결 되었어요!'), findsOneWidget);
      expect(find.textContaining('이제 자녀와'), findsOneWidget);

      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();
      expect(find.text('오늘 화면'), findsOneWidget);
    });

    testWidgets('이미 연결돼 있으면 연결된 것으로 본다', (tester) async {
      await _pump(
        tester,
        user: _user(UserRole.parent),
        dataSource: FakePairingDataSource(
          joinError: ApiException(statusCode: 409, errorCode: 'ALREADY_PAIRED'),
        ),
      );

      await tester.enterText(find.byType(TextField), '482913');
      await tester.pump();
      await tester.tap(find.text('연결하기'));
      await tester.pumpAndSettle();

      expect(find.text('연결 되었어요!'), findsOneWidget);
    });

    testWidgets('자녀가 이미 다른 분과 연결된 숫자면 머물며 안내한다', (tester) async {
      await _pump(
        tester,
        user: _user(UserRole.parent),
        dataSource: FakePairingDataSource(
          joinError: ApiException(statusCode: 409, errorCode: 'ALREADY_PAIRED'),
          pairedAfterChecks: 99,
        ),
      );

      await tester.enterText(find.byType(TextField), '482913');
      await tester.pump();
      await tester.tap(find.text('연결하기'));
      await tester.pumpAndSettle();

      expect(find.text('오늘 화면'), findsNothing);
      expect(find.text('이미 다른 분과 연결된 숫자예요. 자녀에게 확인해 주세요.'), findsOneWidget);
    });

    testWidgets('이미 사용된 숫자면 새 숫자를 받으라고 안내한다', (tester) async {
      await _pump(
        tester,
        user: _user(UserRole.parent),
        dataSource: FakePairingDataSource(
          joinError: ApiException(
            statusCode: 409,
            errorCode: 'INVITE_CODE_USED',
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '482913');
      await tester.pump();
      await tester.tap(find.text('연결하기'));
      await tester.pumpAndSettle();

      expect(find.text('이미 사용된 숫자예요. 자녀에게 새 숫자를 받아 주세요.'), findsOneWidget);
      expect(find.text('오늘 화면'), findsNothing);

      // 다시 입력하면 안내가 사라진다
      await tester.enterText(find.byType(TextField), '111111');
      await tester.pump();
      expect(find.textContaining('이미 사용된'), findsNothing);
    });

    testWidgets('없는 숫자면 다시 확인하라고 안내한다', (tester) async {
      await _pump(
        tester,
        user: _user(UserRole.parent),
        dataSource: FakePairingDataSource(
          joinError: ApiException(
            statusCode: 404,
            errorCode: 'INVITE_CODE_NOT_FOUND',
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '000000');
      await tester.pump();
      await tester.tap(find.text('연결하기'));
      await tester.pumpAndSettle();

      expect(find.text('숫자를 다시 확인해 주세요.'), findsOneWidget);
    });
  });

  test('만료 시각을 오전·오후로 보여준다', () {
    expect(formatExpiry(DateTime(2026, 9, 26, 21, 10)), '9월 26일 오후 9:10');
    expect(formatExpiry(DateTime(2026, 9, 26, 0, 5)), '9월 26일 오전 12:05');
  });

  test('초대 문구에 띄어 쓴 숫자와 쓸 수 있는 시각을 넣는다', () {
    final message = inviteShareMessage(
      Invitation(inviteCode: '482913', expiresAt: DateTime(2026, 9, 28, 21, 6)),
    );

    expect(message, startsWith('[들려줘요] 초대 숫자: 482 913\n'));
    expect(message, contains('9월 28일 오후 9:06까지'));
  });
}
