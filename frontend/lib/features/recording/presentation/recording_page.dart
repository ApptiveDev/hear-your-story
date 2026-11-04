import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/audio_playback_card.dart';
import '../../../core/network/api_exception.dart';
import '../../onboarding/presentation/session.dart';
import '../data/device_recorder_service.dart';
import '../data/recording_providers.dart';
import 'recording_args.dart';
import 'recording_controller.dart';

class RecordingPage extends ConsumerStatefulWidget {
  const RecordingPage({super.key, required this.args, this.controller});
  final RecordingArgs args;
  final RecordingController? controller;

  @override
  ConsumerState<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends ConsumerState<RecordingPage>
    with WidgetsBindingObserver {
  late final RecordingController _controller;
  final _audioKey = GlobalKey<AudioPlaybackCardState>();
  bool _allowLeave = false;
  bool _askingLeave = false;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        RecordingController(
          args: widget.args,
          repository: ref.read(recordingRepositoryProvider),
          recorder: DeviceRecorderService(),
        );
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_checkAccess);
    if (widget.args.recordingId != null) _controller.refreshStatus();
  }

  void _checkAccess() {
    if (_redirecting || !mounted) return;
    final status = _controller.errorStatus;
    if (status != 401 && status != 403) return;
    _redirecting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (status == 401) {
        await handleSessionExpired(context, ref, ApiException(statusCode: 401));
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('이 화면은 볼 수 없어요.')));
      context.go('/today');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.setForeground(state == AppLifecycleState.resumed);
  }

  Future<void> _start() async {
    await _audioKey.currentState?.pause();
    if (!mounted) return;
    if (_controller.hasDraft) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('다시 녹음할까요?'),
          content: const Text('아직 보내지 않은 녹음은 지워져요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('계속 보관'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('다시 녹음'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    await _controller.start();
  }

  Future<void> _restart() async {
    final restart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('처음부터 다시 말할까요?'),
        content: const Text('지금까지 말한 내용은 지워져요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('그대로 두기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('다시 말하기'),
          ),
        ],
      ),
    );
    if (restart == true && mounted) await _controller.restart();
  }

  Future<void> _leave() async {
    if (_askingLeave) return;
    if (_controller.busy && !_controller.isCapturing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('녹음을 저장하고 있어요. 잠시 기다려 주세요.')),
      );
      return;
    }
    if (_controller.isCapturing || _controller.hasDraft) {
      _askingLeave = true;
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('녹음을 그만둘까요?'),
          content: const Text('아직 보내지 않은 녹음은 저장되지 않아요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('계속하기'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('나가기'),
            ),
          ],
        ),
      );
      _askingLeave = false;
      if (leave != true || !mounted) return;
    }
    if (!mounted) return;
    setState(() => _allowLeave = true);
    // PopScope가 갱신된 뒤 나가야 뒤로가기가 다시 막히지 않는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/today');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_checkAccess);
    _controller.dispose();
    super.dispose();
  }

  String get _statusText => switch (_controller.phase) {
    RecordingPhase.idle =>
      widget.args.canRecord ? '편하게 이야기해 주세요.' : '이미 공개된 답변이에요.',
    RecordingPhase.requestingPermission => '마이크를 준비하고 있어요.',
    RecordingPhase.recording => '녹음 중 · ${_controller.elapsedSeconds}초 / 60초',
    RecordingPhase.paused => '잠깐 멈췄어요 · ${_controller.elapsedSeconds}초 / 60초',
    RecordingPhase.stopping => '녹음을 저장하고 있어요.',
    RecordingPhase.draft => '녹음을 보낼 준비가 됐어요.',
    RecordingPhase.uploading =>
      '녹음 보내는 중 · ${(_controller.uploadProgress * 100).round()}%',
    RecordingPhase.processing => '녹음은 저장됐어요. 이야기를 정리하고 있어요.',
    RecordingPhase.ready => '오늘 이야기가 저장됐어요.',
    RecordingPhase.processingFailed => '녹음은 안전하게 저장됐어요.',
    RecordingPhase.delayed => '녹음은 저장됐어요. 아직 정리 중이에요.',
    RecordingPhase.error => '안내를 확인해 주세요.',
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final c = _controller;
      final recording = c.phase == RecordingPhase.recording;
      final paused = c.phase == RecordingPhase.paused;
      return PopScope(
        canPop: _allowLeave || (!c.busy && !c.hasDraft),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_leave());
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('오늘의 이야기'),
            leading: IconButton(
              onPressed: _leave,
              tooltip: '뒤로',
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  widget.args.questionText,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                if (widget.args.questionAudioUrl != null)
                  AudioPlaybackCard(
                    key: _audioKey,
                    source: PlaybackSource(widget.args.questionAudioUrl!),
                    label: '질문 듣기',
                    enabled: !c.busy,
                  ),
                const SizedBox(height: 24),
                Icon(
                  recording
                      ? Icons.mic
                      : paused
                      ? Icons.pause_circle_outline
                      : c.phase == RecordingPhase.ready
                      ? Icons.check_circle_outline
                      : Icons.mic_none,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: !recording,
                  child: Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 16),
                if (c.phase == RecordingPhase.uploading) ...[
                  LinearProgressIndicator(value: c.uploadProgress),
                  const SizedBox(height: 16),
                  const Text('전송이 끝날 때까지 앱을 닫지 말아 주세요.'),
                ],
                if (c.phase == RecordingPhase.processing)
                  const LinearProgressIndicator(),
                if (c.message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(liveRegion: true, child: Text(c.message!)),
                  ),
                if (c.result?.summaryText != null) ...[
                  const SizedBox(height: 16),
                  const Text('이야기 정리'),
                  Text(c.result!.summaryText!),
                ],
                const SizedBox(height: 24),
                if (recording) ...[
                  FilledButton.icon(
                    onPressed: c.stop,
                    icon: const Icon(Icons.stop),
                    label: const Text('그만 말하고 보내기'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: c.pause,
                    icon: const Icon(Icons.pause),
                    label: const Text('잠깐 멈추기'),
                  ),
                ],
                if (paused) ...[
                  FilledButton.icon(
                    onPressed: c.resume,
                    icon: const Icon(Icons.mic),
                    label: const Text('이어서 말하기'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: c.stop,
                    icon: const Icon(Icons.stop),
                    label: const Text('그만 말하고 보내기'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.replay),
                    label: const Text('처음부터 다시 말하기'),
                  ),
                ],
                if (c.canRetryUpload)
                  FilledButton.icon(
                    onPressed: c.retryUpload,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('녹음 보내기'),
                  ),
                if (c.canStart)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.mic),
                      label: Text(
                        c.recordingId != null || c.hasDraft
                            ? '다시 녹음하기'
                            : '말하기 시작',
                      ),
                    ),
                  ),
                if (!c.busy &&
                    !c.hasDraft &&
                    c.recordingId != null &&
                    c.phase != RecordingPhase.ready)
                  TextButton(
                    onPressed: c.phase == RecordingPhase.processing
                        ? null
                        : c.refreshStatus,
                    child: const Text('처리 상태 다시 확인'),
                  ),
                if (c.phase == RecordingPhase.idle)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('최대 60초까지 녹음할 수 있어요. 짧게 말해도 괜찮아요.'),
                  ),
                if (!c.busy)
                  TextButton(onPressed: _leave, child: const Text('오늘 화면으로')),
              ],
            ),
          ),
        ),
      );
    },
  );
}
