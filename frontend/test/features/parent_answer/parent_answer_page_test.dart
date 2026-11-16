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

  testWidgets('음성 준비가 60초를 넘기면 다시 시도할 수 있다', (tester) async {
    final repository = FakeParentAnswerRepository()
      ..audio = const AnswerAudio(status: AnswerTtsStatus.processing);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ParentAnswerPage(
            controller: ParentAnswerController(repository),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('목소리를 담고 있어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);

    for (var i = 0; i < 13; i++) {
      await tester.pump(const Duration(seconds: 5));
    }
    expect(find.text('목소리를 담고 있어요'), findsNothing);
    expect(find.text('다시 시도'), findsOneWidget);

    final calls = repository.audioCalls;
    repository.audio = const AnswerAudio(
      status: AnswerTtsStatus.ready,
      url: 'https://example.test/audio.mp3',
    );
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    await tester.pump();
    expect(repository.audioCalls, calls + 1);
    expect(find.text('자녀의 답변 듣기'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('자녀 답을 기다리는 동안 다시 확인하면 도착한 답을 보여준다', (tester) async {
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

    repository.today = const ParentAnswer(
      questionText: '질문',
      revealStatus: 'REVEALED',
      canView: true,
      answerId: 'ans_1',
      text: '도착한 자녀의 답',
    );
    await tester.tap(find.text('다시 확인'));
    await tester.pumpAndSettle();

    expect(repository.todayCalls, 2);
    expect(find.text('도착한 자녀의 답'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
