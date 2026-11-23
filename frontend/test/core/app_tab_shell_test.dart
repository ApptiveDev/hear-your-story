import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('홈이 아닌 탭에서 뒤로가기를 누르면 앱을 닫지 않고 홈으로 간다', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(tester, calendar: true);

    for (final tab in ['책장', '마이']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('홈 화면'), findsOneWidget);
      expect(calls, isNot(contains('SystemNavigator.pop')));
    }
  });

  testWidgets('탭 막대는 아래에만 놓이고 위 화면이 나머지 높이를 쓴다', (tester) async {
    await _pump(tester, calendar: true);

    final screen = tester.getSize(find.byType(MaterialApp));
    final bar = tester.getSize(find.byType(AppTabBar));
    expect(bar.height, lessThan(screen.height / 3));
  });

  testWidgets('막대 뒤로 화면이 비치고, 끝까지 내리면 막대에 가리지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppTabShell(
          location: '/today',
          child: Scaffold(
            body: SafeArea(
              bottom: false,
              child: Builder(
                builder: (context) => ListView(
                  padding: tabPagePadding(context),
                  children: const [SizedBox(height: 2000), Text('마지막')],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final bar = find.byType(AppTabBar);
    expect(
      find.descendant(of: bar, matching: find.byType(ColoredBox)),
      findsNothing,
    );
    expect(
      tester.getRect(find.byType(ListView)).bottom,
      tester.getRect(bar).bottom,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(bar).top - tester.getRect(find.text('마지막')).bottom,
      24,
    );
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
