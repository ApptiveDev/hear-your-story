import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/today/data/today_providers.dart';
import 'package:life_record/features/today/domain/today.dart';
import 'package:life_record/features/today/presentation/today_page.dart';

import 'today_fixtures.dart';

const _interval = TodayPage.waitingPollInterval;

Future<void> _pump(WidgetTester tester, FakeTodayDataSource source) async {
  final router = GoRouter(
    initialLocation: '/today',
    routes: [
      GoRoute(path: '/today', builder: (_, _) => const TodayPage()),
      GoRoute(
        path: '/child-answer',
        builder: (_, _) => const Scaffold(body: Text('자녀 답변 화면')),
      ),
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
}

Map<String, dynamic> _parentWaiting(String processingStatus) =>
    todayFixture('waiting_for_child')
      ..['myAnswer']['processingStatus'] = processingStatus;

void main() {
  group('상대를 기다리는 동안', () {
    testWidgets('상대가 답하면 당기지 않아도 공개 화면으로 바뀐다', (tester) async {
      final source = FakeTodayDataSource(
        json: todayFixture('waiting_for_parent'),
      );
      await _pump(tester, source);
      expect(find.textContaining('부모님이 답하시면'), findsOneWidget);

      source.json = todayFixture('revealed');
      await tester.pump(_interval);
      await tester.pumpAndSettle();

      expect(find.text('부모님의 답'), findsOneWidget);
    });

    testWidgets('바뀐 게 없으면 화면을 다시 불러오지 않는다', (tester) async {
      final source = FakeTodayDataSource(
        json: todayFixture('waiting_for_parent'),
      );
      await _pump(tester, source);
      expect(source.calls, 1);

      await tester.pump(_interval);
      await tester.pumpAndSettle();

      expect(source.calls, 2); // 확인 1번만, 다시 불러오기 없음
    });

    testWidgets('확인 중 네트워크 오류가 나도 지금 화면을 유지한다', (tester) async {
      final source = FakeTodayDataSource(
        json: todayFixture('waiting_for_parent'),
      );
      await _pump(tester, source);

      source.error = ApiException(statusCode: 0, errorCode: 'NETWORK_ERROR');
      await tester.pump(_interval);
      await tester.pumpAndSettle();

      expect(find.textContaining('부모님이 답하시면'), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);
    });

    testWidgets('확인 중 페어링이 없어졌으면 페어링 화면으로 보낸다', (tester) async {
      final source = FakeTodayDataSource(
        json: todayFixture('waiting_for_parent'),
      );
      await _pump(tester, source);

      source.error = ApiException(statusCode: 409, errorCode: 'PAIR_NOT_FOUND');
      await tester.pump(_interval);
      await tester.pumpAndSettle();

      expect(find.text('페어링 화면'), findsOneWidget);
    });

    testWidgets('답하기 화면에 가 있는 동안은 확인하지 않는다', (tester) async {
      final source = FakeTodayDataSource(
        json: todayFixture('waiting_for_parent'),
      );
      await _pump(tester, source);

      await tester.ensureVisible(find.text('답 고치기'));
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();
      await tester.tap(find.text('답 고치기'));
      await tester.pumpAndSettle();
      await tester.pump(_interval * 3);

      expect(source.calls, 1);
    });
  });

  group('공개된 뒤에도 부모 음성을 정리하는 중이면', () {
    Map<String, dynamic> revealedWhileProcessing() {
      final json = todayFixture('revealed');
      (json['partnerAnswer'] as Map<String, dynamic>)
        ..['processingStatus'] = 'LLM_PROCESSING'
        ..['sttText'] = null
        ..['summaryText'] = null
        ..['processingNotice'] = null;
      return json;
    }

    testWidgets('자녀 화면이 정리 결과까지 기다렸다가 보여준다', (tester) async {
      final source = FakeTodayDataSource(json: revealedWhileProcessing());
      await _pump(tester, source);
      expect(find.text('부모님이 목소리로 답하셨어요.'), findsOneWidget);

      source.json = todayFixture('revealed'); // 정리 완료(READY)
      await tester.pump(_interval);
      await tester.pumpAndSettle();

      final summary =
          (todayFixture('revealed')['partnerAnswer'] as Map)['summaryText'];
      expect(find.text(summary as String), findsOneWidget);
    });

    testWidgets('정리가 끝나면 더 확인하지 않는다', (tester) async {
      final source = FakeTodayDataSource(json: todayFixture('revealed'));
      await _pump(tester, source);

      await tester.pump(_interval * 3);

      expect(source.calls, 1);
    });
  });

  testWidgets('아직 내가 답하지 않았으면 주기적으로 확인하지 않는다', (tester) async {
    final source = FakeTodayDataSource(json: todayFixture('waiting_for_both'));
    await _pump(tester, source);

    await tester.pump(_interval * 3);

    expect(source.calls, 1);
  });

  testWidgets('앱으로 돌아오면 새 질문이 있는지 확인한다', (tester) async {
    final source = FakeTodayDataSource(json: todayFixture('revealed'));
    await _pump(tester, source);

    // 다음 날 새 질문이 배정됨
    source.json = todayFixture('waiting_for_both')
      ..['assignment']['id'] = 'asg_next_day';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('답하기'), findsOneWidget);
  });

  group('부모 녹음 처리 안내', () {
    testWidgets('글 정리 중이면 정리하고 있다고 알린다', (tester) async {
      await _pump(
        tester,
        FakeTodayDataSource(json: _parentWaiting('LLM_PROCESSING')),
      );

      expect(find.text('말씀하신 내용을\n글로 정리하고 있어요.'), findsOneWidget);
    });

    testWidgets('정리에 실패해도 목소리는 전해진다고 알린다', (tester) async {
      await _pump(tester, FakeTodayDataSource(json: _parentWaiting('FAILED')));

      expect(find.textContaining('목소리는 그대로 전해져요.'), findsOneWidget);
      expect(find.text('말씀하신 내용을\n글로 정리하고 있어요.'), findsNothing);
    });

    testWidgets('정리가 끝나면 따로 안내하지 않는다', (tester) async {
      await _pump(tester, FakeTodayDataSource(json: _parentWaiting('READY')));

      expect(find.text('말씀하신 내용을\n글로 정리하고 있어요.'), findsNothing);
      expect(find.textContaining('목소리는 그대로 전해져요.'), findsNothing);
    });
  });

  group('hasTodayChanged', () {
    Today parse(Map<String, dynamic> json) => Today.fromJson(json);

    test('음성 링크만 바뀌면 바뀌지 않은 것으로 본다', () {
      final before = parse(todayFixture('revealed'));
      final json = todayFixture('revealed');
      json['partnerAnswer']['originalAudioUrl'] = 'https://example.com/new';
      expect(hasTodayChanged(before, parse(json)), isFalse);
    });

    test('상대 음성의 처리 상태가 바뀌면 바뀐 것으로 본다', () {
      final processing = todayFixture('revealed');
      processing['partnerAnswer']['processingStatus'] = 'LLM_PROCESSING';
      expect(
        hasTodayChanged(parse(processing), parse(todayFixture('revealed'))),
        isTrue,
      );
    });

    test('공개 상태·질문·처리 상태가 바뀌면 바뀐 것으로 본다', () {
      final waiting = parse(_parentWaiting('LLM_PROCESSING'));
      expect(hasTodayChanged(waiting, parse(_parentWaiting('READY'))), isTrue);
      expect(
        hasTodayChanged(
          parse(todayFixture('waiting_for_parent')),
          parse(todayFixture('revealed')),
        ),
        isTrue,
      );
      expect(
        hasTodayChanged(
          parse(todayFixture('revealed')),
          parse(todayFixture('revealed')..['assignment']['id'] = 'asg_next'),
        ),
        isTrue,
      );
    });
  });
}
