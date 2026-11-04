import 'recording.dart';

abstract class RecordingRepository {
  Future<RecordingSubmission> upload({
    required String assignmentId,
    required RecordedClip clip,
    required String idempotencyKey,
    required void Function(double progress) onProgress,
  });
  Future<RecordingResult> getStatus(String recordingId);
}

/// 플러그인 없이 권한·녹음 실패를 테스트할 수 있는 경계.
abstract class RecorderService {
  Stream<void> get interruptions;
  Future<bool> hasPermission();
  Future<void> start();

  /// 같은 파일에 이어서 녹음할 수 있게 잠시 멈춘다. 멈춘 시간은 길이에 넣지 않는다.
  Future<void> pause();
  Future<void> resume();
  Future<RecordedClip> stop();
  Future<void> discard();
  Future<void> dispose();
}
