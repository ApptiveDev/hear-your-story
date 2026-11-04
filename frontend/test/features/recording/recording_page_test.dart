import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/features/recording/presentation/recording_args.dart';
import 'package:life_record/features/recording/presentation/recording_controller.dart';
import 'package:life_record/features/recording/presentation/recording_page.dart';

import 'fakes.dart';

void main() {
  const args = RecordingArgs(
    assignmentId: 'asg_1',
    questionText: '좋아했던 놀이는 무엇인가요?',
  );

  testWidgets('권한 거부 안내와 재시도 버튼을 표시한다', (tester) async {
    final recorder = FakeRecorder()..permission = false;
    final controller = RecordingController(
      args: args,
      repository: FakeRecordingRepository(),
      recorder: recorder,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RecordingPage(args: args, controller: controller),
        ),
      ),
    );
    expect(find.text(args.questionText), findsOneWidget);
    await tester.ensureVisible(find.text('말하기 시작'));
    await tester.tap(find.text('말하기 시작'));
    await tester.pumpAndSettle();
    expect(find.textContaining('마이크 권한이 필요해요'), findsOneWidget);
    expect(find.text('말하기 시작'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('녹음 상태를 아이콘뿐 아니라 글자로도 알린다', (tester) async {
    final controller = RecordingController(
      args: args,
      repository: FakeRecordingRepository(),
      recorder: FakeRecorder(),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RecordingPage(args: args, controller: controller),
        ),
      ),
    );
    await controller.start();
    await tester.pump();
    expect(find.textContaining('녹음 중'), findsOneWidget);
    expect(find.text('그만 말하고 보내기'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('잠깐 멈추고 이어서 말할 수 있다', (tester) async {
    final recorder = FakeRecorder();
    final controller = RecordingController(
      args: args,
      repository: FakeRecordingRepository(),
      recorder: recorder,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RecordingPage(args: args, controller: controller),
        ),
      ),
    );
    await controller.start();
    await tester.pump();

    await tester.ensureVisible(find.text('잠깐 멈추기'));
    await tester.pump();
    await tester.tap(find.text('잠깐 멈추기'));
    await tester.pump();
    expect(find.textContaining('잠깐 멈췄어요'), findsOneWidget);
    expect(find.text('잠깐 멈추기'), findsNothing);
    expect(find.text('그만 말하고 보내기'), findsOneWidget);
    expect(recorder.pauses, 1);

    await tester.ensureVisible(find.text('이어서 말하기'));
    await tester.pump();
    await tester.tap(find.text('이어서 말하기'));
    await tester.pump();
    expect(find.textContaining('녹음 중'), findsOneWidget);
    expect(recorder.resumes, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('처음부터 다시 말하기는 한 번 더 묻고 나서 다시 시작한다', (tester) async {
    final recorder = FakeRecorder();
    final controller = RecordingController(
      args: args,
      repository: FakeRecordingRepository(),
      recorder: recorder,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RecordingPage(args: args, controller: controller),
        ),
      ),
    );
    await controller.start();
    await controller.pause();
    await tester.pump();

    Future<void> tapRestart() async {
      await tester.ensureVisible(find.text('처음부터 다시 말하기'));
      await tester.pump();
      await tester.tap(find.text('처음부터 다시 말하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tapRestart();
    expect(find.text('지금까지 말한 내용은 지워져요.'), findsOneWidget);
    await tester.tap(find.text('그대로 두기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.phase, RecordingPhase.paused);
    expect(recorder.starts, 1);

    await tapRestart();
    await tester.tap(find.text('다시 말하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('녹음 중 · 0초'), findsOneWidget);
    expect(recorder.starts, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('멈춘 상태에서 뒤로 가면 저장되지 않는다고 묻는다', (tester) async {
    final controller = RecordingController(
      args: args,
      repository: FakeRecordingRepository(),
      recorder: FakeRecorder(),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RecordingPage(args: args, controller: controller),
        ),
      ),
    );
    await controller.start();
    await controller.pause();
    await tester.pump();

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('녹음을 그만둘까요?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
