import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/widgets/audio_playback_card.dart';
import 'package:life_record/core/theme/app_theme.dart';
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
    expect(find.text('눌러서 녹음을 시작해요'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('녹음 시작'));
    await tester.tap(find.byTooltip('녹음 시작'));
    await tester.pumpAndSettle();
    expect(find.textContaining('마이크 권한이 필요해요'), findsOneWidget);
    expect(find.byTooltip('녹음 시작'), findsOneWidget); // 다시 누를 수 있다
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
    expect(find.text('녹음하고 있어요'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.byTooltip('녹음 끝내기'), findsOneWidget);
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
    expect(find.text('녹음 끝내기'), findsOneWidget);
    expect(recorder.pauses, 1);

    await tester.ensureVisible(find.text('이어서 말하기'));
    await tester.pump();
    await tester.tap(find.text('이어서 말하기'));
    await tester.pump();
    expect(find.text('녹음하고 있어요'), findsOneWidget);
    expect(recorder.resumes, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('글씨를 키워도 말하는 동안 멈춤 버튼이 화면 안에 있다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1080 / 411;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const withAudio = RecordingArgs(
      assignmentId: 'asg_1',
      questionText: '어릴 때 가장 좋아했던 놀이는 무엇이었나요?',
      questionAudioUrl: 'https://signed.example.com/question.mp3',
    );
    final controller = RecordingController(
      args: withAudio,
      repository: FakeRecordingRepository(),
      recorder: FakeRecorder(),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: RecordingPage(args: withAudio, controller: controller),
        ),
      ),
    );
    expect(find.byType(AudioPlaybackCard), findsOneWidget);

    await controller.start();
    await tester.pump();
    expect(find.byType(AudioPlaybackCard), findsNothing);
    final height =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getRect(find.text('잠깐 멈추기')).bottom, lessThan(height));

    await controller.pause();
    await tester.pump();
    expect(find.byType(AudioPlaybackCard), findsNothing);
    expect(tester.getRect(find.text('처음부터 다시 말하기')).bottom, lessThan(height));

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
    expect(find.text('녹음하고 있어요'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(recorder.starts, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  test('녹음 시간을 분:초로 보여준다', () {
    expect(formatClock(0), '00:00');
    expect(formatClock(23), '00:23');
    expect(formatClock(60), '01:00');
  });

  for (final paused in [false, true]) {
    testWidgets('미리 듣기 후 명시적 전송만 업로드한다 (paused=$paused)', (tester) async {
      final recorder = FakeRecorder();
      final repository = FakeRecordingRepository()
        ..uploadGate = Completer<void>();
      final controller = RecordingController(
        args: args,
        repository: repository,
        recorder: recorder,
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: RecordingPage(args: args, controller: controller),
          ),
        ),
      );
      await controller.start();
      if (paused) await controller.pause();
      await tester.pump();
      final stop = paused ? find.text('녹음 끝내기') : find.byTooltip('녹음 끝내기');
      await tester.ensureVisible(stop);
      await tester.tap(stop);
      await tester.pumpAndSettle();
      expect(controller.phase, RecordingPhase.draft);
      expect(repository.keys, isEmpty);
      final player = tester.widget<AudioPlaybackCard>(
        find.byType(AudioPlaybackCard),
      );
      expect(player.source.url, Uri.file(recorder.clip.path).toString());
      expect(player.enabled, isTrue);
      expect(find.text('녹음 들어보기'), findsOneWidget);
      // 듣기는 선택이다. 재생하지 않고 보내기를 두 번 눌러도 한 번만 전송한다.
      await tester.ensureVisible(find.text('보내기'));
      await tester.tap(find.text('보내기'));
      await tester.tap(find.text('보내기'));
      await tester.pump();
      expect(repository.keys, hasLength(1));
      expect(controller.phase, RecordingPhase.uploading);
      repository.uploadGate!.complete();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

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

    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();
    expect(find.text('녹음을 그만둘까요?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  group('보낸 녹음이 있을 때(홈의 다시 녹음하기)', () {
    const sentArgs = RecordingArgs(
      assignmentId: 'asg_1',
      questionText: '좋아했던 놀이는 무엇인가요?',
      recordingId: 'rec_1',
    );

    Future<RecordingController> pumpSent(
      WidgetTester tester, {
      FakeRecorder? recorder,
      FakeRecordingRepository? repository,
    }) async {
      final controller = RecordingController(
        args: sentArgs,
        repository: repository ?? FakeRecordingRepository(),
        recorder: recorder ?? FakeRecorder(),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RecordingPage(args: sentArgs, controller: controller),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return controller;
    }

    testWidgets('정리가 끝난 화면에서 다시 녹음할 수 있다', (tester) async {
      await pumpSent(tester);
      expect(find.text('이야기가 저장됐어요'), findsOneWidget);

      await tester.tap(find.text('다시 녹음하기'));
      await tester.pump();
      await tester.pump();
      expect(find.text('녹음하고 있어요'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('다시 녹음하다 마이크 권한이 없으면 권한 안내를 녹음 화면에서 보여준다', (tester) async {
      await pumpSent(tester, recorder: FakeRecorder()..permission = false);

      await tester.tap(find.text('다시 녹음하기'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('마이크 권한이 필요해요'), findsOneWidget);
      expect(find.text('정리 상태를 확인하지 못했어요'), findsNothing);
      expect(find.byTooltip('녹음 시작'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('처리 상태를 확인하지 못하면 다시 확인하게 한다', (tester) async {
      await pumpSent(
        tester,
        repository: FakeRecordingRepository()..pollError = Exception('offline'),
      );

      expect(find.text('정리 상태를 확인하지 못했어요'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
