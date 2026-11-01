import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/child_answer/data/child_answer_providers.dart';
import 'package:life_record/features/child_answer/presentation/child_answer_args.dart';
import 'package:life_record/features/child_answer/presentation/child_answer_page.dart';
import 'package:life_record/features/onboarding/presentation/onboarding_page.dart';
import 'package:life_record/features/stories/data/stories_providers.dart';
import 'package:life_record/features/stories/domain/story.dart';
import 'package:life_record/features/stories/presentation/stories_page.dart';

import 'child_answer/fake_child_answer_repository.dart';
import 'stories/fake_stories_repository.dart';

/// 지난 이야기·자녀 답변 화면도 401이면 로그인 정보를 지우고 가입 화면으로 보낸다.
void main() {
  final expired = ApiException(statusCode: 401, errorCode: 'TOKEN_EXPIRED');

  Future<void> pump(WidgetTester tester, Widget page, List overrides) async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'test-token',
      'current_user': jsonEncode({
        'id': 'child',
        'name': '자녀',
        'role': 'CHILD',
        'pairingStatus': 'PAIRED',
      }),
      'device_id': 'keep-device',
    });
    final router = GoRouter(
      initialLocation: '/subject',
      routes: [
        GoRoute(path: '/subject', builder: (_, _) => page),
        GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...overrides],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expectSignedOut(WidgetTester tester) async {
    expect(find.text('누구로 시작할까요?'), findsOneWidget);
    expect(find.textContaining('같은 역할을 고르면 이야기가 그대로 이어져요.'), findsOneWidget);
    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'access_token'), isNull);
    expect(await storage.read(key: 'current_user'), isNull);
    expect(await storage.read(key: 'device_id'), 'keep-device');
  }

  testWidgets('지난 이야기 첫 페이지 401', (tester) async {
    final repo = FakeStoriesRepository({})..error = expired;
    await pump(tester, const StoriesPage(), [
      storiesRepositoryProvider.overrideWithValue(repo),
    ]);

    await expectSignedOut(tester);
  });

  testWidgets('지난 이야기 더 보기 401', (tester) async {
    final repo = FakeStoriesRepository({
      null: StoryPage(items: [testStory('1')], nextCursor: 'c2', hasNext: true),
    });
    await pump(tester, const StoriesPage(), [
      storiesRepositoryProvider.overrideWithValue(repo),
    ]);

    repo.error = expired;
    await tester.tap(find.text('이전 이야기 더 보기'));
    await tester.pumpAndSettle();

    await expectSignedOut(tester);
  });

  testWidgets('자녀 답변 보내기 401', (tester) async {
    final repo = FakeChildAnswerRepository(error: expired);
    await pump(tester, const ChildAnswerPage(args: ChildAnswerArgs.demo), [
      childAnswerRepositoryProvider.overrideWithValue(repo),
    ]);

    await tester.enterText(find.byType(TextField), '숨바꼭질이요');
    await tester.pump();
    await tester.tap(find.text('답변 보내기'));
    await tester.pumpAndSettle();

    await expectSignedOut(tester);
  });
}
