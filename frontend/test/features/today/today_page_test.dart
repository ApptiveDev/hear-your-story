import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/child_answer/presentation/child_answer_args.dart';
import 'package:life_record/features/recording/presentation/recording_args.dart';
import 'package:life_record/features/today/data/today_providers.dart';
import 'package:life_record/features/today/presentation/today_page.dart';

import 'today_fixtures.dart';

class _Harness {
  ChildAnswerArgs? childAnswerArgs;
  RecordingArgs? recordingArgs;
}

Future<_Harness> _pump(WidgetTester tester, FakeTodayDataSource source) async {
  final harness = _Harness();
  Widget back(String label) => Builder(
    builder: (context) => Scaffold(
      body: Column(
        children: [
          Text(label),
          TextButton(onPressed: () => context.pop(), child: const Text('뒤로')),
        ],
      ),
    ),
  );
  final router = GoRouter(
    initialLocation: '/today',
    routes: [
      GoRoute(path: '/today', builder: (_, _) => const TodayPage()),
      GoRoute(
        path: '/child-answer',
        builder: (_, state) {
          harness.childAnswerArgs = state.extra as ChildAnswerArgs?;
          return back('자녀 답변 화면');
        },
      ),
      GoRoute(
        path: '/recording',
        builder: (_, state) {
          harness.recordingArgs = state.extra as RecordingArgs?;
          return back('녹음 화면');
        },
      ),
      GoRoute(path: '/parent-answer', builder: (_, _) => back('부모 답변 화면')),
      GoRoute(path: '/stories', builder: (_, _) => back('지난 이야기 화면')),
      GoRoute(path: '/pairing', builder: (_, _) => const Text('페어링 화면')),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [todayDataSourceProvider.overrideWithValue(source)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  // 홈 인사말이 저장된 사용자 이름을 읽는다
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('자녀', () {
    testWidgets('아직 답하지 않았으면 답하기로 자녀 답변 화면을 연다', (tester) async {
      final harness = await _pump(
        tester,
        FakeTodayDataSource(json: todayFixture('waiting_for_both')),
      );

      expect(find.text('어릴 때 가장 좋아했던 놀이는 무엇이었나요?'), findsOneWidget);
      await tester.tap(find.text('답하기'));
      await tester.pumpAndSettle();

      expect(find.text('자녀 답변 화면'), findsOneWidget);
      final args = harness.childAnswerArgs!;
      expect(args.assignmentId, 'asg_01J8M90G3M9BT7PRD6X4CN9C0E');
      expect(args.questionText, '어릴 때 가장 좋아했던 놀이는 무엇이었나요?');
      expect(args.isEditing, isFalse);
    });

    testWidgets('답을 보냈으면 내 답을 보여주고 수정 모드로 연다', (tester) async {
      final source = FakeTodayDataSource(
        json: todayFixture('waiting_for_parent'),
      );
      final harness = await _pump(tester, source);

      expect(find.text('저는 놀이터에서 숨바꼭질하던 시간이 기억나요.'), findsOneWidget);
      await tester.ensureVisible(find.text('답 고치기'));
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();
      await tester.tap(find.text('답 고치기'));
      await tester.pumpAndSettle();

      expect(harness.childAnswerArgs!.initialText, '저는 놀이터에서 숨바꼭질하던 시간이 기억나요.');

      // 돌아오면 홈을 다시 불러온다
      final callsBefore = source.calls;
      await tester.tap(find.text('뒤로'));
      await tester.pumpAndSettle();
      expect(source.calls, callsBefore + 1);
    });

    testWidgets('공개되면 부모님의 정리된 답과 내 답을 보여준다', (tester) async {
      await _pump(tester, FakeTodayDataSource(json: todayFixture('revealed')));

      expect(find.text('부모님의 답'), findsOneWidget);
      expect(find.text('어린 시절 동네 친구들과 고무줄 놀이를 즐겼어요.'), findsOneWidget);
      expect(find.text('내 답'), findsOneWidget);
      expect(find.text('답 고치기'), findsNothing); // 공개 후에는 수정 불가
    });
  });

  testWidgets('공개되고 원본 음성이 있으면 부모님 목소리 듣기 카드를 보여준다', (tester) async {
    await _pump(tester, FakeTodayDataSource(json: todayFixture('revealed')));

    expect(find.text('부모님 목소리 듣기'), findsOneWidget);
  });

  testWidgets('원본 음성 URL이 없으면 재생 카드를 보여주지 않는다', (tester) async {
    final json = todayFixture('revealed');
    (json['partnerAnswer'] as Map<String, dynamic>)['originalAudioUrl'] = null;
    await _pump(tester, FakeTodayDataSource(json: json));

    expect(find.text('부모님의 답'), findsOneWidget); // 답 카드는 그대로 보이고
    expect(find.text('부모님 목소리 듣기'), findsNothing);
  });

  group('부모님', () {
    testWidgets('아직 답하지 않았으면 목소리로 답하기로 녹음 화면을 연다', (tester) async {
      final json = todayFixture('waiting_for_both')..['viewerRole'] = 'PARENT';
      await _pump(tester, FakeTodayDataSource(json: json));

      final harness = await _pump(tester, FakeTodayDataSource(json: json));

      await tester.tap(find.text('목소리로 답하기'));
      await tester.pumpAndSettle();

      expect(find.text('녹음 화면'), findsOneWidget);
      final args = harness.recordingArgs!;
      expect(args.assignmentId, 'asg_01J8M90G3M9BT7PRD6X4CN9C0E');
      expect(args.questionText, '어릴 때 가장 좋아했던 놀이는 무엇이었나요?');
      expect(args.questionAudioUrl, isNull);
      expect(args.recordingId, isNull);
      expect(args.canRecord, isTrue);
    });

    testWidgets('보낸 뒤에는 정리 중임을 알리고 다시 녹음할 수 있다', (tester) async {
      final harness = await _pump(
        tester,
        FakeTodayDataSource(json: todayFixture('waiting_for_child')),
      );

      expect(find.textContaining('목소리를 보냈어요.'), findsOneWidget);
      expect(find.text('말씀하신 내용을\n글로 정리하고 있어요.'), findsOneWidget);

      await tester.tap(find.text('다시 녹음하기'));
      await tester.pumpAndSettle();

      // 기존 녹음의 처리 상태를 녹음 화면이 다시 조회한다
      expect(
        harness.recordingArgs!.recordingId,
        'rec_01J8M96KKXMV5XMXY6KGJ05Q6D',
      );
    });

    testWidgets('공개되면 자녀의 답을 보여주고 목소리로 들으러 갈 수 있다', (tester) async {
      await _pump(tester, FakeTodayDataSource(json: parentRevealedFixture()));

      expect(find.text('자녀의 답'), findsOneWidget);
      expect(find.text('저는 놀이터에서 숨바꼭질하던 시간이 기억나요.'), findsOneWidget);

      await tester.tap(find.text('목소리로 듣기'));
      await tester.pumpAndSettle();

      expect(find.text('부모 답변 화면'), findsOneWidget);
    });
  });

  testWidgets('페어링 전이면 페어링 화면으로 보낸다', (tester) async {
    await _pump(
      tester,
      FakeTodayDataSource(
        error: ApiException(statusCode: 409, errorCode: 'PAIR_NOT_FOUND'),
      ),
    );

    expect(find.text('페어링 화면'), findsOneWidget);
  });

  testWidgets('오늘 질문이 없으면 준비 중이라고 안내하고 다시 시도할 수 있다', (tester) async {
    final source = FakeTodayDataSource(
      error: ApiException(
        statusCode: 404,
        errorCode: 'TODAY_ASSIGNMENT_NOT_FOUND',
      ),
    );
    await _pump(tester, source);

    expect(find.textContaining('오늘 질문을 준비하고 있어요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(source.calls, 2);
  });

  testWidgets('저장된 이름으로 인사한다', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'current_user': '{"id":"usr_test","name":"김민지","role":"CHILD","pairingStatus":"PAIRED"}',
    });
    await _pump(
      tester,
      FakeTodayDataSource(json: todayFixture('waiting_for_both')),
    );

    expect(find.text('안녕하세요 김민지님'), findsOneWidget);
  });

  testWidgets('이름을 모르면 인사 없이 보여준다', (tester) async {
    await _pump(
      tester,
      FakeTodayDataSource(json: todayFixture('waiting_for_both')),
    );

    expect(find.textContaining('안녕하세요'), findsNothing);
    expect(find.text('답하기'), findsOneWidget);
  });

  testWidgets('지난 이야기로 갈 수 있다', (tester) async {
    await _pump(
      tester,
      FakeTodayDataSource(json: todayFixture('waiting_for_both')),
    );

    await tester.tap(find.text('지난 이야기 보기'));
    await tester.pumpAndSettle();

    expect(find.text('지난 이야기 화면'), findsOneWidget);
  });
}
