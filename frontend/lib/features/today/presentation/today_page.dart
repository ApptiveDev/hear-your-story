import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/audio_playback_card.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../child_answer/presentation/child_answer_args.dart';
import '../../onboarding/data/auth_providers.dart';
import '../../onboarding/presentation/session.dart';
import '../../onboarding/presentation/widgets/logout_button.dart';
import '../../onboarding/domain/app_user.dart';
import '../../recording/presentation/recording_args.dart';
import '../data/today_providers.dart';
import '../domain/today.dart';
import 'today_provider.dart';

/// 오늘 질문 홈. 서버가 계산한 제출·공개 상태에 따라 다음 행동 하나를 보여준다.
///
/// 상대를 기다리거나 음성을 정리하는 동안에는 주기적으로, 앱으로 돌아왔을 때는 바로
/// 서버 상태를 확인해서 바뀌었으면 홈을 다시 그린다.
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  static const waitingPollInterval = Duration(seconds: 10);

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage>
    with WidgetsBindingObserver {
  Timer? _poll;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(TodayPage.waitingPollInterval, (_) {
      final today = ref.read(todayProvider).value;
      if (today != null && shouldWatchToday(today)) _checkForChanges();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 다른 앱에 다녀오거나 다음 날 다시 열면 상대 답이나 새 질문이 있을 수 있다
    if (state == AppLifecycleState.resumed) _checkForChanges();
  }

  /// 화면을 로딩·오류로 바꾸지 않고 확인한 뒤, 바뀐 게 있을 때만 다시 불러온다.
  Future<void> _checkForChanges() async {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final current = ref.read(todayProvider).value;
    if (_checking ||
        current == null ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed) ||
        ModalRoute.of(context)?.isCurrent == false) {
      return; // 답하기·녹음 화면에 있으면 돌아올 때 다시 불러온다
    }
    _checking = true;
    try {
      final json = await ref.read(todayDataSourceProvider).fetchToday();
      if (mounted && hasTodayChanged(current, Today.fromJson(json))) {
        ref.invalidate(todayProvider);
      }
    } on ApiException catch (e) {
      // 페어링 해제·로그인 만료는 다시 불러와서 기존 처리(화면 이동)에 맡긴다
      if (mounted && (e.statusCode == 401 || e.errorCode == 'PAIR_NOT_FOUND')) {
        ref.invalidate(todayProvider);
      }
    } catch (_) {
      // 잠깐의 네트워크 오류는 다음 확인 때 다시 시도한다
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(todayProvider, (_, next) {
      final e = next.error;
      if (e is ApiException && e.errorCode == 'PAIR_NOT_FOUND') {
        context.go('/pairing');
      } else if (e != null) {
        handleSessionExpired(context, ref, e);
      }
    });

    final today = ref.watch(todayProvider);
    return Scaffold(
      persistentFooterButtons: logoutFooter(ref),
      body: SafeArea(
        child: today.when(
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _TodayError(error: e),
          data: (today) => RefreshIndicator(
            onRefresh: () => ref.refresh(todayProvider.future),
            child: _TodayContent(today: today),
          ),
        ),
      ),
    );
  }
}

class _TodayError extends ConsumerWidget {
  const _TodayError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = error;
    if (e is ApiException &&
        (e.errorCode == 'PAIR_NOT_FOUND' || e.statusCode == 401)) {
      return const Center(child: CircularProgressIndicator()); // 다른 화면으로 이동 중
    }
    final message = e is ApiException
        ? (e.errorCode == 'TODAY_ASSIGNMENT_NOT_FOUND'
              ? '오늘 질문을 준비하고 있어요.\n잠시 후 다시 확인해 주세요.'
              : e.userMessage)
        : '문제가 생겼어요. 다시 시도해 주세요.';
    return ErrorRetryView(
      message: message,
      onRetry: () => ref.invalidate(todayProvider),
    );
  }
}

class _TodayContent extends ConsumerWidget {
  const _TodayContent({required this.today});
  final Today today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 가입할 때 저장한 이름. 읽는 중이거나 없으면 인사 없이 보여준다.
    final name = ref.watch(currentUserProvider).value?.name;
    final isChild = today.viewerRole == UserRole.child;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(), // 당겨서 새로고침
      // Figma 홈: 내용 너비 361 (393 화면 좌우 16)
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: () => context.push('/my'),
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: '마이페이지',
          ),
        ),
        Text(
          formatAssignedDate(today.assignedDate),
          textAlign: TextAlign.center,
          style: AppText.label,
        ),
        if (name != null && name.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('안녕하세요 $name님', style: AppText.greeting),
          ),
        ],
        const SizedBox(height: 24),
        _TodayQuestionCard(
          question: today.question.text,
          // 아직 답하지 않았을 때만 카드 안에 답하기 버튼을 둔다
          action: today.iAnswered
              ? null
              : isChild
              ? FilledButton.icon(
                  onPressed: () => _openChildAnswer(context, ref, today, null),
                  icon: const Icon(Icons.edit),
                  label: const Text('답하기'),
                )
              : FilledButton.icon(
                  onPressed: () => _openParentRecording(context, ref, today),
                  icon: const Icon(Icons.mic),
                  label: const Text('목소리로 답하기'),
                ),
        ),
        const SizedBox(height: 32),
        if (isChild)
          _ChildSection(today: today)
        else
          _ParentSection(today: today),
        const SizedBox(height: 32),
        Center(
          child: TextButton.icon(
            onPressed: () => context.push('/stories'),
            icon: const Icon(Icons.menu_book),
            label: const Text('지난 이야기 보기'),
          ),
        ),
      ],
    );
  }
}

/// Figma 오늘의 질문 카드(바깥 창): 모서리 20, 위아래 여백 50, 내용 너비 320.
class _TodayQuestionCard extends StatelessWidget {
  const _TodayQuestionCard({required this.question, this.action});

  final String question;

  /// 카드 아래쪽 주요 행동. 없으면 질문만 보여준다.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 40, 20, action == null ? 40 : 32),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.questionCard),
        boxShadow: AppShadows.questionCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('#오늘의 질문', style: AppText.label),
          const SizedBox(height: 8),
          Text(question, style: AppText.question),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}

/// 다른 화면에 다녀온 뒤 홈을 새로 불러온다.
Future<void> _openAndRefresh(
  BuildContext context,
  WidgetRef ref,
  String location, {
  Object? extra,
}) async {
  await context.push(location, extra: extra);
  ref.invalidate(todayProvider);
}

void _openChildAnswer(
  BuildContext context,
  WidgetRef ref,
  Today today,
  String? initialText,
) {
  _openAndRefresh(
    context,
    ref,
    '/child-answer',
    extra: ChildAnswerArgs(
      assignmentId: today.assignmentId,
      questionText: today.question.text,
      initialText: initialText, // 이미 답했으면 수정 모드
    ),
  );
}

void _openParentRecording(BuildContext context, WidgetRef ref, Today today) {
  final my = today.myAnswer;
  _openAndRefresh(
    context,
    ref,
    '/recording',
    extra: RecordingArgs(
      assignmentId: today.assignmentId,
      questionText: today.question.text,
      questionAudioUrl: today.question.audioUrl,
      recordingId: my is VoiceAnswer ? my.recordingId : null, // 처리 상태 재조회
      canRecord: !today.isRevealed,
    ),
  );
}

class _ChildSection extends ConsumerWidget {
  const _ChildSection({required this.today});
  final Today today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myText = switch (today.myAnswer) {
      TextAnswer(:final text) => text,
      _ => null,
    };

    if (!today.iAnswered) {
      return const _Message('부모님과 같은 질문에 답해요.\n둘 다 답하면\n서로의 답을 볼 수 있어요.');
    }

    if (!today.isRevealed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (myText != null) _AnswerCard(label: '내 답', text: myText),
          const SizedBox(height: 16),
          const _Message('부모님이 답하시면\n여기에서 들을 수 있어요.'),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => _openChildAnswer(context, ref, today, myText),
            child: const Text('답 고치기'),
          ),
        ],
      );
    }

    final parent = today.partnerAnswer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AnswerCard(
          label: '부모님의 답',
          text: parent is VoiceAnswer
              ? parent.displayText ??
                    parent.processingNotice ??
                    '부모님이 목소리로 답하셨어요.'
              : '부모님이 목소리로 답하셨어요.',
          highlighted: true,
        ),
        if (parent is VoiceAnswer && parent.originalAudioUrl != null) ...[
          const SizedBox(height: 12),
          AudioPlaybackCard(
            source: PlaybackSource(
              parent.originalAudioUrl!,
              expiresAt: parent.originalAudioExpiresAt,
            ),
            label: '부모님 목소리 듣기',
            onRefresh: () async {
              final json = await ref.read(todayDataSourceProvider).fetchToday();
              final p = Today.fromJson(json).partnerAnswer;
              if (p is! VoiceAnswer || p.originalAudioUrl == null) {
                throw StateError('음성을 다시 불러오지 못했어요');
              }
              return PlaybackSource(
                p.originalAudioUrl!,
                expiresAt: p.originalAudioExpiresAt,
              );
            },
          ),
        ],
        if (myText != null) ...[
          const SizedBox(height: 16),
          _AnswerCard(label: '내 답', text: myText),
        ],
      ],
    );
  }
}

class _ParentSection extends ConsumerWidget {
  const _ParentSection({required this.today});
  final Today today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!today.iAnswered) {
      return const _Message('목소리로 편하게 답해 주세요.\n30초면 충분해요.');
    }

    if (!today.isRevealed) {
      final my = today.myAnswer;
      final status = my is VoiceAnswer ? my.processingStatus : null;
      // 글 정리에 실패해도 원본 목소리는 저장되어 자녀에게 전달된다
      final notice = switch (status) {
        null || 'READY' => null,
        'FAILED' => '글로 정리하지는 못했지만\n목소리는 그대로 전해져요.',
        _ => '말씀하신 내용을\n글로 정리하고 있어요.',
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Message('목소리를 보냈어요.\n자녀가 답하면\n여기에서 볼 수 있어요.'),
          if (notice != null) ...[const SizedBox(height: 8), _Message(notice)],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _openParentRecording(context, ref, today),
            icon: const Icon(Icons.mic),
            label: const Text('다시 녹음하기'),
          ),
        ],
      );
    }

    final child = today.partnerAnswer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AnswerCard(
          label: '자녀의 답',
          text: child is TextAnswer ? child.text : '자녀가 답했어요.',
          highlighted: true,
        ),
        if (child is TextAnswer) ...[
          const SizedBox(height: 20),
          // 음성 상태 조회·재생·링크 갱신은 부모 답변 화면이 처리한다
          OutlinedButton.icon(
            onPressed: () => context.push('/parent-answer'),
            icon: const Icon(Icons.volume_up),
            label: const Text('목소리로 듣기'),
          ),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodyLarge);
}

/// Figma 답 카드: 모서리 15, 카드색, 그림자 (1, 2) 흐림 7.
/// 상대의 답(highlighted)은 주색 테두리로 구분한다.
class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.label,
    required this.text,
    this.highlighted = false,
  });

  final String label;
  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: highlighted
            ? Border.all(color: AppColors.base, width: 2)
            : null,
        boxShadow: AppShadows.answerCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: 8),
          Text(text, style: AppText.extraInfo.copyWith(color: AppColors.font)),
        ],
      ),
    );
  }
}

/// 홈을 다시 그려야 할 만큼 서버 상태가 바뀌었는지.
/// 음성 링크는 조회할 때마다 새로 서명되므로 비교하지 않는다.
bool hasTodayChanged(Today before, Today after) {
  return before.assignmentId != after.assignmentId ||
      before.revealStatus != after.revealStatus ||
      before.iAnswered != after.iAnswered ||
      _processing(before.myAnswer) != _processing(after.myAnswer) ||
      _processing(before.partnerAnswer) != _processing(after.partnerAnswer);
}

/// 서버 상태가 더 바뀔 수 있어 주기적으로 확인해야 하는지.
///
/// 상대를 기다리는 중이거나, 공개됐어도 부모 음성을 아직 글로 정리하는 중이면
/// 확인한다. 자녀가 먼저 답하면 부모가 올리자마자 공개되므로 자녀 화면에서도
/// 정리 결과(READY/FAILED)를 기다려야 한다.
bool shouldWatchToday(Today today) {
  bool processing(TodayAnswer? a) {
    final status = _processing(a);
    return status != null && status != 'READY' && status != 'FAILED';
  }

  return (today.iAnswered && !today.isRevealed) ||
      processing(today.myAnswer) ||
      processing(today.partnerAnswer);
}

String? _processing(TodayAnswer? a) =>
    a is VoiceAnswer ? a.processingStatus : null;

/// 예: 9월 24일 수요일
String formatAssignedDate(DateTime date) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${date.month}월 ${date.day}일 ${weekdays[date.weekday - 1]}요일';
}
