import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/audio_playback_card.dart';
import '../../../core/widgets/error_text.dart';
import '../../../core/widgets/step_layout.dart';
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
  bool _sending = false;
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

  Future<void> _send() async {
    if (_sending || !_controller.canRetryUpload) return;
    _sending = true;
    try {
      await _audioKey.currentState?.pause();
      if (!mounted) return;
      await _controller.retryUpload();
    } finally {
      _sending = false;
    }
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final c = _controller;
      return PopScope(
        canPop: _allowLeave || (!c.busy && !c.hasDraft),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_leave());
        },
        child: Scaffold(body: SafeArea(child: _body(context, c))),
      );
    },
  );

  /// 녹음 단계에 맞는 Figma 화면(WF-010 ~ WF-016)을 고른다.
  Widget _body(BuildContext context, RecordingController c) {
    switch (c.phase) {
      case RecordingPhase.recording:
      case RecordingPhase.paused:
        return _capturing(c);
      case RecordingPhase.stopping:
        return _waiting(
          title: '녹음을 저장하고 있어요',
          body: '잠시만 기다려 주세요',
          actions: const [],
        );
      case RecordingPhase.uploading:
        return _uploading(c);
      case RecordingPhase.processing:
        return _waiting(
          title: '이야기를 정리하고 있어요',
          body: '녹음은 안전하게 저장했어요.\n정리가 끝나면 알려드릴게요.',
          actions: [..._rerecord(c), _homeButton()],
        );
      case RecordingPhase.ready:
        return _ready(c);
      case RecordingPhase.delayed:
        return _notice(
          title: '정리가 조금 늦어지고 있어요',
          body: '녹음한 목소리는 안전하게 저장되어 있어요.\n조금 뒤에 다시 시도해 볼까요?',
          retry: true,
        );
      case RecordingPhase.processingFailed:
        return _notice(
          title: '글로 정리하지 못했어요',
          body: '녹음한 목소리는 안전하게 저장되어\n그대로 전해져요.',
          retry: false,
        );
      case RecordingPhase.draft:
        return _draft(c);
      case RecordingPhase.error:
        if (c.hasDraft) return _draft(c);
        // 보낸 뒤 처리 상태를 확인하지 못했으면 다시 확인하게 한다.
        // 다시 녹음하다 난 오류(권한·짧은 녹음)는 녹음 시작 화면에서 알린다.
        if (c.statusCheckFailed && c.recordingId != null && !c.locked) {
          return _notice(
            title: '정리 상태를 확인하지 못했어요',
            body: c.message ?? '녹음은 저장됐어요. 다시 확인해 주세요.',
            retry: true,
          );
        }
        return _startView(c);
      case RecordingPhase.idle:
      case RecordingPhase.requestingPermission:
        return _startView(c);
    }
  }

  /// 보낸 뒤 화면(정리 중·완료·지연·실패)에서도 답을 다시 녹음할 수 있게 한다.
  /// 홈의 `다시 녹음하기`는 보낸 녹음의 상태부터 보여주므로 이 버튼이 없으면 막힌다.
  List<Widget> _rerecord(RecordingController c) => [
    if (c.canStart)
      OutlinedButton.icon(
        onPressed: _start,
        icon: const Icon(AppIcons.microphone),
        label: const Text('다시 녹음하기'),
      ),
  ];

  /// 보낸 뒤 화면에서 오늘 화면으로 돌아간다.
  Widget _homeButton({bool primary = false}) {
    const label = Text('홈으로 가기');
    return primary
        ? FilledButton(onPressed: _leave, child: label)
        : OutlinedButton(onPressed: _leave, child: label);
  }

  /// Figma WF-010 녹음 시작 전
  Widget _startView(RecordingController c) {
    final again = c.recordingId != null || c.hasDraft;
    final String caption;
    if (!widget.args.canRecord || c.locked) {
      caption = '이미 공개된 답변이에요';
    } else if (c.phase == RecordingPhase.requestingPermission) {
      caption = '마이크를 준비하고 있어요';
    } else {
      caption = again ? '눌러서 다시 녹음해요' : '눌러서 녹음을 시작해요';
    }
    return StepLayout(
      onBack: _leave,
      actions: const [],
      children: [
        _QuestionCard(question: widget.args.questionText),
        if (widget.args.questionAudioUrl != null) ...[
          const SizedBox(height: 16),
          AudioPlaybackCard(
            key: _audioKey,
            source: PlaybackSource(widget.args.questionAudioUrl!),
            label: '질문 듣기',
            enabled: !c.busy,
          ),
        ],
        const SizedBox(height: 45),
        Center(
          child: _RecordButton(
            recording: false,
            onPressed: c.canStart ? _start : null,
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            caption,
            textAlign: TextAlign.center,
            style: AppText.headingM.copyWith(color: AppColors.textBrand),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '최대 60초까지 녹음할 수 있어요',
          textAlign: TextAlign.center,
          style: AppText.bodyS,
        ),
        if (c.phase == RecordingPhase.error && c.message != null) ...[
          const SizedBox(height: 16),
          ErrorText(c.message!),
        ],
      ],
    );
  }

  /// Figma WF-011 녹음 중 (잠깐 멈춤 포함)
  Widget _capturing(RecordingController c) {
    final paused = c.phase == RecordingPhase.paused;
    final seconds = c.elapsedSeconds;
    return StepLayout(
      onBack: _leave,
      actions: paused
          ? [
              FilledButton.icon(
                onPressed: c.resume,
                icon: const Icon(AppIcons.microphone),
                label: const Text('이어서 말하기'),
              ),
              OutlinedButton(onPressed: c.stop, child: const Text('녹음 끝내기')),
              TextButton(onPressed: _restart, child: const Text('처음부터 다시 말하기')),
            ]
          : [OutlinedButton(onPressed: c.pause, child: const Text('잠깐 멈추기'))],
      children: [
        Text(
          widget.args.questionText,
          textAlign: TextAlign.center,
          style: AppText.headingM,
        ),
        const SizedBox(height: 16),
        Text(
          formatClock(seconds),
          textAlign: TextAlign.center,
          style: AppText.numberXL.copyWith(color: AppColors.textBrand),
        ),
        const SizedBox(height: 16),
        const Text(
          '최대 01:00까지',
          textAlign: TextAlign.center,
          style: AppText.bodyS,
        ),
        const SizedBox(height: 16),
        _Bar(value: seconds / 60),
        const SizedBox(height: 16),
        if (!paused) const _Waveform(),
        const SizedBox(height: 24),
        if (!paused) ...[
          Center(child: _RecordButton(recording: true, onPressed: c.stop)),
          const SizedBox(height: 12),
        ],
        Semantics(
          liveRegion: paused,
          child: Text(
            paused ? '잠깐 멈췄어요' : '녹음하고 있어요',
            textAlign: TextAlign.center,
            style: AppText.headingM.copyWith(color: AppColors.textBrand),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          paused ? '이어서 말하거나 녹음을 끝내고 확인해요' : '다 말씀하셨다면 눌러서 끝내요',
          textAlign: TextAlign.center,
          style: AppText.bodyS,
        ),
      ],
    );
  }

  /// Figma WF-012 녹음 완료·전송 전. 듣기는 선택이며 보내기를 눌러야 전송한다.
  Widget _draft(RecordingController c) {
    final clip = c.draft;
    return StepLayout(
      onBack: _leave,
      actions: [
        if (c.canRetryUpload)
          FilledButton(onPressed: _send, child: const Text('보내기')),
        if (c.canStart)
          OutlinedButton(onPressed: _start, child: const Text('다시 녹음')),
      ],
      children: [
        Text(
          '녹음이 끝났어요',
          style: AppText.headingL.copyWith(color: AppColors.textBrand),
        ),
        const SizedBox(height: 24),
        Text(
          '들어보고 마음에 들면 보내주세요',
          style: AppText.bodyL.copyWith(color: AppColors.textSub),
        ),
        if (clip != null) ...[
          const SizedBox(height: 24),
          AudioPlaybackCard(
            key: _audioKey,
            source: PlaybackSource(Uri.file(clip.path).toString()),
            label: '녹음 들어보기',
          ),
        ],
        if (c.message != null) ...[
          const SizedBox(height: 16),
          ErrorText(c.message!),
        ],
      ],
    );
  }

  /// Figma WF-013 업로드 진행
  Widget _uploading(RecordingController c) {
    final percent = (c.uploadProgress * 100).round();
    return StepLayout(
      onBack: _leave,
      actions: const [],
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            '녹음을 보내고 있어요',
            style: AppText.headingL.copyWith(color: AppColors.textBrand),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '화면을 닫지 말고 잠시만 기다려 주세요',
          style: AppText.bodyL.copyWith(color: AppColors.textSub),
        ),
        const SizedBox(height: 24),
        _Panel(
          children: [
            Text(
              '$percent%',
              style: AppText.numberXL.copyWith(color: AppColors.textBrand),
            ),
            const SizedBox(height: 14),
            _Bar(value: c.uploadProgress),
            const SizedBox(height: 14),
            const Text('보내는 중이에요', style: AppText.bodyS),
          ],
        ),
      ],
    );
  }

  /// Figma WF-014 AI 정리 중 (녹음 저장 중에도 같은 모양을 쓴다)
  Widget _waiting({
    required String title,
    required String body,
    required List<Widget> actions,
  }) {
    return StepLayout(
      onBack: _leave,
      actions: actions,
      children: [
        const SizedBox(height: 120),
        const _Dots(),
        const SizedBox(height: 20),
        _CenterTitle(title),
        const SizedBox(height: 20),
        Text(
          body,
          textAlign: TextAlign.center,
          style: AppText.bodyL.copyWith(color: AppColors.textSub),
        ),
      ],
    );
  }

  /// Figma WF-015 처리 완료
  Widget _ready(RecordingController c) {
    final story = c.result?.summaryText ?? c.result?.sttText;
    return StepLayout(
      onBack: _leave,
      actions: [_homeButton(primary: true), ..._rerecord(c)],
      children: [
        const SizedBox(height: 72),
        const _Badge(
          child: Icon(AppIcons.check, size: 48, color: AppColors.textBrand),
        ),
        const SizedBox(height: 20),
        const _CenterTitle('이야기가 저장됐어요'),
        if (story != null) ...[
          const SizedBox(height: 20),
          _Panel(
            color: AppColors.surfaceCard,
            radius: AppRadius.note,
            children: [
              Text(
                '내 이야기',
                style: AppText.labelM.copyWith(color: AppColors.textBrand),
              ),
              const SizedBox(height: 8),
              Text(
                story,
                style: AppText.bodyL.copyWith(color: AppColors.textStrong),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Figma WF-016 STT·LLM 지연 또는 실패
  Widget _notice({
    required String title,
    required String body,
    required bool retry,
  }) {
    final c = _controller;
    return StepLayout(
      onBack: _leave,
      actions: [
        if (retry)
          FilledButton(
            onPressed: c.busy ? null : c.refreshStatus,
            child: const Text('다시 시도'),
          ),
        _homeButton(primary: !retry),
        ..._rerecord(c),
      ],
      children: [
        const SizedBox(height: 72),
        _Badge(
          child: Text(
            'i',
            style: AppText.numberXL.copyWith(color: AppColors.textBrand),
          ),
        ),
        const SizedBox(height: 16),
        _CenterTitle(title),
        const SizedBox(height: 20),
        Text(
          body,
          textAlign: TextAlign.center,
          style: AppText.bodyL.copyWith(color: AppColors.textSub),
        ),
      ],
    );
  }
}

/// 녹음 시간. 예: 00:23
String formatClock(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Figma `Card/Question` (버튼 없이 질문만)
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});
  final String question;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('#오늘의 질문', style: AppText.labelL),
          const SizedBox(height: 14),
          Text(question, style: AppText.headingL),
        ],
      ),
    );
  }
}

/// Figma `Record Button`: Ready(주황 원 + 마이크) / Recording(테두리 + 네모)
class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.recording, required this.onPressed});

  final bool recording;

  /// null이면 누를 수 없다.
  final VoidCallback? onPressed;

  static const size = 172.0;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // 녹음을 끝내면 전송 전 미리 듣기 화면으로 이동한다.
    final label = recording ? '녹음 끝내기' : '녹음 시작';
    final Widget face = recording
        ? Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.actionPrimaryLight, width: 5),
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.actionPrimaryDark,
              ),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.textOnPrimary,
                  borderRadius: BorderRadius.circular(AppRadius.note),
                ),
              ),
            ),
          )
        : Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? AppColors.actionPrimary : AppColors.borderSoft,
              boxShadow: enabled ? AppShadows.button : null,
            ),
            child: Icon(
              AppIcons.microphone,
              size: 64,
              color: enabled ? AppColors.textOnPrimary : AppColors.textDisabled,
            ),
          );
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(onTap: onPressed, child: face),
      ),
    );
  }
}

/// Figma `Waveform` Live. 실제 소리 크기를 받지 않아 모양만 보여준다.
class _Waveform extends StatelessWidget {
  const _Waveform();

  static const heights = <double>[
    14, 28, 44, 22, 60, 36, 18, 52, 70, 40, 24, 56, 34, //
    64, 20, 46, 30, 58, 26, 42, 16, 50, 32, 22, 12,
  ];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 80,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              for (final (i, h) in heights.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: h,
                  decoration: BoxDecoration(
                    color: AppColors.actionPrimary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 두께 14의 진행 막대 (녹음 시간, 업로드)
class _Bar extends StatelessWidget {
  const _Bar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: value.clamp(0, 1),
      minHeight: 14,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    );
  }
}

/// Figma WF-014 점 세 개
class _Dots extends StatelessWidget {
  const _Dots();

  @override
  Widget build(BuildContext context) {
    const colors = [
      AppColors.actionPrimaryLight,
      AppColors.actionPrimary,
      AppColors.actionPrimaryDark,
    ];
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (i, color) in colors.indexed) ...[
            if (i > 0) const SizedBox(width: 14),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ],
      ),
    );
  }
}

/// Figma 완료·지연 화면의 둥근 표시 (112)
class _Badge extends StatelessWidget {
  const _Badge({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ExcludeSemantics(
        child: Container(
          width: 112,
          height: 112,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            shape: BoxShape.circle,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 가운데 정렬 제목. 화면 읽기 프로그램이 바로 읽게 한다.
class _CenterTitle extends StatelessWidget {
  const _CenterTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.headingL.copyWith(color: AppColors.textBrand),
      ),
    );
  }
}

/// 흰 카드 (업로드 진행, 내 이야기)
class _Panel extends StatelessWidget {
  const _Panel({
    required this.children,
    this.color = AppColors.surfaceWhite,
    this.radius = AppRadius.cardSmall,
  });

  final List<Widget> children;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
