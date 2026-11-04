import 'dart:async';

import 'package:life_record/features/recording/domain/recording.dart';
import 'package:life_record/features/recording/domain/recording_repository.dart';

class FakeRecorder implements RecorderService {
  bool permission = true;
  int starts = 0;
  int pauses = 0;
  int resumes = 0;
  int stops = 0;
  int disposals = 0;
  Object? pauseError;
  Object? resumeError;
  Completer<void>? resumeGate;
  Completer<void>? startGate;
  final interruptionController = StreamController<void>.broadcast();
  RecordedClip clip = const RecordedClip(
    path: '/test.m4a',
    duration: Duration(seconds: 5),
    bytes: 2048,
  );

  @override
  Stream<void> get interruptions => interruptionController.stream;
  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<void> start() async {
    starts++;
    await startGate?.future;
  }

  @override
  Future<void> pause() async {
    pauses++;
    if (pauseError != null) throw pauseError!;
  }

  @override
  Future<void> resume() async {
    resumes++;
    await resumeGate?.future;
    if (resumeError != null) throw resumeError!;
  }

  @override
  Future<RecordedClip> stop() async {
    stops++;
    return clip;
  }

  @override
  Future<void> discard() async {}
  @override
  Future<void> dispose() async {
    disposals++;
    await interruptionController.close();
  }
}

class FakeRecordingRepository implements RecordingRepository {
  final keys = <String>[];
  int polls = 0;
  Object? uploadError;
  Object? pollError;
  Completer<void>? uploadGate;
  Completer<RecordingResult>? pollGate;
  ProcessingStatus status = ProcessingStatus.ready;

  @override
  Future<RecordingSubmission> upload({
    required String assignmentId,
    required RecordedClip clip,
    required String idempotencyKey,
    required void Function(double progress) onProgress,
  }) async {
    keys.add(idempotencyKey);
    await uploadGate?.future;
    if (uploadError != null) throw uploadError!;
    onProgress(1);
    return RecordingSubmission(
      recordingId: 'rec_1',
      assignmentId: assignmentId,
    );
  }

  @override
  Future<RecordingResult> getStatus(String recordingId) async {
    polls++;
    if (pollError != null) throw pollError!;
    if (pollGate != null) return pollGate!.future;
    return RecordingResult(
      recordingId: recordingId,
      assignmentId: 'asg_1',
      status: status,
    );
  }
}
