import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/onboarding/data/auth_providers.dart';
import 'package:life_record/features/onboarding/domain/app_user.dart';
import 'package:life_record/features/parent_answer/data/parent_answer_providers.dart';
import 'package:life_record/features/stories/data/stories_providers.dart';
import 'package:life_record/features/stories/domain/story.dart';
import 'package:go_router/go_router.dart';
import 'package:life_record/features/stories/presentation/stories_page.dart';
import 'package:life_record/features/stories/presentation/story_detail_page.dart';
import 'package:life_record/features/stories/presentation/widgets/story_card_frame.dart';

import '../parent_answer/fake_parent_answer_repository.dart';
import 'fake_stories_repository.dart';

void main() {
  /// [role]을 주면 그 역할로 로그인한 상태, 안 주면 역할을 모르는 상태(자녀 카드)
  Future<void> pumpPage(
    WidgetTester tester,
    FakeStoriesRepository repo, {
    UserRole? role,
    FakeParentAnswerRepository? audioRepo,
    String? open,
  }) async {
    final router = GoRouter(
      initialLocation: '/stories',
      routes: [
        GoRoute(
          path: '/stories',
          builder: (_, _) => const StoriesPage(),
          routes: [
            GoRoute(
              path: ':storyId',
              builder: (_, state) =>
                  StoryDetailPage(storyId: state.pathParameters['storyId']!),
            ),
          ],
        ),
        GoRoute(path: '/today', builder: (_, _) => const Text('오늘 화면')),
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
          if (audioRepo != null)
            parentAnswerRepositoryProvider.overrideWithValue(audioRepo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    // 목록 카드에는 질문만 있어서, 답·듣기·지우기는 이야기 상세에서 본다
    if (open != null) {
      await tester.tap(find.text(open));
      await tester.pumpAndSettle();
    }
  }

  /// 이야기 하나짜리 첫 페이지
  FakeStoriesRepository oneStory(Story story) => FakeStoriesRepository({
    null: StoryPage(items: [story], nextCursor: null, hasNext: false),
  });

  // ───────────── 목록·페이징·상태 (역할과 무관) ─────────────

  testWidgets('이야기 카드와 더 보기 버튼이 보이고, 누르면 다음 이야기가 붙는다', (tester) async {
    final repo = FakeStoriesRepository({
      null: StoryPage(items: [testStory('1')], nextCursor: 'c2', hasNext: true),
      'c2': StoryPage(
        items: [testStory('2')],
        nextCursor: null,
        hasNext: false,
      ),
    });
    await pumpPage(tester, repo);

    expect(find.text('질문 1'), findsOneWidget);
    expect(find.text('자녀 답 1'), findsNothing); // 답은 상세에서 본다

    await tester.tap(find.text('이전 이야기 더 보기'));
    await tester.pumpAndSettle();

    expect(find.text('질문 2'), findsOneWidget);
    expect(find.text('이전 이야기 더 보기'), findsNothing); // 마지막 페이지
  });

  testWidgets('이야기가 없으면 빈 화면 안내', (tester) async {
    final repo = FakeStoriesRepository({
      null: const StoryPage(items: [], nextCursor: null, hasNext: false),
    });
    await pumpPage(tester, repo);

    expect(find.text('아직 공개된 이야기가 없어요'), findsOneWidget);
  });

  testWidgets('첫 로딩 실패 → 안내와 다시 시도 → 성공', (tester) async {
    final repo = FakeStoriesRepository({
      null: StoryPage(
        items: [testStory('1')],
        nextCursor: null,
        hasNext: false,
      ),
    })..error = ApiException();
    await pumpPage(tester, repo);
    // 연결 오류는 몇 번 다시 시도한다. 로딩 화면이 움직이지 않아 pumpAndSettle이
    // 기다려 주지 않으므로 다시 시도가 끝날 만큼 시간을 넘긴다.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('이야기를 불러오지 못했어요'), findsOneWidget);
    expect(find.textContaining('인터넷 연결을 확인해 주세요.'), findsOneWidget);

    repo.error = null; // 연결이 돌아왔다고 가정
    await tester.tap(find.text('다시 불러오기'));
    await tester.pumpAndSettle();

    expect(find.text('질문 1'), findsOneWidget);
  });

  testWidgets('AI 정리 실패 이야기는 안내 문구를 보여준다', (tester) async {
    const notice = '음성 정리는 실패했지만 원본 녹음은 안전하게 저장되었습니다.';
    final repo = FakeStoriesRepository({
      null: StoryPage(
        items: [
          testStory(
            '1',
            summaryText: null,
            processingStatus: 'FAILED',
            processingNotice: notice,
          ),
        ],
        nextCursor: null,
        hasNext: false,
      ),
    });
    await pumpPage(tester, repo, open: '질문 1');

    expect(find.text(notice), findsOneWidget);
  });

  test('날짜는 "9월 24일 목요일" 형식', () {
    expect(StoryCardFrame.formatDate(DateTime(2026, 9, 24)), '9월 24일 목요일');
  });

  // ───────────── 역할별 화면 ─────────────

  testWidgets('부모: 자녀 답 TTS와 내 답(글)만 보이고 내 목소리 재생은 없다', (tester) async {
    final audioRepo = FakeParentAnswerRepository();
    await pumpPage(
      tester,
      oneStory(testStory('1', originalAudioUrl: 'https://example.test/p.m4a')),
      role: UserRole.parent,
      audioRepo: audioRepo,
      open: '질문 1',
    );

    expect(find.text('자녀 답 들어보기'), findsOneWidget);
    expect(find.text('자녀 답 1'), findsOneWidget);
    expect(find.text('내 이야기'), findsOneWidget);
    expect(find.text('자녀의 이야기'), findsOneWidget);
    expect(find.text('정리된 부모님 답'), findsOneWidget);
    // 공책 위에서 내 이야기가 상대 이야기보다 먼저 나온다
    expect(
      tester.getTopLeft(find.text('내 이야기')).dy,
      lessThan(tester.getTopLeft(find.text('자녀의 이야기')).dy),
    );
    expect(find.text('부모님 목소리 듣기'), findsNothing); // URL이 있어도 부모 화면엔 없음
    expect(audioRepo.audioCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink()); // 오디오 플레이어 정리
  });

  testWidgets('자녀: 부모님 목소리와 내가 쓴 답이 보이고 TTS API는 부르지 않는다', (tester) async {
    final audioRepo = FakeParentAnswerRepository();
    await pumpPage(
      tester,
      oneStory(testStory('1', originalAudioUrl: 'https://example.test/p.m4a')),
      role: UserRole.child,
      audioRepo: audioRepo,
      open: '질문 1',
    );

    expect(find.text('부모님 목소리 듣기'), findsOneWidget);
    expect(find.text('내 이야기'), findsOneWidget);
    expect(find.text('부모님의 이야기'), findsOneWidget);
    expect(find.text('자녀 답 들어보기'), findsNothing);
    expect(audioRepo.audioCalls, 0); // 부모 전용 API라 자녀는 호출하면 안 됨

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('상세: 내 답 지우기는 공책 바로 아래, 듣기는 화면 아래에 고정된다', (tester) async {
    await pumpPage(
      tester,
      oneStory(testStory('1', originalAudioUrl: 'https://example.test/p.m4a')),
      role: UserRole.child,
      audioRepo: FakeParentAnswerRepository(),
      open: '질문 1',
    );

    final notebook = tester.getBottomLeft(find.text('부모님의 이야기')).dy;
    final delete = tester.getTopLeft(find.text('내 답 지우기')).dy;
    final listen = tester.getTopLeft(find.text('부모님 목소리 듣기')).dy;
    expect(delete, greaterThan(notebook)); // 공책 아래
    expect(listen, greaterThan(delete)); // 듣기는 그보다 아래(내용 끝)

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('상세: 글이 길면 듣기는 고정되지 않고 스크롤해서 닿는다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPage(
      tester,
      oneStory(
        testStory(
          '1',
          summaryText: '아주 긴 부모님 답 ' * 30,
          originalAudioUrl: 'https://example.test/p.m4a',
        ),
      ),
      role: UserRole.child,
      audioRepo: FakeParentAnswerRepository(),
      open: '질문 1',
    );

    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    // 처음에는 화면 밖에 있다가 스크롤하면 보인다
    expect(tester.getTopLeft(find.text('부모님 목소리 듣기')).dy, greaterThan(screen));
    await tester.scrollUntilVisible(find.text('부모님 목소리 듣기'), 300);
    expect(
      tester.getBottomLeft(find.text('부모님 목소리 듣기')).dy,
      lessThanOrEqualTo(screen),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // ───────────── 삭제된 답 (계약 5.12·5.13 초안) ─────────────

  testWidgets('자녀: 부모님이 지운 녹음은 재생 버튼 없이 안내만 보인다', (tester) async {
    await pumpPage(
      tester,
      oneStory(
        testStory(
          '1',
          parentDeleted: true,
          processingNotice: '부모님이 이 음성 기록을 삭제했어요.',
          // 주소가 남아 있어도 지운 녹음은 재생하지 않는다
          originalAudioUrl: 'https://example.test/p.m4a',
        ),
      ),
      role: UserRole.child,
      open: '질문 1',
    );

    expect(find.text('부모님 목소리 듣기'), findsNothing);
    expect(find.text('부모님이 이 음성 기록을 삭제했어요.'), findsOneWidget);
    expect(find.text('글로 정리하고 있어요.'), findsNothing); // 처리 중으로 오해하지 않음
    expect(find.text('자녀 답 1'), findsOneWidget); // 내 답은 그대로
  });

  testWidgets('자녀: 안내 문구가 없어도 기본 삭제 안내를 보여준다', (tester) async {
    await pumpPage(
      tester,
      oneStory(testStory('1', parentDeleted: true)),
      role: UserRole.child,
      open: '질문 1',
    );

    expect(find.text(deletedParentAnswerText), findsOneWidget);
  });

  testWidgets('부모: 지워진 자녀 답은 TTS를 요청하지 않고 안내만 보인다', (tester) async {
    final audioRepo = FakeParentAnswerRepository();
    await pumpPage(
      tester,
      oneStory(testStory('1', childDeleted: true)),
      role: UserRole.parent,
      audioRepo: audioRepo,
      open: '질문 1',
    );

    expect(find.text('자녀 답 들어보기'), findsNothing);
    expect(find.text(deletedChildAnswerText), findsOneWidget);
    expect(find.text('정리된 부모님 답'), findsOneWidget); // 내 답은 그대로
    expect(audioRepo.audioCalls, 0);
  });

  // ───────────── 내 답 지우기 (각자 본인 답만 개별 삭제) ─────────────

  testWidgets('부모: 확인 후 내 녹음만 지우고 자녀 답은 남는다', (tester) async {
    final repo = oneStory(testStory('1', ttsStatus: 'NOT_REQUESTED'));
    await pumpPage(
      tester,
      repo,
      role: UserRole.parent,
      audioRepo: FakeParentAnswerRepository(),
      open: '질문 1',
    );

    await tester.tap(find.text('녹음 지우기'));
    await tester.pumpAndSettle();
    expect(find.text('이 녹음을 지울까요?'), findsOneWidget);
    expect(find.text(parentDeleteConfirmMessage), findsOneWidget);

    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();

    expect(repo.deletedRecordingIds, ['rec_1']);
    expect(repo.deletedAnswerIds, isEmpty); // 자녀 답은 건드리지 않음
    expect(find.text(deletedParentAnswerText), findsOneWidget);
    expect(find.text('자녀 답 1'), findsOneWidget);
    expect(find.text('녹음 지우기'), findsNothing); // 지운 뒤엔 버튼이 없음
    expect(find.text('녹음을 지웠어요.'), findsOneWidget);
  });

  testWidgets('부모: 취소하면 아무것도 지우지 않는다', (tester) async {
    final repo = oneStory(testStory('1', ttsStatus: 'NOT_REQUESTED'));
    await pumpPage(
      tester,
      repo,
      role: UserRole.parent,
      audioRepo: FakeParentAnswerRepository(),
      open: '질문 1',
    );

    await tester.tap(find.text('녹음 지우기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(repo.deletedRecordingIds, isEmpty);
    expect(find.text('정리된 부모님 답'), findsOneWidget);
    expect(find.text('녹음 지우기'), findsOneWidget);
  });

  testWidgets('자녀: 확인 후 내 답만 지우고 부모님 답은 남는다', (tester) async {
    final repo = oneStory(testStory('1'));
    await pumpPage(tester, repo, role: UserRole.child, open: '질문 1');

    expect(find.text('녹음 지우기'), findsNothing); // 부모 녹음은 지울 수 없음
    await tester.tap(find.text('내 답 지우기'));
    await tester.pumpAndSettle();
    expect(find.text(childDeleteConfirmMessage), findsOneWidget);

    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();

    expect(repo.deletedAnswerIds, ['ans_1']);
    expect(repo.deletedRecordingIds, isEmpty);
    expect(find.text(deletedChildAnswerText), findsOneWidget);
    expect(find.text('정리된 부모님 답'), findsOneWidget);
    expect(find.text('내 답 지우기'), findsNothing);
  });

  testWidgets('이미 지워진 내 답에는 지우기 버튼이 없다', (tester) async {
    await pumpPage(
      tester,
      oneStory(testStory('1', childDeleted: true)),
      role: UserRole.child,
      open: '질문 1',
    );

    expect(find.text('내 답 지우기'), findsNothing);
  });

  testWidgets('지우기에 실패하면 안내하고 답은 그대로 둔다', (tester) async {
    final repo = oneStory(testStory('1'))
      ..deleteError = ApiException(statusCode: 500);
    await pumpPage(tester, repo, role: UserRole.child, open: '질문 1');

    await tester.tap(find.text('내 답 지우기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();

    expect(find.text('잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('자녀 답 1'), findsOneWidget);
    expect(find.text('내 답 지우기'), findsOneWidget); // 다시 시도할 수 있음
  });

  testWidgets('다음 페이지를 기다리는 중에 지워도 지운 카드가 되살아나지 않는다', (tester) async {
    final repo = FakeStoriesRepository({
      null: StoryPage(items: [testStory('1')], nextCursor: 'c2', hasNext: true),
      'c2': StoryPage(
        items: [testStory('2')],
        nextCursor: null,
        hasNext: false,
      ),
    })..cursorGates['c2'] = Completer<void>();
    await pumpPage(tester, repo, role: UserRole.child);

    await tester.tap(find.text('이전 이야기 더 보기'));
    await tester.pump(); // 다음 페이지 응답 대기 중
    // 불러오는 표시가 계속 돌아 pumpAndSettle을 쓸 수 없다
    await tester.tap(find.text('질문 1'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('내 답 지우기'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('지우기'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(repo.deletedAnswerIds, ['ans_1']);

    repo.cursorGates['c2']!.complete();
    await tester.pumpAndSettle();

    // 상세에서 본 이야기는 지운 상태 그대로다
    expect(find.text('자녀 답 1'), findsNothing);
    expect(find.text('삭제된 답이에요.'), findsOneWidget);

    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();
    expect(find.text('질문 2'), findsOneWidget);
  });

  testWidgets('이미 지워진 기록이면(404) 안내하고 목록을 다시 불러온다', (tester) async {
    final repo = oneStory(testStory('1'))
      ..deleteError = ApiException(statusCode: 404);
    await pumpPage(tester, repo, role: UserRole.child, open: '질문 1');

    await tester.tap(find.text('내 답 지우기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();

    expect(find.text('이미 지워진 기록이에요.'), findsOneWidget);
    expect(repo.requestedCursors.length, 2); // 처음 + 다시 불러오기
  });

  testWidgets('부모: TTS 만드는 중이면 안내만 하고 API는 부르지 않는다', (tester) async {
    final audioRepo = FakeParentAnswerRepository();
    await pumpPage(
      tester,
      oneStory(testStory('1', ttsStatus: 'PROCESSING')),
      role: UserRole.parent,
      audioRepo: audioRepo,
      open: '질문 1',
    );

    expect(find.text('목소리를 담고 있어요'), findsOneWidget);
    expect(find.text('자녀 답 들어보기'), findsNothing);
    expect(audioRepo.audioCalls, 0);
  });

  testWidgets('부모: TTS 조회가 실패해도 자녀 글은 보인다', (tester) async {
    final audioRepo = FakeParentAnswerRepository()
      ..audioError = ApiException(statusCode: 403); // 재시도 안 하는 에러
    await pumpPage(
      tester,
      oneStory(testStory('1')),
      role: UserRole.parent,
      audioRepo: audioRepo,
      open: '질문 1',
    );

    expect(find.text('자녀 답 들어보기'), findsNothing);
    expect(find.text('자녀 답 1'), findsOneWidget);
  });
}
