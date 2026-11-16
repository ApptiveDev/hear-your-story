import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_record/core/widgets/app_tab_shell.dart';

Future<void> _pump(WidgetTester tester, {required bool calendar}) async {
  final tabs = appTabs(calendar: calendar);
  Widget page(String label) => Scaffold(body: Center(child: Text(label)));
  final router = GoRouter(
    initialLocation: '/today',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppTabShell(location: state.uri.path, tabs: tabs, child: child),
        routes: [
          GoRoute(path: '/today', builder: (_, _) => page('홈 화면')),
          GoRoute(
            path: '/stories',
            builder: (_, _) => page('책장 화면'),
            routes: [
              GoRoute(path: 'calendar', builder: (_, _) => page('달력 화면')),
            ],
          ),
          GoRoute(path: '/my', builder: (_, _) => page('마이 화면')),
        ],
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('탭을 누르면 그 화면으로 가고 탭 막대는 그대로 남는다', (tester) async {
    await _pump(tester, calendar: true);
    expect(find.text('홈 화면'), findsOneWidget);

    for (final (label, screen) in [
      ('책장', '책장 화면'),
      ('달력', '달력 화면'),
      ('마이', '마이 화면'),
      ('홈', '홈 화면'),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(screen), findsOneWidget);
      expect(find.byType(AppTabBar), findsOneWidget);
    }
  });

  testWidgets('탭 막대는 아래에만 놓이고 위 화면이 나머지 높이를 쓴다', (tester) async {
    await _pump(tester, calendar: true);

    final screen = tester.getSize(find.byType(MaterialApp));
    final bar = tester.getSize(find.byType(AppTabBar));
    expect(bar.height, lessThan(screen.height / 3));
  });

  testWidgets('월별 조회를 끈 빌드에서는 달력 탭을 숨긴다', (tester) async {
    await _pump(tester, calendar: false);

    expect(find.text('달력'), findsNothing);
    expect(find.text('책장'), findsOneWidget);
  });

  test('주소에 맞는 탭을 고른다 (더 긴 주소 우선)', () {
    final tabs = appTabs(calendar: true);
    expect(tabIndexFor('/today', tabs), 0);
    expect(tabIndexFor('/stories', tabs), 1);
    expect(tabIndexFor('/stories/calendar', tabs), 2);
    expect(tabIndexFor('/my', tabs), 3);
  });
}
