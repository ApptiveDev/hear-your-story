import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_record/app/app.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/core/text_scale/text_scale.dart';
import 'package:life_record/core/text_scale/text_scale_button.dart';
import 'package:life_record/core/theme/app_theme.dart';
import 'package:life_record/core/theme/app_tokens.dart';
import 'package:life_record/core/widgets/app_tab_shell.dart';
import 'package:life_record/core/widgets/note_paper.dart';
import 'package:life_record/core/widgets/notebook_paper.dart';
import 'package:life_record/core/widgets/step_layout.dart';
import 'package:life_record/features/account/domain/legal_documents.dart';
import 'package:life_record/features/account/presentation/legal_page.dart';
import 'package:life_record/features/account/presentation/my_page.dart';
import 'package:life_record/features/onboarding/data/auth_providers.dart';
import 'package:life_record/features/onboarding/data/kakao_sign_in.dart';
import 'package:life_record/features/onboarding/domain/app_user.dart';
import 'package:life_record/features/pairing/data/pairing_providers.dart';
import 'package:life_record/features/pairing/presentation/pairing_page.dart';
import 'package:life_record/features/parent_answer/domain/parent_answer.dart';
import 'package:life_record/features/parent_answer/presentation/parent_answer_controller.dart';
import 'package:life_record/features/parent_answer/presentation/parent_answer_page.dart';
import 'package:life_record/features/stories/data/stories_providers.dart';
import 'package:life_record/features/stories/domain/story.dart';
import 'package:life_record/features/stories/presentation/stories_calendar_page.dart';
import 'package:life_record/features/stories/presentation/stories_page.dart';
import 'package:life_record/features/stories/presentation/story_detail_page.dart';
import 'package:life_record/features/today/data/today_providers.dart';
import 'package:life_record/features/today/presentation/today_page.dart';

import 'onboarding/fake_auth_data_source.dart';
import 'pairing/fake_pairing_data_source.dart';
import 'parent_answer/fake_parent_answer_repository.dart';
import 'stories/fake_stories_repository.dart';
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
    routes: [
      // 아래 탭 막대까지 함께 그려서 글씨가 커도 넘치지 않는지 본다
      ShellRoute(
        builder: (context, state, child) =>
            AppTabShell(location: state.uri.path, child: child),
        routes: [GoRoute(path: '/today', builder: (_, _) => const TodayPage())],
      ),
    ],
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

/// 공책의 두 이야기 글이 모두 가로 줄 사이에서 시작하고 끝나는지
void _expectOnPaperLines(WidgetTester tester, double scale) {
  final paper = tester.getTopLeft(find.byType(NotebookPaper)).dy + 12;
  final unit = 30 * scale;
  final texts = find.descendant(
    of: find.byType(NoteEntry),
    matching: find.byWidgetPredicate(
      (w) => w is Text && w.style?.fontSize == AppText.bodyL.fontSize,
    ),
  );
  expect(texts, findsNWidgets(2));
  for (var i = 0; i < 2; i++) {
    final rect = tester.getRect(texts.at(i));
    for (final y in [rect.top, rect.bottom]) {
      final line = (y - paper) / unit;
      expect(line, closeTo(line.roundToDouble(), 0.05));
    }
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  // 안드로이드 글꼴 크기 설정의 "크게"와 최대값
  for (final scale in [1.3, 2.0]) {
    group('글씨 $scale배', () {
      testWidgets('역할 선택과 이름 입력', (tester) async {
        _phoneWithTextScale(tester, scale);
        final auth = FakeAuthDataSource()
          ..kakao = kakaoLoginJson(status: 'REGISTRATION_REQUIRED');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authDataSourceProvider.overrideWithValue(auth),
              kakaoSignInProvider.overrideWithValue(FakeKakao()),
            ],
            child: const App(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('카카오 로그인'));
        await tester.pumpAndSettle();
        expect(find.text('누구로 시작할까요?'), findsOneWidget);

        // 글씨가 크면 카드가 화면 아래로 밀리지만 스크롤로 닿아야 한다
        await tester.ensureVisible(find.text('부모'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('부모'));
        await tester.pump();
        // `다음`은 화면 아래에 고정되어 스크롤 없이 보인다
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
        expect(find.text('이름을 알려 주세요'), findsOneWidget);
      });

      testWidgets('자녀 초대 코드', (tester) async {
        _phoneWithTextScale(tester, scale);
        await _pumpPairing(tester, UserRole.child);
        expect(find.text('초대 코드가 만들어졌어요'), findsOneWidget);
      });

      testWidgets('연결 완료', (tester) async {
        _phoneWithTextScale(tester, scale);
        await _pumpPairing(tester, UserRole.child, pairedAfterChecks: 1);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        expect(find.text('부모님과 연결됐어요'), findsOneWidget);
        await tester.ensureVisible(find.text('홈으로 가기'));
      });

      testWidgets('부모 코드 입력', (tester) async {
        _phoneWithTextScale(tester, scale);
        await _pumpPairing(tester, UserRole.parent);
        await tester.enterText(find.byType(TextField), '482913');
        await tester.pump();
        expect(find.text('초대 코드를 입력해 주세요'), findsOneWidget);
      });

      testWidgets('이야기 달력', (tester) async {
        _phoneWithTextScale(tester, scale);
        final repo = FakeStoriesRepository(
          {},
          months: {
            '2026-11': [testStory('1', assignedDate: DateTime(2026, 11, 28))],
          },
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [storiesRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              home: StoriesCalendarPage(now: () => DateTime(2026, 11, 30)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('2026년 11월'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('질문 1'), 200);
        expect(find.text('질문 1'), findsOneWidget);
      });

      testWidgets('질문 책장: 겹친 카드가 질문을 가리지 않는다', (tester) async {
        _phoneWithTextScale(tester, scale);
        const first = '어릴 때 가장 좋아했던 놀이는 무엇이었고 누구와 함께 했나요?';
        const second = '처음 일을 시작했던 날은 어땠나요?';
        final repo = FakeStoriesRepository({
          null: StoryPage(
            items: [
              testStory(
                '1',
                assignedDate: DateTime(2026, 11, 28),
                questionText: first,
              ),
              testStory(
                '2',
                assignedDate: DateTime(2026, 11, 27),
                questionText: second,
              ),
            ],
            nextCursor: null,
            hasNext: false,
          ),
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [storiesRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(home: StoriesPage()),
          ),
        );
        await tester.pumpAndSettle();

        // 다음 카드 위쪽 여백(16)까지 포함해 질문 아래 끝이 덮이지 않아야 한다
        final firstBottom = tester.getRect(find.text(first)).bottom;
        final nextCardTop = tester.getRect(find.text(second)).top - 16;
        expect(firstBottom, lessThanOrEqualTo(nextCardTop));
      });

      testWidgets('마이페이지', (tester) async {
        _phoneWithTextScale(tester, scale);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWith(
                (ref) async => _user(UserRole.parent),
              ),
              // 들어올 때 다시 받는 사용자 정보는 실패로 두고 저장된 정보로 그린다
              authDataSourceProvider.overrideWithValue(
                FakeAuthDataSource(meError: ApiException()),
              ),
            ],
            child: const MaterialApp(home: MyPage()),
          ),
        );
        await tester.pumpAndSettle();
        // 글씨가 크면 화면 아래로 밀리지만 스크롤로 닿아야 한다
        await tester.scrollUntilVisible(find.text('탈퇴하기'), 200);
        expect(find.text('탈퇴하기'), findsOneWidget);
      });

      testWidgets('개인정보 처리방침·이용약관', (tester) async {
        _phoneWithTextScale(tester, scale);
        for (final document in [privacyPolicy, termsOfService]) {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: LegalPage(
                  key: ValueKey(document.title), // 스크롤 위치를 이어받지 않게
                  document: document,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          // 글씨가 커도 제목과 첫 항목이 보이고, 끝까지 스크롤해도 넘치지 않는다
          expect(find.text(document.title), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text(document.sections.last.heading),
            300,
            maxScrolls: 100,
          );
        }
      });

      testWidgets('헤더: 좁은 폰에서 이전과 글자 크기가 한 줄에 들어간다', (tester) async {
        _phoneWithTextScale(tester, scale);
        // 흔한 폰보다 좁은 360dp
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1080 / 360;
        await tester.pumpWidget(
          ProviderScope(
            // 앱에서 크게를 골라도 합친 배율은 2배까지라 이 검사 범위 안이다
            overrides: [
              initialTextSizeProvider.overrideWithValue(TextSize.large),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: StepLayout(
                  onBack: () {},
                  actions: const [],
                  children: const [Text('내용')],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('이전'), findsOneWidget);
        expect(find.byType(TextScaleButton), findsOneWidget);
        // 버튼 글자가 버튼 밖으로 잘리지 않는다(넘치면 오류 없이 잘리기만 한다)
        final button = tester.getRect(find.byType(TextScaleButton));
        for (final text in ['가', '/가']) {
          final label = tester.getRect(find.text(text));
          expect(button.expandToInclude(label), button);
        }
        // 버튼은 오른쪽 여백에 붙는다
        expect(button.right, 360 - AppSizes.screenPadding);
      });

      testWidgets('부모 답변: 두 이야기 모두 공책 줄에 맞는다', (tester) async {
        _phoneWithTextScale(tester, scale);
        final repository = FakeParentAnswerRepository()
          ..today = const ParentAnswer(
            questionText: '어릴 때 가장 좋아했던 간식은 뭐였어요?',
            revealStatus: 'REVEALED',
            canView: true,
            answerId: 'ans_1',
            text: '나는 엄마가 싸준 계란말이 도시락! 소풍 날 뚜껑을 열면 제일 먼저 먹었어요.',
            myText: '겨울이면 할머니가 구워주신 군고구마가 제일 좋았단다.',
          )
          ..audio = const AnswerAudio(status: AnswerTtsStatus.failed);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: ParentAnswerPage(
                  controller: ParentAnswerController(repository),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _expectOnPaperLines(tester, scale);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('책장 상세: 두 이야기 모두 공책 줄에 맞는다', (tester) async {
        _phoneWithTextScale(tester, scale);
        final repo = FakeStoriesRepository({
          null: StoryPage(
            items: [testStory('1', summaryText: '아주 긴 부모님 답 ' * 8)],
            nextCursor: null,
            hasNext: false,
          ),
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [storiesRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const StoryDetailPage(storyId: 'story_1'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _expectOnPaperLines(tester, scale);
        await tester.pumpWidget(const SizedBox.shrink());
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
          // 글씨가 크면 화면 아래로 밀리지만 끝까지 스크롤할 수 있어야 한다
          await tester.drag(find.byType(ListView), const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(AppTabBar), findsOneWidget);
        });
      }
    });
  }
}
