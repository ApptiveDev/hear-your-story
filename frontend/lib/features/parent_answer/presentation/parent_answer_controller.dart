import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/audio_playback_card.dart';
import '../domain/parent_answer.dart';
import '../domain/parent_answer_repository.dart';

class ParentAnswerController extends ChangeNotifier {
  ParentAnswerController(this._repository);
  final ParentAnswerRepository _repository;
  ParentAnswer? answer;
  AnswerAudio? audio;
  bool loading = false;
  bool audioLoading = false;
  bool empty = false;
  String? message;
  String? audioMessage;
  int? errorStatus;
  Timer? _timer;
  Timer? _deadline;
  int _generation = 0;
  bool _disposed = false;
  bool _foreground = true;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed || !_foreground || loading) return;
    _cancel();
    final generation = _generation;
    loading = true;
    audioLoading = false;
    message = null;
    audioMessage = null;
    errorStatus = null;
    answer = null;
    audio = null;
    empty = false;
    _emit();
    try {
      final next = await _repository.getToday();
      if (!_active(generation)) return;
      answer = next;
      loading = false;
      _emit();
      if (next.canView && next.answerId != null) retryAudio();
    } catch (error) {
      if (!_active(generation)) return;
      loading = false;
      errorStatus = error is ApiException ? error.statusCode : null;
      empty =
          error is ApiException &&
          error.errorCode == 'TODAY_ASSIGNMENT_NOT_FOUND';
      message = empty
          ? '오늘 질문이 아직 준비되지 않았어요.'
          : error is ApiException
          ? error.userMessage
          : '답변을 불러오지 못했어요. 다시 시도해 주세요.';
      _emit();
    }
  }

  void retryAudio() {
    if (_disposed ||
        !_foreground ||
        audioLoading ||
        answer?.canView != true ||
        answer?.answerId == null) {
      return;
    }
    _cancel();
    final generation = _generation;
    _deadline = Timer(const Duration(seconds: 60), () {
      if (!_active(generation)) return;
      _cancel();
      audioLoading = false;
      audioMessage = '음성을 준비하고 있어요. 글을 먼저 읽어 주세요.';
      _emit();
    });
    unawaited(_loadAudio(generation));
  }

  Future<void> _loadAudio(int generation) async {
    audioLoading = true;
    audioMessage = null;
    _emit();
    try {
      final next = await _repository.getAudio(answer!.answerId!);
      if (!_active(generation)) return;
      audio = next;
      audioLoading = false;
      switch (next.status) {
        case AnswerTtsStatus.processing:
          audioMessage = '답변을 읽어 줄 음성을 준비하고 있어요.';
          _timer = Timer(
            const Duration(seconds: 5),
            () => unawaited(_loadAudio(generation)),
          );
        case AnswerTtsStatus.failed:
          _deadline?.cancel();
          audioMessage = '음성은 준비하지 못했지만 글로 답변을 볼 수 있어요.';
        case AnswerTtsStatus.notRequested:
          _deadline?.cancel();
          audioMessage = '아직 준비된 음성이 없어요. 글로 답변을 확인해 주세요.';
        case AnswerTtsStatus.ready:
          _deadline?.cancel();
          if (next.url == null) audioMessage = '음성 주소를 확인하지 못했어요. 다시 확인해 주세요.';
      }
      _emit();
    } catch (error) {
      if (!_active(generation)) return;
      _deadline?.cancel();
      audioLoading = false;
      errorStatus = error is ApiException ? error.statusCode : null;
      if (errorStatus == 401 || errorStatus == 403) {
        answer = null;
        audio = null;
      }
      audioMessage = error is ApiException
          ? error.userMessage
          : '음성을 확인하지 못했어요. 다시 시도해 주세요.';
      _emit();
    }
  }

  /// URL 만료 시 읽기 API만 호출한다. TTS 생성 요청은 하지 않는다.
  Future<PlaybackSource> refreshAudioSource() async {
    if (_disposed ||
        !_foreground ||
        answer?.canView != true ||
        answer?.answerId == null) {
      throw StateError('공개 답변 없음');
    }
    final generation = _generation;
    try {
      final next = await _repository.getAudio(answer!.answerId!);
      if (!_active(generation) ||
          next.status != AnswerTtsStatus.ready ||
          next.url == null) {
        throw StateError('음성 준비 중');
      }
      audio = next;
      return PlaybackSource(next.url!, expiresAt: next.expiresAt);
    } on ApiException catch (error) {
      if (_active(generation) &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        errorStatus = error.statusCode;
        answer = null;
        audio = null;
        _emit();
      }
      rethrow;
    }
  }

  bool _active(int generation) =>
      !_disposed && _foreground && generation == _generation;

  void setForeground(bool foreground) {
    if (_disposed || foreground == _foreground) return;
    _foreground = foreground;
    if (!foreground) {
      _cancel();
      loading = false;
      audioLoading = false;
    } else {
      unawaited(load());
    }
  }

  /// 음성이 준비 중이라 다음 확인을 기다리는 중인지. 60초가 지나 확인을 멈추면 false.
  bool get audioPolling => _timer?.isActive ?? false;

  void _cancel() {
    _generation++;
    _timer?.cancel();
    _deadline?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel();
    super.dispose();
  }
}
