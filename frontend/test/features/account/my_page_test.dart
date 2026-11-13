import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/core/storage/token_storage.dart';
import 'package:life_record/features/account/data/account_providers.dart';
import 'package:life_record/features/account/data/account_repository_impl.dart';
import 'package:life_record/features/account/domain/account_repository.dart';
import 'package:life_record/features/account/presentation/account_deleted_page.dart';
import 'package:life_record/features/account/presentation/my_page.dart';
import 'package:life_record/features/onboarding/data/auth_providers.dart';

import '../../helpers/phone_size.dart';

Future<void> _pump(
  WidgetTester tester, {
  ApiException? deleteError,
  Duration deleteDelay = Duration.zero,
  AccountRepository? repository,
  String role = 'PARENT',
}) async {
  usePhoneSize(tester);
  FlutterSecureStorage.setMockInitialValues({
    'access_token': 'token',
    'current_user': jsonEncode({
      'id': 'usr_test',
      'name': '김민지',
      'role': role,
      'pairingStatus': 'PAIRED',
    }),
  });
  final router = GoRouter(
    initialLocation: '/my',
    routes: [
      GoRoute(path: '/my', builder: (_, _) => const MyPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const Text('가입 화면')),
      GoRoute(
        path: '/account-deleted',
        builder: (_, _) => const AccountDeletedPage(),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountRepositoryProvider.overrideWithValue(
          repository ??
              MockAccountRepository(failWith: deleteError, delay: deleteDelay),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// ApiException이 아닌 예외(저장소 오류 등)를 던지는 저장소
class _BrokenAccountRepository implements AccountRepository {
  @override
  Future<void> deleteAccount() async => throw StateError('예상 밖 오류');
}

bool _canPop(WidgetTester tester) => tester
    .widget<PopScope>(
      find.descendant(of: find.byType(MyPage), matching: find.byType(PopScope)),
    )
    .canPop;

Future<String?> _token() => TokenStorage(const FlutterSecureStorage()).read();

Future<void> _tapAndConfirm(
  WidgetTester tester, {
  required String item,
  required String action,
}) async {
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('이름·역할·앱 버전을 보여준다', (tester) async {
    await _pump(tester);

    expect(find.text('김민지'), findsOneWidget);
    expect(find.text('부모님'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
  });

  testWidgets('자녀는 자녀로 보인다', (tester) async {
    await _pump(tester, role: 'CHILD');

    expect(find.text('자녀'), findsOneWidget);
  });

  testWidgets('처리방침·문의 주소가 정해지기 전에는 준비 중 안내를 보여준다', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('개인정보 처리방침'));
    await tester.pumpAndSettle();
    expect(find.text('준비 중이에요.'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('문의하기'));
    await tester.pumpAndSettle();
    expect(find.text('준비 중이에요.'), findsOneWidget);
  });

  group('로그아웃', () {
    testWidgets('확인하면 로그인 정보를 지우고 가입 화면으로 간다', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      expect(find.text(logoutConfirmMessage), findsOneWidget);
      await tester.tap(find.text('로그아웃').last);
      await tester.pumpAndSettle();

      expect(find.text('가입 화면'), findsOneWidget);
      expect(await _token(), isNull);
      final container = ProviderScope.containerOf(
        tester.element(find.text('가입 화면')),
      );
      expect(await container.read(currentUserProvider.future), isNull);
    });

    testWidgets('취소하면 그대로 둔다', (tester) async {
      await _pump(tester);

      await _tapAndConfirm(tester, item: '로그아웃', action: '취소');

      expect(find.text('마이페이지'), findsOneWidget);
      expect(await _token(), 'token');
    });
  });

  group('탈퇴', () {
    testWidgets('확인하면 로그인 정보를 지우고 완료 화면으로 간다', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('탈퇴하기'));
      await tester.pumpAndSettle();
      expect(find.text(deleteConfirmMessage), findsOneWidget);
      await tester.tap(find.text('탈퇴하기').last);
      await tester.pumpAndSettle();

      expect(find.text('탈퇴를 시작했어요'), findsOneWidget);
      expect(await _token(), isNull);
    });

    testWidgets('취소하면 아무것도 지우지 않는다', (tester) async {
      await _pump(tester);

      await _tapAndConfirm(tester, item: '탈퇴하기', action: '취소');

      expect(find.text('마이페이지'), findsOneWidget);
      expect(await _token(), 'token');
    });

    testWidgets('실패하면 안내하고 로그인 정보는 그대로 둔다', (tester) async {
      await _pump(tester, deleteError: ApiException(statusCode: 500));

      await tester.tap(find.text('탈퇴하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('탈퇴하기').last);
      await tester.pumpAndSettle();

      expect(find.text('잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(find.text('마이페이지'), findsOneWidget);
      expect(await _token(), 'token');
    });

    testWidgets('이미 탈퇴를 처리하는 중(409)이면 완료로 본다', (tester) async {
      await _pump(
        tester,
        deleteError: ApiException(
          statusCode: 409,
          errorCode: 'ACCOUNT_DELETION_IN_PROGRESS',
        ),
      );

      await tester.tap(find.text('탈퇴하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('탈퇴하기').last);
      await tester.pumpAndSettle();

      expect(find.text('탈퇴를 시작했어요'), findsOneWidget);
      expect(await _token(), isNull);
    });

    testWidgets('로그인이 만료되면(401) 가입 화면으로 보낸다', (tester) async {
      await _pump(tester, deleteError: ApiException(statusCode: 401));

      await tester.tap(find.text('탈퇴하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('탈퇴하기').last);
      await tester.pumpAndSettle();

      expect(find.text('가입 화면'), findsOneWidget);
    });

    testWidgets('완료 화면에서 처음으로 가면 가입 화면이 열린다', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('탈퇴하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('탈퇴하기').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('처음으로'));
      await tester.pumpAndSettle();

      expect(find.text('가입 화면'), findsOneWidget);
    });
    testWidgets('요청하는 동안에는 뒤로 가지 못하고, 끝나면 완료 화면으로 간다', (tester) async {
      await _pump(tester, deleteDelay: const Duration(seconds: 1));
      expect(_canPop(tester), isTrue);

      await tester.tap(find.text('탈퇴하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('탈퇴하기').last);
      await tester.pump(const Duration(milliseconds: 100)); // 요청 중
      expect(_canPop(tester), isFalse);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('탈퇴를 시작했어요'), findsOneWidget);
      expect(await _token(), isNull);
    });

    testWidgets('실패하면 뒤로 갈 수 있게 풀고 다시 시도할 수 있다', (tester) async {
      await _pump(tester, deleteError: ApiException(statusCode: 500));

      await tester.tap(find.text('탈퇴하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('탈퇴하기').last);
      await tester.pumpAndSettle();

      expect(_canPop(tester), isTrue);
    });

    testWidgets('예상 밖 오류여도 안내하고 화면이 막히지 않는다', (tester) async {
      await _pump(tester, repository: _BrokenAccountRepository());

      await tester.tap(find.text('탈퇴하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('탈퇴하기').last);
      await tester.pumpAndSettle();

      expect(find.text('문제가 생겼어요. 다시 시도해 주세요.'), findsOneWidget);
      expect(_canPop(tester), isTrue);
      expect(await _token(), 'token');
      // 다른 항목을 다시 누를 수 있다
      await tester.tap(find.text('개인정보 처리방침'));
      await tester.pumpAndSettle();
      expect(find.text('준비 중이에요.'), findsOneWidget);
    });

    testWidgets('요청 중 화면이 사라져도 로그인 정보를 지운다', (tester) async {
      await _pump(tester, deleteDelay: const Duration(seconds: 1));

      await tester.tap(find.text('탈퇴하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('탈퇴하기').last);
      await tester.pump(const Duration(milliseconds: 100));

      // 다른 곳(예: 401 처리)에서 화면을 닫은 상황
      final router = GoRouter.of(tester.element(find.byType(MyPage)));
      router.go('/onboarding');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(await _token(), isNull);
    });
  });
}
