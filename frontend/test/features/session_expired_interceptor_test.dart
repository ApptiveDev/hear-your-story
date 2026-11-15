import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_record/app/app.dart';
import 'package:life_record/app/router.dart';
import 'package:life_record/core/network/dio_provider.dart';
import 'package:life_record/features/child_answer/data/child_answer_data_source.dart';
import 'package:life_record/features/child_answer/data/child_answer_providers.dart';
import 'package:life_record/features/child_answer/presentation/child_answer_args.dart';
import 'package:life_record/features/child_answer/presentation/child_answer_page.dart';
import 'package:life_record/features/onboarding/presentation/onboarding_page.dart';
import 'package:life_record/features/parent_answer/data/parent_answer_data_source.dart';
import 'package:life_record/features/parent_answer/data/parent_answer_providers.dart';
import 'package:life_record/features/parent_answer/data/parent_answer_repository_impl.dart';
import 'package:life_record/features/stories/data/stories_data_source.dart';
import 'package:life_record/features/stories/data/stories_providers.dart';
import 'package:life_record/features/stories/domain/story.dart';
import 'package:life_record/features/stories/presentation/widgets/child_story_card.dart';
import 'package:life_record/features/stories/presentation/widgets/parent_story_card.dart';

import 'stories/fake_stories_repository.dart';

/// 서버 대신 모든 요청에 401을 돌려준다. 실제 Dio interceptor를 거치게 하려는 것이다.
class _UnauthorizedAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'errorCode': 'TOKEN_EXPIRED', 'traceId': 'trace'}),
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 화면이 따로 처리하지 않는 곳의 401도 Dio interceptor → 앱 최상단(App)이
/// 로그인 정보를 지우고 카카오 로그인 화면으로 보낸다.
void main() {
  late _UnauthorizedAdapter server;

  Dio unauthorizedDio(Ref ref) =>
      ref.read(dioProvider)..httpClientAdapter = server;

  Future<GoRouter> launch(
    WidgetTester tester,
    Widget page,
    List<Override> overrides,
  ) async {
    server = _UnauthorizedAdapter();
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'test-token',
      'current_user': jsonEncode({
        'id': 'usr',
        'name': '사용자',
        'role': 'CHILD',
        'pairingStatus': 'PAIRED',
      }),
      'device_id': 'keep-device',
    });
    final router = GoRouter(
      initialLocation: '/subject',
      routes: [
        GoRoute(
          path: '/subject',
          builder: (_, _) => Scaffold(body: page),
        ),
        GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [routerProvider.overrideWithValue(router), ...overrides],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> expectSignedOut(WidgetTester tester) async {
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.textContaining('다시 로그인해 주세요.'), findsOneWidget);
    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'access_token'), isNull);
    expect(await storage.read(key: 'current_user'), isNull);
    expect(await storage.read(key: 'device_id'), 'keep-device');
    // 만료된 토큰을 실제로 보냈다가 401을 받은 상황인지 확인
    expect(server.requests, isNotEmpty);
    expect(server.requests.first.headers['Authorization'], 'Bearer test-token');
  }

  final parentAnswerOverride = parentAnswerRepositoryProvider.overrideWith(
    (ref) => ParentAnswerRepositoryImpl(
      ApiParentAnswerDataSource(unauthorizedDio(ref)),
    ),
  );

  testWidgets('부모 이야기 카드: 자녀 답 음성 401', (tester) async {
    await launch(tester, ParentStoryCard(story: testStory('1')), [
      parentAnswerOverride,
    ]);

    await expectSignedOut(tester);
  });

  testWidgets('자녀 이야기 카드: 만료된 음성을 다시 받다가 401', (tester) async {
    final story = testStory('1');
    final parent = story.parentAnswer;
    // 받아 둔 음성 주소가 만료되어 듣기를 누르면 이야기를 다시 조회한다
    final expired = Story(
      storyId: story.storyId,
      assignmentId: story.assignmentId,
      assignedDate: story.assignedDate,
      questionText: story.questionText,
      questionCategory: story.questionCategory,
      parentAnswer: StoryParentAnswer(
        recordingId: parent.recordingId,
        processingStatus: parent.processingStatus,
        summaryText: parent.summaryText,
        originalAudioUrl: 'https://example.test/p.m4a',
        originalAudioExpiresAt: DateTime.now().subtract(
          const Duration(minutes: 1),
        ),
      ),
      childAnswer: story.childAnswer,
      revealedAt: story.revealedAt,
    );
    await launch(tester, ChildStoryCard(story: expired), [
      storiesDataSourceProvider.overrideWith(
        (ref) => ApiStoriesDataSource(unauthorizedDio(ref)),
      ),
    ]);
    expect(server.requests, isEmpty);

    await tester.tap(find.text('듣기'));
    await tester.pumpAndSettle();

    await expectSignedOut(tester);
  });

  testWidgets('여러 요청이 한꺼번에 401을 받아도 안내는 한 번만 띄운다', (tester) async {
    await launch(
      tester,
      ListView(
        children: [
          ParentStoryCard(story: testStory('1')),
          ParentStoryCard(story: testStory('2')),
        ],
      ),
      [parentAnswerOverride],
    );

    expect(server.requests, hasLength(2));
    await expectSignedOut(tester); // 안내 문구가 하나뿐인지도 확인한다
  });

  testWidgets('자녀 답변 보내기 401: 쓰던 글을 맡긴 뒤 가입 화면으로 간다', (tester) async {
    final router = await launch(
      tester,
      const ChildAnswerPage(args: ChildAnswerArgs.demo),
      [
        childAnswerDataSourceProvider.overrideWith(
          (ref) => ApiChildAnswerDataSource(unauthorizedDio(ref)),
        ),
      ],
    );

    await tester.enterText(find.byType(TextField), '숨바꼭질이요');
    await tester.pump();
    await tester.tap(find.text('답변 보내기'));
    await tester.pumpAndSettle();

    await expectSignedOut(tester);

    router.go('/subject');
    await tester.pumpAndSettle();
    expect(find.text('숨바꼭질이요'), findsOneWidget);
  });
}
