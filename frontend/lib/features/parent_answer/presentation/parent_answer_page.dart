import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/audio_playback_card.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/step_layout.dart';
import '../../onboarding/presentation/session.dart';
import '../data/parent_answer_providers.dart';
import '../domain/parent_answer.dart';
import 'parent_answer_controller.dart';

/// context.push('/parent-answer')로 인자 없이 진입한다.
/// today를 재조회해 서버가 공개를 허용한 자녀 답변만 표시한다.
class ParentAnswerPage extends ConsumerStatefulWidget {
  const ParentAnswerPage({super.key, this.controller});
  final ParentAnswerController? controller;

  @override
  ConsumerState<ParentAnswerPage> createState() => _ParentAnswerPageState();
}

class _ParentAnswerPageState extends ConsumerState<ParentAnswerPage>
    with WidgetsBindingObserver {
  late final ParentAnswerController _controller;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        ParentAnswerController(ref.read(parentAnswerRepositoryProvider));
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_checkAccess);
    unawaited(_controller.load());
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
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _controller.setForeground(state == AppLifecycleState.resumed);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_checkAccess);
    _controller.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go('/today');

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => Scaffold(body: SafeArea(child: _body(context))),
  );

  Widget _body(BuildContext context) {
    final c = _controller;
    if (c.loading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: '답변 불러오는 중'),
      );
    }
    if (c.message != null) {
      return ErrorRetryView(message: c.message!, onRetry: c.load);
    }
    final answer = c.answer;
    if (answer == null) return const Center(child: Text('답변을 확인하고 있어요.'));

    final childText = answer.canView ? answer.text : null;
    return StepLayout(
      // 홈에서 push로 들어왔으면 pop해서 홈이 새로고침되게 한다
      onBack: _back,
      actions: childText == null || answer.answerId == null
          ? const []
          : _audioActions(c),
      children: [
        Text(
          '오늘의 질문',
          style: AppText.labelM.copyWith(color: AppColors.textBrand),
        ),
        const SizedBox(height: 8),
        Text(answer.questionText, style: AppText.headingM),
        const SizedBox(height: 16),
        _NotePage(
          myText: answer.myText,
          childText: childText,
          waitingText: answer.canView
              ? '아직 표시할 답변이 없어요.'
              : waitingMessage(answer.revealStatus),
        ),
      ],
    );
  }

  /// Figma WF-021 ~ WF-023: 음성 상태에 따라 아래 버튼이 바뀐다.
  List<Widget> _audioActions(ParentAnswerController c) {
    final audio = c.audio;
    if (audio?.status == AnswerTtsStatus.ready && audio?.url != null) {
      return [
        AudioPlaybackCard(
          source: PlaybackSource(audio!.url!, expiresAt: audio.expiresAt),
          label: '자녀의 답변 듣기',
          onRefresh: c.refreshAudioSource,
        ),
      ];
    }
    if (c.audioLoading || audio?.status == AnswerTtsStatus.processing) {
      return [
        if (c.audioMessage != null)
          Text(
            c.audioMessage!,
            textAlign: TextAlign.center,
            style: AppText.bodyS,
          ),
        const FilledButton(onPressed: null, child: Text('목소리를 담고 있어요')),
      ];
    }
    return [
      Text(
        c.audioMessage ?? '목소리는 잠시 후 다시 들려드릴게요',
        textAlign: TextAlign.center,
        style: AppText.bodyM.copyWith(color: AppColors.textSub),
      ),
      OutlinedButton(onPressed: c.retryAudio, child: const Text('다시 시도')),
    ];
  }
}

/// 자녀 답을 아직 볼 수 없을 때의 안내 (Figma WF-020)
String waitingMessage(String revealStatus) => switch (revealStatus) {
  'WAITING_FOR_PARENT' => '오늘 이야기를 들려주시면\n여기에 나타나요.',
  _ => '곧 도착해요.\n도착하면 여기에 나타나요.',
};

/// Figma `Note/Page`: 내 이야기와 자녀의 이야기가 함께 적힌 공책 한 장.
///
/// 디자인의 왼쪽 구멍·줄 장식은 빼고 두 이야기만 옮겼다.
class _NotePage extends StatelessWidget {
  const _NotePage({
    required this.myText,
    required this.childText,
    required this.waitingText,
  });

  final String? myText;
  final String? childText;

  /// 자녀 답이 없을 때 그 자리에 보여줄 안내
  final String waitingText;

  @override
  Widget build(BuildContext context) {
    final myText = this.myText;
    final childText = this.childText;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.note),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (myText != null) ...[
            const _NoteLabel(icon: AppIcons.heart, text: '내 이야기'),
            const SizedBox(height: 8),
            Text(
              myText,
              style: AppText.bodyL.copyWith(color: AppColors.textStrong),
            ),
            const SizedBox(height: 32),
          ],
          const _NoteLabel(icon: AppIcons.childHead, text: '자녀의 이야기'),
          const SizedBox(height: 8),
          if (childText != null)
            Text(
              childText,
              style: AppText.bodyL.copyWith(color: AppColors.textStrong),
            )
          else
            Semantics(
              liveRegion: true,
              child: Text(
                waitingText,
                style: AppText.bodyL.copyWith(color: AppColors.textSub),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteLabel extends StatelessWidget {
  const _NoteLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.textBrand),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: AppText.labelM.copyWith(color: AppColors.textBrand),
          ),
        ),
      ],
    );
  }
}
