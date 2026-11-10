import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/recording/domain/recording.dart';
import 'package:life_record/features/recording/presentation/recording_args.dart';
import 'package:life_record/features/recording/presentation/recording_controller.dart';

import 'fakes.dart';

void main() {
  late FakeRecorder recorder;
  late FakeRecordingRepository repository;
  late RecordingController controller;
  late DateTime now;
  var serial = 0;

  setUp(() {
    recorder = FakeRecorder();
    repository = FakeRecordingRepository();
    now = DateTime(2026, 9, 25);
    controller = RecordingController(
      args: const RecordingArgs(assignmentId: 'asg_1', questionText: '질문'),
      repository: repository,
      recorder: recorder,
      now: () => now,
      createKey: () => 'key_${serial++}',
    );
  });
  tearDown(() => controller.dispose());

  testWidgets('권한 거부 시 녹음을 시작하지 않는다', (tester) async {
    recorder.permission = false;
    await controller.start();
    expect(recorder.starts, 0);
    expect(controller.phase, RecordingPhase.error);
    expect(controller.message, contains('마이크 권한'));
  });

  testWidgets('1초 미만 파일은 업로드하지 않는다', (tester) async {
    recorder.clip = const RecordedClip(
      path: '/tiny.m4a',
      duration: Duration(milliseconds: 500),
      bytes: 10,
    );
    await controller.start();
    await controller.stop();
    expect(repository.keys, isEmpty);
    expect(controller.hasDraft, isFalse);
  });

  testWidgets('업로드 재시도는 같은 키, 재녹음은 새 키를 쓴다', (tester) async {
    repository.uploadError = ApiException();
    await controller.start();
    await controller.stop();
    final first = repository.keys.single;
    expect(controller.hasDraft, isTrue);
    await controller.retryUpload();
    expect(repository.keys, [first, first]);
    await controller.start();
    repository.uploadError = null;
    await controller.stop();
    await tester.pump();
    expect(repository.keys.last, isNot(first));
    expect(controller.phase, RecordingPhase.ready);
  });

  testWidgets('업로드 중 중복 정지·재시도를 무시한다', (tester) async {
    repository.uploadGate = Completer<void>();
    await controller.start();
    final stopping = controller.stop();
    await tester.pump();
    await controller.stop();
    await controller.retryUpload();
    expect(repository.keys.length, 1);
    repository.uploadGate!.complete();
    await stopping;
  });

  testWidgets('60초가 되면 자동 정지하고 보낸다', (tester) async {
    await controller.start();
    now = now.add(const Duration(seconds: 60));
    await tester.pump(const Duration(milliseconds: 100));
    expect(recorder.stops, 1);
    expect(repository.keys.length, 1);
  });

  testWidgets('백그라운드에서 녹음을 멈추고 파일을 보관한다', (tester) async {
    await controller.start();
    controller.setForeground(false);
    await tester.pump();
    expect(recorder.stops, 1);
    expect(repository.keys, isEmpty);
    expect(controller.phase, RecordingPhase.draft);
    controller.setForeground(true);
    await controller.retryUpload();
    expect(repository.keys.length, 1);
  });

  testWidgets('마이크가 다른 앱에 중단되어도 자동 전송하지 않는다', (tester) async {
    await controller.start();
    recorder.interruptionController.add(null);
    // 스트림 구독이 FakeAsync 밖(setUp)에서 만들어져 실제 이벤트 루프를 한 번 돌린다
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(controller.phase, RecordingPhase.draft);
    expect(repository.keys, isEmpty);
  });

  testWidgets('AI 실패는 제출 성공과 녹음 ID를 유지한다', (tester) async {
    repository.status = ProcessingStatus.failed;
    await controller.start();
    await controller.stop();
    await tester.pump();
    expect(controller.phase, RecordingPhase.processingFailed);
    expect(controller.recordingId, 'rec_1');
    expect(controller.hasDraft, isFalse);
  });

  testWidgets('폴링은 3초에서 5초로 바뀌고 총 60초에 끝난다', (tester) async {
    repository.status = ProcessingStatus.llmProcessing;
    await controller.start();
    await controller.stop();
    await tester.pump();
    expect(repository.polls, 1);
    for (var i = 0; i < 10; i++) {
      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
    }
    expect(repository.polls, 11);
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(repository.polls, 11);
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(repository.polls, 12);
    now = now.add(const Duration(seconds: 25));
    await tester.pump(const Duration(seconds: 25));
    expect(controller.phase, RecordingPhase.delayed);
    final count = repository.polls;
    await tester.pump(const Duration(seconds: 30));
    expect(repository.polls, count);
  });

  testWidgets('백그라운드 응답은 버리고 복귀하면 다시 조회한다', (tester) async {
    repository.pollGate = Completer<RecordingResult>();
    await controller.start();
    await controller.stop();
    controller.setForeground(false);
    repository.pollGate!.complete(
      const RecordingResult(
        recordingId: 'rec_1',
        assignmentId: 'asg_1',
        status: ProcessingStatus.failed,
      ),
    );
    await tester.pump();
    expect(controller.result, isNull);
    repository.pollGate = null;
    controller.setForeground(true);
    await tester.pump();
    expect(controller.phase, RecordingPhase.ready);
  });

  testWidgets('ANSWER_LOCKED 이후 재녹음과 재전송을 막는다', (tester) async {
    repository.uploadError = ApiException(
      statusCode: 409,
      errorCode: 'ANSWER_LOCKED',
    );
    await controller.start();
    await controller.stop();
    expect(controller.locked, isTrue);
    expect(controller.canStart, isFalse);
    expect(controller.canRetryUpload, isFalse);
  });

  group('일시정지', () {
    testWidgets('멈춘 시간은 빼고, 실제 녹음 시간 합계가 60초면 끝나서 파일 하나를 보낸다', (tester) async {
      await tester.runAsync(() async {
        await controller.start();
        now = now.add(const Duration(seconds: 20));
        await controller.pause();
        expect(controller.phase, RecordingPhase.paused);
        expect(controller.elapsedSeconds, 20);

        now = now.add(const Duration(minutes: 5)); // 멈춘 동안은 세지 않는다
        await controller.resume();
        expect(controller.phase, RecordingPhase.recording);
        now = now.add(const Duration(seconds: 15));
        await controller.pause();
        expect(controller.elapsedSeconds, 35);

        await controller.resume();
        now = now.add(const Duration(seconds: 24));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(controller.elapsedSeconds, 59);
        expect(repository.keys, isEmpty);

        now = now.add(const Duration(seconds: 1));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });

      expect(recorder.pauses, 2);
      expect(recorder.resumes, 2);
      expect(recorder.starts, 1);
      expect(recorder.stops, 1);
      expect(repository.keys, hasLength(1));
    });

    testWidgets('멈춘 상태에서 보내면 바로 업로드한다', (tester) async {
      await controller.start();
      await controller.pause();
      await controller.stop();
      expect(recorder.stops, 1);
      expect(repository.keys, hasLength(1));
    });

    testWidgets('멈춘 상태에서는 전화 같은 방해 알림으로 녹음이 끝나지 않는다', (tester) async {
      await controller.start();
      await controller.pause();
      recorder.interruptionController.add(null);
      await tester.pump();
      expect(controller.phase, RecordingPhase.paused);
      expect(recorder.stops, 0);
    });

    testWidgets('멈춘 상태로 앱을 내리면 파일로 남기고 보내지 않는다', (tester) async {
      await controller.start();
      await controller.pause();
      controller.setForeground(false);
      await tester.pump();
      expect(recorder.stops, 1);
      expect(controller.hasDraft, isTrue);
      expect(repository.keys, isEmpty);
    });

    testWidgets('앱이 내려가 있으면 이어서 녹음하지 않는다', (tester) async {
      await controller.start();
      await controller.pause();
      controller.setForeground(false);
      await tester.pump();
      await controller.resume();
      expect(recorder.resumes, 0);
    });

    testWidgets('멈추기에 실패하면 지금까지의 녹음을 파일로 남긴다', (tester) async {
      recorder.pauseError = Exception('pause 실패');
      await controller.start();
      await controller.pause();
      expect(recorder.stops, 1);
      expect(controller.hasDraft, isTrue);
      expect(controller.phase, RecordingPhase.draft);
    });

    testWidgets('이어서 녹음에 실패하면 지금까지의 녹음을 파일로 남긴다', (tester) async {
      recorder.resumeError = Exception('resume 실패');
      await controller.start();
      await controller.pause();
      await controller.resume();
      expect(recorder.stops, 1);
      expect(controller.hasDraft, isTrue);
    });

    testWidgets('이어서 녹음을 기다리는 사이 끝내면 시간을 다시 재지 않는다', (tester) async {
      recorder.resumeGate = Completer();
      await controller.start();
      await controller.pause();
      final resuming = controller.resume();
      await controller.stop();
      recorder.resumeGate!.complete();
      await resuming;
      now = now.add(const Duration(seconds: 70));
      await tester.pump(const Duration(milliseconds: 200));
      expect(recorder.stops, 1);
      expect(repository.keys, hasLength(1));
    });

    testWidgets('이어서 녹음을 기다리는 사이 끝낸 뒤 실패해도 보낸 녹음을 그대로 둔다', (tester) async {
      recorder.resumeGate = Completer();
      recorder.resumeError = Exception('resume 실패');
      await controller.start();
      await controller.pause();
      final resuming = controller.resume();
      await controller.stop();
      recorder.resumeGate!.complete();
      await resuming;
      expect(recorder.stops, 1);
      expect(controller.phase, RecordingPhase.ready);
      expect(controller.message, isNot(contains('저장하지 못했어요')));
    });

    testWidgets('멈추기를 기다리는 사이 끝낸 뒤 실패해도 보낸 녹음을 그대로 둔다', (tester) async {
      recorder.pauseGate = Completer();
      recorder.pauseError = Exception('pause 실패');
      await controller.start();
      final pausing = controller.pause();
      await controller.stop();
      recorder.pauseGate!.complete();
      await pausing;
      expect(recorder.stops, 1);
      expect(controller.phase, RecordingPhase.ready);
    });

    testWidgets('기다리던 이어가기가 실패해도 새로 시작한 녹음은 끊지 않는다', (tester) async {
      recorder.resumeGate = Completer();
      recorder.resumeError = Exception('resume 실패');
      await controller.start();
      await controller.pause();
      final resuming = controller.resume();
      controller.setForeground(false);
      await tester.pump();
      controller.setForeground(true);
      await controller.start();
      expect(controller.phase, RecordingPhase.recording);
      recorder.resumeGate!.complete();
      await resuming;
      expect(recorder.stops, 1);
      expect(controller.phase, RecordingPhase.recording);
      await controller.stop();
    });

    testWidgets('이어가기를 기다리는 사이 다시 멈췄다 이어가도 시간은 한 번만 잰다', (tester) async {
      await controller.start();
      await controller.pause();
      recorder.resumeGate = Completer();
      final first = controller.resume();
      await controller.pause();
      final second = controller.resume();
      recorder.resumeGate!.complete();
      await first;
      await second;
      await controller.pause();
      final paused = controller.elapsedSeconds;

      now = now.add(const Duration(seconds: 70));
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.phase, RecordingPhase.paused);
      expect(controller.elapsedSeconds, paused);
      expect(recorder.stops, 0);
    });

    testWidgets('처음부터 다시 말하면 시간을 0부터 재고 이전 녹음은 보내지 않는다', (tester) async {
      await controller.start();
      now = now.add(const Duration(seconds: 30));
      await controller.pause();
      expect(controller.elapsedSeconds, 30);

      await controller.restart();
      expect(controller.phase, RecordingPhase.recording);
      expect(controller.elapsedSeconds, 0);
      expect(recorder.starts, 2);
      expect(recorder.stops, 0);
      expect(repository.keys, isEmpty);

      // 앞의 30초는 합계에 들어가지 않는다
      now = now.add(const Duration(seconds: 40));
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.elapsedSeconds, 40);
      expect(repository.keys, isEmpty);
      await controller.stop();
    });

    testWidgets('녹음 중이거나 앱이 내려가 있으면 처음부터 다시 시작하지 않는다', (tester) async {
      await controller.start();
      await controller.restart();
      expect(recorder.starts, 1);

      await controller.pause();
      controller.setForeground(false);
      await tester.pump();
      await controller.restart();
      expect(recorder.starts, 1);
    });

    testWidgets('두 번 눌러도 한 번만 멈추고 이어진다', (tester) async {
      await controller.start();
      await Future.wait([controller.pause(), controller.pause()]);
      expect(recorder.pauses, 1);
      await Future.wait([controller.resume(), controller.resume()]);
      expect(recorder.resumes, 1);
      await controller.stop(); // 녹음 타이머 정리
    });
  });

  test('파일 크기와 길이 경계를 검사한다', () {
    expect(
      const RecordedClip(
        path: '/a',
        duration: Duration(seconds: 60),
        bytes: 10 * 1024 * 1024,
      ).validationMessage,
      isNull,
    );
    expect(
      const RecordedClip(
        path: '/a',
        duration: Duration(seconds: 61),
        bytes: 1,
      ).validationMessage,
      isNotNull,
    );
    expect(
      const RecordedClip(
        path: '/a',
        duration: Duration(seconds: 1),
        bytes: 10 * 1024 * 1024 + 1,
      ).validationMessage,
      isNotNull,
    );
  });
}
