import 'dart:ui' show SemanticsFlag;

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

/// currentUserProvider를 읽은 횟수. 연결 후 다시 읽는지 확인한다.
var _userReads = 0;

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
        currentUserProvider.overrideWith((ref) async {
          _userReads++;
          return user;
        }),
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
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    _userReads = 0;
  });

  testWidgets('가입 정보가 없으면 가입 화면으로 보낸다', (tester) async {
    await _pump(tester, user: null, dataSource: FakePairingDataSource());
    await tester.pumpAndSettle();

    expect(find.text('가입 화면'), findsOneWidget);
  });

  group('자녀', () {
    testWidgets('초대 코드를 한 칸에 한 자리씩 보여준다', (tester) async {
      await _pump(
        tester,
        user: _user(UserRole.child),
        dataSource: FakePairingDataSource(pairedAfterChecks: 99),
      );

      expect(find.text('초대 코드가 만들어졌어요'), findsOneWidget);
      for (final digit in '482913'.split('')) {
        expect(find.text(digit), findsOneWidget);
      }
      expect(find.text('부모님이 코드를 입력하면 자동으로 연결돼요'), findsOneWidget);
    });

    testWidgets('공유하기를 누르면 코드와 방법을 담아 공유 창을 연다', (tester) async {
      final shared = <String>[];
      await _pump(
        tester,
        user: _user(UserRole.child),
        dataSource: FakePairingDataSource(pairedAfterChecks: 99),
        share: (text) async => shared.add(text),
      );

      await tester.tap(find.text('공유하기'));
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

      await tester.tap(find.text('공유하기'));
      await tester.pump();

      expect(find.text('공유 창을 열지 못했어요. 코드를 복사해서 보내 주세요.'), findsOneWidget);
    });

    testWidgets('부모님이 연결하면 연결 완료 화면을 거쳐 오늘 화면으로 넘어간다', (tester) async {
      final dataSource = FakePairingDataSource(pairedAfterChecks: 2);
      await _pump(tester, user: _user(UserRole.child), dataSource: dataSource);

      await tester.pump(const Duration(seconds: 3)); // 첫 확인: 아직
      expect(find.text('부모님과 연결됐어요'), findsNothing);

      await tester.pump(const Duration(seconds: 3)); // 두 번째 확인: 연결됨
      await tester.pumpAndSettle();
      expect(find.text('부모님과 연결됐어요'), findsOneWidget);
      expect(find.text('오늘 화면'), findsNothing);

      final readsBeforeHome = _userReads;
      await tester.tap(find.text('홈으로 가기'));
      await tester.pumpAndSettle();
      expect(find.text('오늘 화면'), findsOneWidget);
      // 마이페이지가 연결 상태를 보도록 사용자 정보를 다시 읽는다
      expect(_userReads, greaterThan(readsBeforeHome));
    });

    testWidgets('코드의 유효 시간이 지나면 만료를 알리고 새 코드를 받는다', (tester) async {
      final dataSource = FakePairingDataSource(
        inviteCode: '111111',
        expiresAt: '2020-01-01T00:00:00+09:00',
        nextInvitations: [('222222', '2099-01-01T00:00:00+09:00')],
        pairedAfterChecks: 99,
      );
      await _pump(tester, user: _user(UserRole.child), dataSource: dataSource);
      // 제목과 오류 안내 두 곳
      expect(find.text('코드가 만료됐어요'), findsNWidgets(2));
      expect(find.text('1'), findsNWidgets(6));

      await tester.tap(find.text('새 코드 받기'));
      await tester.pump();
      await tester.pump();

      expect(find.text('초대 코드가 만들어졌어요'), findsOneWidget);
      expect(find.text('2'), findsNWidgets(6));
    });

    testWidgets('기기 시각이 틀려 새 코드도 지나 보이면 코드를 그대로 보여준다', (tester) async {
      final dataSource = FakePairingDataSource(
        inviteCode: '111111',
        expiresAt: '2020-01-01T00:00:00+09:00',
        pairedAfterChecks: 99,
      ); // 서버가 같은 코드를 돌려줌
      await _pump(tester, user: _user(UserRole.child), dataSource: dataSource);

      await tester.tap(find.text('새 코드 받기'));
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 3));
      }

      expect(dataSource.invitationCalls, 2); // 처음 1번 + 새 코드 받기 1번
      expect(find.text('초대 코드가 만들어졌어요'), findsOneWidget);
      expect(find.text('새 코드 받기'), findsNothing);
    });

    testWidgets('새로 받은 다른 코드도 지나 보이면 한 번에 코드를 보여준다', (tester) async {
      final dataSource = FakePairingDataSource(
        inviteCode: '111111',
        expiresAt: '2020-01-01T00:00:00+09:00',
        nextInvitations: [('222222', '2020-01-01T00:00:00+09:00')],
        pairedAfterChecks: 99,
      );
      await _pump(tester, user: _user(UserRole.child), dataSource: dataSource);

      await tester.tap(find.text('새 코드 받기'));
      await tester.pump();
      await tester.pump();

      expect(dataSource.invitationCalls, 2);
      expect(find.text('초대 코드가 만들어졌어요'), findsOneWidget);
      expect(find.text('2'), findsNWidgets(6));
      expect(find.text('새 코드 받기'), findsNothing);
    });

    testWidgets('앱으로 돌아오면 바로 연결됐는지 확인한다', (tester) async {
      final dataSource = FakePairingDataSource(pairedAfterChecks: 1);
      await _pump(tester, user: _user(UserRole.child), dataSource: dataSource);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('부모님과 연결됐어요'), findsOneWidget);
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
      // 처음 한 번 읽은 뒤, 마이페이지가 연결 상태를 보도록 다시 읽는다
      expect(_userReads, greaterThan(1));
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

    testWidgets('화면 읽기 프로그램이 코드 입력칸을 찾을 수 있다', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        user: _user(UserRole.parent),
        dataSource: FakePairingDataSource(),
      );

      expect(find.semantics.byFlag(SemanticsFlag.isTextField), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('공유받은 코드를 길게 눌러 붙여넣을 수 있다', (tester) async {
      await _pump(
        tester,
        user: _user(UserRole.parent),
        dataSource: FakePairingDataSource(),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enableInteractiveSelection, isTrue);
    });

    testWidgets('연결에 성공하면 연결 완료 화면을 거쳐 오늘 화면으로 넘어간다', (tester) async {
      final dataSource = FakePairingDataSource();
      await _pump(tester, user: _user(UserRole.parent), dataSource: dataSource);

      await tester.enterText(find.byType(TextField), '482913');
      await tester.pump();
      await tester.tap(find.text('연결하기'));
      await tester.pumpAndSettle();

      expect(dataSource.joinedCodes, ['482913']);
      expect(find.text('자녀와 연결됐어요'), findsOneWidget);

      final readsBeforeHome = _userReads;
      await tester.tap(find.text('홈으로 가기'));
      await tester.pumpAndSettle();
      expect(find.text('오늘 화면'), findsOneWidget);
      // 마이페이지가 연결 상태를 보도록 사용자 정보를 다시 읽는다
      expect(_userReads, greaterThan(readsBeforeHome));
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

      expect(find.text('자녀와 연결됐어요'), findsOneWidget);
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
      expect(find.text('이미 다른 분과 연결된 코드예요. 자녀에게 확인해 주세요.'), findsOneWidget);
    });

    testWidgets('이미 사용된 코드면 새 코드를 받으라고 안내한다', (tester) async {
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

      expect(find.text('이미 사용된 코드예요. 자녀에게 새 코드를 받아 주세요.'), findsOneWidget);
      expect(find.text('오늘 화면'), findsNothing);

      // 다시 입력하면 안내가 사라진다
      await tester.enterText(find.byType(TextField), '111111');
      await tester.pump();
      expect(find.textContaining('이미 사용된'), findsNothing);
    });

    testWidgets('없는 코드면 다시 확인하라고 안내한다', (tester) async {
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

      expect(find.text('코드가 맞지 않아요. 다시 확인해 주세요'), findsOneWidget);
      expect(find.text('숫자만 입력할 수 있어요'), findsNothing);
    });
  });

  test('남은 시간을 분·초, 시간·분, 날짜로 알려준다', () {
    final expiresAt = DateTime(2026, 9, 26, 21, 10);
    expect(
      remainingText(const Duration(minutes: 9, seconds: 42), expiresAt),
      '9분 42초 뒤에 코드가 만료돼요',
    );
    expect(
      remainingText(const Duration(hours: 2, minutes: 5), expiresAt),
      '2시간 5분 뒤에 코드가 만료돼요',
    );
    expect(
      remainingText(const Duration(days: 2), expiresAt),
      '9월 26일 오후 9:10까지 쓸 수 있어요',
    );
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
