import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/stories/data/stories_providers.dart';
import 'package:life_record/features/today/presentation/month_records.dart';

import '../../helpers/phone_size.dart';
import '../stories/fake_stories_repository.dart';

void main() {
  Future<void> pump(WidgetTester tester, FakeStoriesRepository repo) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storiesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [MonthRecords(now: () => DateTime(2026, 11, 20))],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('이번 달 이야기를 "N월 기록"으로 보여준다', (tester) async {
    await pump(
      tester,
      FakeStoriesRepository(
        {},
        months: {
          '2026-11': [
            testStory('1', assignedDate: DateTime(2026, 11, 2)),
            testStory('2', assignedDate: DateTime(2026, 11, 18)),
          ],
        },
      ),
    );

    expect(find.text('11월 기록'), findsOneWidget);
    expect(find.text('질문 1'), findsOneWidget);
    expect(find.text('질문 2'), findsOneWidget);
    // 최신 이야기가 위에 온다.
    expect(
      tester.getTopLeft(find.text('질문 2')).dy,
      lessThan(tester.getTopLeft(find.text('질문 1')).dy),
    );
  });

  testWidgets('이야기가 없으면 아무것도 그리지 않는다', (tester) async {
    await pump(tester, FakeStoriesRepository({}, months: {'2026-11': []}));

    expect(find.text('11월 기록'), findsNothing);
  });

  testWidgets('불러오지 못해도 홈을 막지 않고 숨긴다', (tester) async {
    // 에러는 재시도 후에도 숨긴다.
    final repo = FakeStoriesRepository({})
      ..error = ApiException(statusCode: 500);
    await pump(tester, repo);

    expect(find.text('11월 기록'), findsNothing);
  });
}
