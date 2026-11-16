import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/child_answer/data/child_answer_providers.dart';
import 'package:life_record/features/child_answer/presentation/child_answer_args.dart';
import 'package:life_record/features/child_answer/presentation/child_answer_page.dart';

import 'fake_child_answer_repository.dart';

void main() {
  late FakeChildAnswerRepository repo;

  setUp(() => repo = FakeChildAnswerRepository());

  Future<void> pumpPage(
    WidgetTester tester, {
    ChildAnswerArgs args = ChildAnswerArgs.demo,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [childAnswerRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(home: ChildAnswerPage(args: args)),
      ),
    );
  }

  FilledButton button(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

  testWidgets('질문이 보이고 빈 칸이면 보내기 버튼이 비활성', (tester) async {
    await pumpPage(tester);

    expect(find.text(ChildAnswerArgs.demo.questionText), findsOneWidget);
    expect(button(tester, '보내기').onPressed, isNull);
  });

  testWidgets('글을 쓰고 보내면 완료 화면이 보인다', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), '숨바꼭질이요');
    await tester.pump();
    expect(button(tester, '보내기').onPressed, isNotNull);

    await tester.tap(find.text('보내기'));
    await tester.pumpAndSettle();

    expect(find.text('답변을 보냈어요'), findsOneWidget);
    expect(find.text('숨바꼭질이요'), findsOneWidget);
  });

  testWidgets('네트워크 오류여도 쓴 글이 남아 있다', (tester) async {
    repo.error = ApiException();
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), '지워지면 안 되는 글');
    await tester.pump();
    await tester.tap(find.text('보내기'));
    await tester.pumpAndSettle();

    expect(find.text('인터넷 연결을 확인해 주세요.'), findsOneWidget);
    expect(find.text('지워지면 안 되는 글'), findsOneWidget);
  });

  testWidgets('1000자를 넘기면 안내 문구와 버튼 비활성', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), '가' * 1001);
    await tester.pump();

    expect(find.text('1000자까지 적을 수 있어요.'), findsOneWidget);
    expect(button(tester, '보내기').onPressed, isNull);
  });

  testWidgets('수정 모드는 내용을 바꿔야 수정 완료가 활성', (tester) async {
    await pumpPage(
      tester,
      args: const ChildAnswerArgs(
        assignmentId: 'asg_1',
        questionText: '질문',
        initialText: '원래 답변',
      ),
    );

    expect(find.text('원래 답변'), findsOneWidget);
    expect(button(tester, '저장하기').onPressed, isNull);

    await tester.enterText(find.byType(TextField), '고친 답변');
    await tester.pump();
    expect(button(tester, '저장하기').onPressed, isNotNull);
  });

  testWidgets('쓴 글이 있으면 이전을 눌렀을 때 한 번 더 묻고 계속 쓸 수 있다', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byType(TextField), '아직 안 보낸 글');
    await tester.pump();

    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();
    expect(find.text('쓴 내용이 저장되지 않았어요'), findsOneWidget);

    await tester.tap(find.text('계속 쓰기'));
    await tester.pumpAndSettle();
    expect(find.text('쓴 내용이 저장되지 않았어요'), findsNothing);
    expect(find.text('아직 안 보낸 글'), findsOneWidget);
  });

  testWidgets('수정 화면에서 고친 뒤 취소하면 고친 내용 안내로 묻는다', (tester) async {
    await pumpPage(
      tester,
      args: const ChildAnswerArgs(
        assignmentId: 'asg_1',
        questionText: '질문',
        initialText: '원래 답변',
      ),
    );
    expect(find.text('답변을 고치고 있어요'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '고친 답변');
    await tester.pump();

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('고친 내용이 저장되지 않았어요'), findsOneWidget);
    expect(find.text('계속 고치기'), findsOneWidget);
  });
}
