import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_record/features/child_answer/data/child_answer_providers.dart';
import 'package:life_record/features/child_answer/presentation/child_answer_args.dart';
import 'package:life_record/features/child_answer/presentation/child_answer_page.dart';
import 'package:life_record/features/today/data/today_providers.dart';
import 'package:life_record/features/today/presentation/today_page.dart';

import '../child_answer/fake_child_answer_repository.dart';
import 'today_fixtures.dart';

void main() {
  // 실제 흐름에서 찾은 버그: 제출 후 "홈으로"(go)를 누르면 홈이 재사용되어
  // 이전 상태("답하기")가 그대로 보였다.
  testWidgets('답을 제출하고 홈으로 돌아오면 홈이 제출 상태로 바뀐다', (tester) async {
    final today = FakeTodayDataSource(json: todayFixture('waiting_for_both'));
    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(path: '/today', builder: (_, _) => const TodayPage()),
        GoRoute(
          path: '/child-answer',
          builder: (_, state) =>
              ChildAnswerPage(args: state.extra! as ChildAnswerArgs),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayDataSourceProvider.overrideWithValue(today),
          childAnswerRepositoryProvider.overrideWithValue(
            FakeChildAnswerRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('글로 답하기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '저는 놀이터에서 숨바꼭질하던 시간이 기억나요.');
    await tester.pump();
    // 서버는 제출 응답을 줄 때 이미 저장을 마친 상태다
    today.json = todayFixture('waiting_for_parent');
    await tester.tap(find.text('답변 보내기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('홈으로'));
    await tester.pumpAndSettle();

    expect(find.text('글로 답하기'), findsNothing);
    expect(find.text('답 고치기'), findsOneWidget);
  });
}
