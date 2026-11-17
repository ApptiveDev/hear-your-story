import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/onboarding/data/auth_providers.dart';
import 'package:life_record/features/onboarding/domain/app_user.dart';
import 'package:life_record/features/onboarding/presentation/onboarding_page.dart';
import 'package:life_record/features/stories/data/stories_providers.dart';
import 'package:life_record/features/stories/presentation/stories_calendar_page.dart';
import 'package:life_record/features/stories/presentation/story_detail_page.dart';

import '../../helpers/phone_size.dart';
import 'fake_stories_repository.dart';

void main() {
  DateTime nov(int day) => DateTime(2026, 11, day);

  FakeStoriesRepository twoStories() => FakeStoriesRepository(
    {},
    months: {
      '2026-11': [
        testStory('1', assignedDate: nov(2)),
        testStory('2', assignedDate: nov(18)),
      ],
      '2026-10': [testStory('3', assignedDate: DateTime(2026, 10, 7))],
    },
  );

  Future<void> pumpPage(
    WidgetTester tester,
    FakeStoriesRepository repo, {
    bool settle = true,
  }) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storiesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: StoriesCalendarPage(now: () => nov(20))),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Finder day(String label) => find.bySemanticsLabel(label);

  testWidgets('이번 달을 month로 불러오고 가장 최근 이야기를 보여준다', (tester) async {
    final repo = twoStories();
    await pumpPage(tester, repo);

    expect(repo.requestedMonths, ['2026-11']);
    expect(find.text('2026년 11월'), findsOneWidget);
    expect(day('11월 2일, 이야기 있음'), findsOneWidget);
    expect(day('11월 18일, 이야기 있음'), findsOneWidget);
    expect(day('11월 3일'), findsOneWidget);
    expect(find.text('질문 2'), findsOneWidget);
    expect(find.text('질문 1'), findsNothing);
  });

  testWidgets('이야기가 있는 날을 누르면 그날의 이야기로 바뀐다', (tester) async {
    await pumpPage(tester, twoStories());

    await tester.tap(day('11월 2일, 이야기 있음'));
    await tester.pumpAndSettle();

    expect(find.text('질문 1'), findsOneWidget);
    expect(find.text('질문 2'), findsNothing);
  });

  testWidgets('이야기가 없는 날은 눌러도 바뀌지 않는다', (tester) async {
    await pumpPage(tester, twoStories());

    await tester.tap(day('11월 3일'));
    await tester.pumpAndSettle();

    expect(find.text('질문 2'), findsOneWidget);
  });

  testWidgets('화면 읽어주기(TalkBack)로도 이야기가 있는 날만 고를 수 있다', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPage(tester, twoStories());

    final empty = tester.getSemantics(day('11월 3일'));
    expect(empty.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);

    final story = tester.getSemantics(day('11월 2일, 이야기 있음'));
    expect(story.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    story.owner!.performAction(story.id, SemanticsAction.tap);
    await tester.pumpAndSettle();

    expect(find.text('질문 1'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('이전 달로 갔다가 돌아오면 고른 날짜가 남아 있다', (tester) async {
    final repo = twoStories();
    await pumpPage(tester, repo);
    await tester.tap(day('11월 2일, 이야기 있음'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('이전 달'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 10월'), findsOneWidget);
    expect(find.text('질문 3'), findsOneWidget);
    await tester.tap(day('10월 7일, 이야기 있음'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('다음 달'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 11월'), findsOneWidget);
    expect(find.text('질문 1'), findsOneWidget);
    expect(repo.requestedMonths, ['2026-11', '2026-10', '2026-11']);
  });

  testWidgets('이번 달에서는 다음 달로 갈 수 없다', (tester) async {
    await pumpPage(tester, twoStories());

    final next = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('다음 달'),
        matching: find.byType(IconButton),
      ),
    );
    expect(next.onPressed, isNull);
  });

  testWidgets('해가 바뀌는 달도 month 형식을 지킨다', (tester) async {
    final repo = twoStories();
    await pumpPage(tester, repo);

    for (var i = 0; i < 11; i++) {
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
    }

    expect(find.text('2025년 12월'), findsOneWidget);
    expect(repo.requestedMonths.last, '2025-12');
  });

  testWidgets('이야기가 없는 달은 안내 문구를 보여준다', (tester) async {
    await pumpPage(tester, FakeStoriesRepository({}));

    expect(find.text('이 달에는 아직 이야기가 없어요'), findsOneWidget);
    expect(find.text('이번 달로 가기'), findsNothing); // 이미 이번 달
  });

  testWidgets('지난 빈 달에서는 이번 달로 바로 돌아갈 수 있다', (tester) async {
    final repo = twoStories();
    await pumpPage(tester, repo);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
    }
    expect(find.text('2026년 9월'), findsOneWidget);

    await tester.tap(find.text('이번 달로 가기'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 11월'), findsOneWidget);
    expect(find.text('질문 2'), findsOneWidget);
  });

  testWidgets('불러오는 중에는 달력과 로딩 표시를 함께 보여준다', (tester) async {
    final repo = twoStories()..gate = Completer<void>();
    await pumpPage(tester, repo, settle: false);
    await tester.pump();

    expect(find.text('달력을 불러오고 있어요'), findsOneWidget);
    expect(find.text('2026년 11월'), findsOneWidget);
    // 불러오는 동안은 날짜를 고를 수 없다
    expect(day('11월 18일, 이야기 있음'), findsNothing);

    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('달력을 불러오고 있어요'), findsNothing);
    expect(find.text('질문 2'), findsOneWidget);
  });

  testWidgets('실패하면 안내와 다시 시도를 보여주고, 다시 시도하면 불러온다', (tester) async {
    final repo = twoStories()..error = ApiException(statusCode: 400);
    await pumpPage(tester, repo);

    expect(find.text('달력을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('질문 2'), findsNothing);

    repo.error = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('다시 시도'), findsNothing);
    expect(find.text('질문 2'), findsOneWidget);
  });

  testWidgets('로그인이 만료되면(401) 가입 화면으로 보낸다', (tester) async {
    usePhoneSize(tester);
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'test-token',
      'current_user': jsonEncode({
        'id': 'child',
        'name': '자녀',
        'role': 'CHILD',
        'pairingStatus': 'PAIRED',
      }),
    });
    final repo = FakeStoriesRepository({})
      ..error = ApiException(statusCode: 401);
    final router = GoRouter(
      initialLocation: '/calendar',
      routes: [
        GoRoute(
          path: '/calendar',
          builder: (_, _) => StoriesCalendarPage(now: () => nov(20)),
        ),
        GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storiesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('카카오로 시작하기'), findsOneWidget);
  });
  // 질문 책장 → 달력 이동은 아래 탭 막대가 맡는다 (test/core/app_tab_shell_test.dart)

  /// 달력 → 이야기 상세로 오갈 수 있게 라우터로 띄운다
  Future<void> pumpWithDetail(
    WidgetTester tester,
    FakeStoriesRepository repo, {
    UserRole? role,
  }) async {
    usePhoneSize(tester);
    final router = GoRouter(
      initialLocation: '/stories/calendar',
      routes: [
        GoRoute(
          path: '/stories',
          builder: (_, _) => const Text('질문 책장'),
          routes: [
            GoRoute(
              path: 'calendar',
              builder: (_, _) => StoriesCalendarPage(now: () => nov(20)),
            ),
            GoRoute(
              path: ':storyId',
              builder: (_, state) => StoryDetailPage(
                storyId: state.pathParameters['storyId']!,
                month: state.uri.queryParameters['month'],
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storiesRepositoryProvider.overrideWithValue(repo),
          if (role != null)
            currentUserProvider.overrideWith(
              (ref) async => AppUser(
                id: 'u1',
                name: '테스트',
                role: role,
                pairingStatus: PairingStatus.paired,
              ),
            ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('이야기를 누르면 그 달 데이터로 이야기 상세를 연다', (tester) async {
    final repo = twoStories();
    await pumpWithDetail(tester, repo);

    await tester.tap(find.text('질문 2'));
    await tester.pumpAndSettle();

    expect(find.text('자녀 답 2'), findsOneWidget);
    expect(repo.requestedMonths, ['2026-11']); // 상세는 다시 요청하지 않는다
  });

  testWidgets('달력에서 연 이야기에서 내 답을 지우면 연결이 끊겨도 바로 반영된다', (tester) async {
    final repo = twoStories();
    await pumpWithDetail(tester, repo, role: UserRole.child);
    await tester.tap(find.text('질문 2'));
    await tester.pumpAndSettle();

    repo.error = ApiException(statusCode: 400); // 지운 뒤 달을 다시 받지 못한다
    await tester.tap(find.text('내 답 지우기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();

    expect(repo.deletedAnswerIds, ['ans_2']);
    expect(find.text('자녀 답 2'), findsNothing);
    expect(find.text('삭제된 답이에요.'), findsOneWidget);
    expect(find.text('내 답 지우기'), findsNothing);

    // 달력도 다시 불러오지 않고 그 달을 그대로 보여준다
    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();
    expect(find.text('질문 2'), findsOneWidget);
    expect(find.text('달력을 불러오지 못했어요'), findsNothing);
  });
}
