import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../domain/recording.dart';
import '../domain/recording_repository.dart';
import 'recording_args.dart';

enum RecordingPhase {
  idle,
  requestingPermission,
  recording,
  paused,
  stopping,
  draft,
  uploading,
  processing,
  ready,
  processingFailed,
  delayed,
  error,
}

class RecordingController extends ChangeNotifier {
  RecordingController({
    required this.args,
    required this._repository,
    required this._recorder,
    DateTime Function()? now,
    String Function()? createKey,
  }) : _now = now ?? DateTime.now,
       _createKey = createKey ?? _randomKey {
    recordingId = args.recordingId;
    _interruptions = _recorder.interruptions.listen((_) {
      if (phase == RecordingPhase.recording && !_disposed) {
        _operation = _stopAndUpload(upload: false);
      }
    });
  }

  final RecordingArgs args;
  final RecordingRepository _repository;
  final RecorderService _recorder;
  final DateTime Function() _now;
  final String Function() _createKey;
  RecordingPhase phase = RecordingPhase.idle;
  RecordingResult? result;
  String? recordingId;
  String? message;
  int? errorStatus;
  int elapsedSeconds = 0;
  double uploadProgress = 0;
  bool locked = false;
  bool _disposed = false;
  bool _foreground = true;
  RecordedClip? _clip;
  String? _key;
  Timer? _recordTimer;
  Timer? _pollTimer;
  Timer? _deadlineTimer;
  DateTime? _startedAt;
  Duration _recordedBefore = Duration.zero; // 일시정지 전까지 녹음한 시간
  DateTime? _pollStartedAt;
  int _pollGeneration = 0;
  int _captureGeneration = 0; // 녹음을 끝내거나 새로 시작할 때마다 늘린다
  Future<void>? _operation;
  StreamSubscription<void>? _interruptions;

  bool get busy => const [
    RecordingPhase.requestingPermission,
    RecordingPhase.recording,
    RecordingPhase.paused,
    RecordingPhase.stopping,
    RecordingPhase.uploading,
  ].contains(phase);

  /// 녹음이 진행 중이거나 일시정지되어 아직 파일이 만들어지지 않은 상태
  bool get isCapturing =>
      phase == RecordingPhase.recording || phase == RecordingPhase.paused;
  bool get hasDraft => _clip != null;
  bool get canStart => args.canRecord && !locked && !busy;
  bool get canRetryUpload =>
      hasDraft && !busy && !locked && errorStatus != 413 && errorStatus != 422;

  static String _randomKey() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() {
    if (!canStart || !_foreground || _disposed) return Future.value();
    return _operation = _start();
  }

  Future<void> _start() async {
    _captureGeneration++;
    _stopPolling();
    phase = RecordingPhase.requestingPermission;
    message = null;
    errorStatus = null;
    _emit();
    try {
      if (!await _recorder.hasPermission()) {
        if (_disposed) return;
        phase = RecordingPhase.error;
        message = '마이크 권한이 필요해요. 권한을 허용하거나 휴대폰 설정에서 마이크를 켜 주세요.';
        _emit();
        return;
      }
      if (_disposed) return;
      if (!_foreground) {
        phase = RecordingPhase.idle;
        _emit();
        return;
      }
      _clip = null;
      _key = null;
      await _recorder.start();
      if (_disposed) return;
      elapsedSeconds = 0;
      _recordedBefore = Duration.zero;
      _startedAt = _now();
      phase = RecordingPhase.recording;
      _emit();
      if (!_foreground) {
        await _stopAndUpload(upload: false);
        return;
      }
      _startRecordTimer();
    } catch (error) {
      _fail(error, fallback: '녹음을 시작하지 못했어요. 마이크를 확인하고 다시 시도해 주세요.');
    }
  }

  Duration get _recordedTotal =>
      _recordedBefore + _now().difference(_startedAt!);

  void _startRecordTimer() {
    _recordTimer?.cancel(); // 이어가기가 겹쳐도 타이머는 하나만 둔다
    _recordTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      elapsedSeconds = _recordedTotal.inSeconds.clamp(0, 60);
      _emit();
      if (elapsedSeconds >= 60) unawaited(stop());
    });
  }

  Future<void> pause() {
    if (phase != RecordingPhase.recording || _disposed) return Future.value();
    return _operation = _pause();
  }

  Future<void> _pause() async {
    _recordTimer?.cancel();
    _recordedBefore = _recordedTotal;
    elapsedSeconds = _recordedBefore.inSeconds.clamp(0, 60);
    phase = RecordingPhase.paused;
    _emit();
    final generation = _captureGeneration;
    try {
      await _recorder.pause();
    } catch (_) {
      // 기다리는 사이 이미 끝낸 녹음이면 결과를 덮어쓰지 않는다.
      if (_disposed || generation != _captureGeneration) return;
      // 멈추지 못하면 녹음이 계속되므로 지금까지의 녹음을 파일로 남긴다.
      await _stopAndUpload(upload: false);
    }
  }

  Future<void> resume() {
    if (phase != RecordingPhase.paused || !_foreground || _disposed) {
      return Future.value();
    }
    return _operation = _resume();
  }

  Future<void> _resume() async {
    phase = RecordingPhase.recording;
    _startedAt = _now();
    _emit();
    final generation = _captureGeneration;
    try {
      await _recorder.resume();
      // 기다리는 사이 녹음을 끝냈으면 시간을 다시 재지 않는다.
      if (_disposed ||
          generation != _captureGeneration ||
          phase != RecordingPhase.recording) {
        return;
      }
      _startRecordTimer();
    } catch (_) {
      // 기다리는 사이 이미 끝낸 녹음이면 결과를 덮어쓰지 않는다.
      if (_disposed || generation != _captureGeneration) return;
      await _stopAndUpload(upload: false);
    }
  }

  /// 멈춘 녹음을 버리고 처음부터 다시 녹음한다.
  Future<void> restart() {
    if (phase != RecordingPhase.paused || !_foreground || _disposed) {
      return Future.value();
    }
    return _operation = _start(); // 녹음기가 시작할 때 이전 녹음을 지운다
  }

  Future<void> stop() {
    if (!isCapturing || _disposed) return Future.value();
    return _operation = _stopAndUpload(upload: _foreground);
  }

  Future<void> _stopAndUpload({required bool upload}) async {
    _captureGeneration++;
    _recordTimer?.cancel();
    phase = RecordingPhase.stopping;
    _emit();
    try {
      final clip = await _recorder.stop();
      if (_disposed) return;
      final invalid = clip.validationMessage;
      if (invalid != null) {
        _clip = null;
        phase = RecordingPhase.error;
        message = invalid;
        _emit();
        return;
      }
      _clip = clip;
      _key = _createKey();
      phase = RecordingPhase.draft;
      if (upload && _foreground) {
        await _upload();
      } else {
        message = '녹음을 멈췄어요. 녹음 보내기를 누르거나 다시 녹음해 주세요.';
        _emit();
      }
    } catch (error) {
      _fail(error, fallback: '녹음을 저장하지 못했어요. 다시 녹음해 주세요.');
    }
  }

  Future<void> retryUpload() {
    if (!canRetryUpload || !_foreground || _disposed) return Future.value();
    return _operation = _upload();
  }

  Future<void> _upload() async {
    phase = RecordingPhase.uploading;
    uploadProgress = 0;
    message = null;
    errorStatus = null;
    _emit();
    try {
      final submission = await _repository.upload(
        assignmentId: args.assignmentId,
        clip: _clip!,
        idempotencyKey: _key!, // 같은 파일 재전송은 같은 키를 유지한다.
        onProgress: (value) {
          if (_disposed) return;
          uploadProgress = value;
          _emit();
        },
      );
      if (_disposed) return;
      recordingId = submission.recordingId;
      result = null;
      _clip = null;
      _key = null;
      // 정리 실패 때문에 이미 성공한 업로드를 실패로 바꾸지 않는다.
      try {
        await _recorder.discard();
      } catch (_) {
        /* 다음 종료 시 정리 */
      }
      if (_disposed) return;
      phase = RecordingPhase.processing;
      _emit();
      if (_foreground) refreshStatus();
    } catch (error) {
      _fail(error);
    }
  }

  void refreshStatus() {
    if (_disposed || !_foreground || recordingId == null || busy || hasDraft) {
      return;
    }
    _stopPolling();
    phase = RecordingPhase.processing;
    message = null;
    errorStatus = null;
    _pollStartedAt = _now();
    final generation = _pollGeneration;
    _deadlineTimer = Timer(const Duration(seconds: 60), () {
      if (_disposed || generation != _pollGeneration) return;
      _stopPolling();
      phase = RecordingPhase.delayed;
      message = '녹음은 저장됐어요. 음성 정리에 시간이 걸리고 있어요.';
      _emit();
    });
    _emit();
    unawaited(_poll(generation));
  }

  Future<void> _poll(int generation) async {
    try {
      final next = await _repository.getStatus(recordingId!);
      if (_disposed || generation != _pollGeneration || !_foreground) return;
      result = next;
      if (next.status.isTerminal) {
        _stopPolling();
        phase = next.status == ProcessingStatus.ready
            ? RecordingPhase.ready
            : RecordingPhase.processingFailed;
        message = next.status == ProcessingStatus.failed
            ? '음성 정리는 완료하지 못했지만 녹음은 안전하게 저장됐어요.'
            : null;
        _emit();
        return;
      }
      _emit();
      final elapsed = _now().difference(_pollStartedAt!);
      _pollTimer = Timer(
        Duration(seconds: elapsed.inSeconds < 30 ? 3 : 5),
        () => unawaited(_poll(generation)),
      );
    } catch (error) {
      if (_disposed || generation != _pollGeneration) return;
      _stopPolling();
      _fail(error, fallback: '녹음은 저장됐지만 처리 상태를 확인하지 못했어요. 다시 확인해 주세요.');
    }
  }

  /// 백그라운드에서는 새 녹음·폴링을 시작하지 않는다.
  void setForeground(bool foreground) {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    if (!foreground) {
      _stopPolling();
      if (isCapturing) _operation = _stopAndUpload(upload: false);
    } else if (!busy && !hasDraft && recordingId != null) {
      refreshStatus();
    }
  }

  void _stopPolling() {
    _pollGeneration++;
    _pollTimer?.cancel();
    _deadlineTimer?.cancel();
  }

  void _fail(Object error, {String fallback = '녹음을 보내지 못했어요. 다시 시도해 주세요.'}) {
    if (_disposed) return;
    phase = RecordingPhase.error;
    errorStatus = error is ApiException ? error.statusCode : null;
    locked = error is ApiException && error.errorCode == 'ANSWER_LOCKED';
    message = locked
        ? '이미 공개된 답변은 바꿀 수 없어요.'
        : error is ApiException
        ? error.userMessage
        : fallback;
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    _recordTimer?.cancel();
    _stopPolling();
    unawaited(_interruptions?.cancel());
    // 진행 중인 파일 작업이 끝난 뒤 마이크와 임시 파일을 정리한다.
    unawaited(_release());
    super.dispose();
  }

  Future<void> _release() async {
    try {
      await _operation;
    } catch (_) {
      /* 화면은 이미 닫힘 */
    }
    try {
      await _recorder.dispose();
    } catch (_) {
      /* 다음 실행 시 캐시 정리 */
    }
  }
}
