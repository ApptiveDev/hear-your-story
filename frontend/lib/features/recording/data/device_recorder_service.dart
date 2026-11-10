import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../domain/recording.dart';
import '../domain/recording_repository.dart';

class DeviceRecorderService implements RecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  final Stopwatch _watch = Stopwatch();
  Directory? _directory;

  /// 사용자가 누른 일시정지도 같은 pause 상태로 오므로 전화 같은 방해와 구분한다.
  bool _pausedByUser = false;

  @override
  Stream<void> get interruptions => _recorder
      .onStateChanged()
      .where((state) => state == RecordState.pause && !_pausedByUser)
      .map((_) {});

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    await discard();
    _pausedByUser = false;
    // 캐시가 비워져 임시 폴더 자체가 없을 수 있으므로 먼저 만든다.
    final temporary = await (await getTemporaryDirectory()).create(
      recursive: true,
    );
    _directory = await temporary.createTemp('parent_recording_');
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
      path: '${_directory!.path}/answer.m4a',
    );
    _watch
      ..reset()
      ..start();
  }

  @override
  Future<void> pause() async {
    _pausedByUser = true;
    await _recorder.pause();
    _watch.stop();
  }

  @override
  Future<void> resume() async {
    await _recorder.resume();
    _pausedByUser = false;
    _watch.start();
  }

  @override
  Future<RecordedClip> stop() async {
    _watch.stop();
    final path = await _recorder.stop();
    if (path == null) throw const FileSystemException('녹음 파일 없음');
    return RecordedClip(
      path: path,
      // 자동 정지 콜백의 수 ms 지연은 사용자 녹음 길이에 포함하지 않는다.
      duration: _watch.elapsed > const Duration(seconds: 60)
          ? const Duration(seconds: 60)
          : _watch.elapsed,
      bytes: await File(path).length(),
    );
  }

  @override
  Future<void> discard() async {
    _watch.stop();
    await _recorder.cancel();
    final directory = _directory;
    _directory = null;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true); // 이 서비스가 만든 임시 폴더만 삭제
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await discard();
    } finally {
      await _recorder.dispose();
    }
  }
}
