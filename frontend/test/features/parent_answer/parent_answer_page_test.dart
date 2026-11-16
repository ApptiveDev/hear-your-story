import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/features/parent_answer/domain/parent_answer.dart';
import 'package:life_record/features/parent_answer/presentation/parent_answer_controller.dart';
import 'package:life_record/features/parent_answer/presentation/parent_answer_page.dart';

import 'fake_parent_answer_repository.dart';

void main() {
  testWidgets('TTS 실패 화면에서도 자녀 글을 읽을 수 있다', (tester) async {
    final repository = FakeParentAnswerRepository()
      ..audio = const AnswerAudio(status: AnswerTtsStatus.failed);
    final controller = ParentAnswerController(repository);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: ParentAnswerPage(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('자녀의 답변'), findsOneWidget);
    expect(find.textContaining('글로 답변을 볼 수 있어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('공개 전에는 글과 재생 버튼을 보여주지 않는다', (tester) async {
    final repository = FakeParentAnswerRepository()
      ..today = const ParentAnswer(
        questionText: '질문',
        revealStatus: 'WAITING_FOR_CHILD',
        canView: false,
      );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ParentAnswerPage(
            controller: ParentAnswerController(repository),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('도착하면 여기에 나타나요'), findsOneWidget);
    expect(find.text('자녀의 답변 듣기'), findsNothing);
    expect(repository.audioCalls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('내 이야기와 자녀의 이야기를 한 장에 함께 보여준다', (tester) async {
    final repository = FakeParentAnswerRepository()
      ..today = const ParentAnswer(
        questionText: '질문',
        revealStatus: 'REVEALED',
        canView: true,
        answerId: 'ans_1',
        text: '자녀의 답변',
        myText: '부모의 이야기',
      )
      ..audio = const AnswerAudio(status: AnswerTtsStatus.failed);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ParentAnswerPage(
            controller: ParentAnswerController(repository),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('내 이야기'), findsOneWidget);
    expect(find.text('부모의 이야기'), findsOneWidget);
    expect(find.text('자녀의 이야기'), findsOneWidget);
    expect(find.text('자녀의 답변'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
