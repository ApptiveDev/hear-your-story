import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/code_cells.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/error_text.dart';
import '../../../core/widgets/page_title.dart';
import '../../../core/widgets/step_layout.dart';
import '../../onboarding/data/auth_providers.dart';
import '../../onboarding/domain/app_user.dart';
import '../../onboarding/presentation/session.dart';
import '../../onboarding/presentation/widgets/logout_button.dart';
import '../../stories/presentation/stories_controller.dart';
import '../../stories/presentation/stories_month_provider.dart';
import '../data/pairing_providers.dart';
import '../domain/pairing_repository.dart';
import 'expiry_format.dart';
import 'invite_share.dart';
import 'pairing_controller.dart';

/// 자녀는 초대 코드를 보여주며 연결을 기다리고, 부모는 코드를 입력한다.
class PairingPage extends ConsumerWidget {
  const PairingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      persistentFooterButtons: [
        TextButton(
          onPressed: user.value == null
              ? null
              : () {
                  // 상대 탈퇴 전의 답변·음성 URL이 캐시에 남지 않게 다시 조회한다.
                  ref.invalidate(storiesControllerProvider);
                  ref.invalidate(storiesMonthProvider);
                  context.go('/stories');
                },
          child: const Text('지난 이야기 보기'),
        ),
        ...logoutFooter(ref),
      ],
      body: SafeArea(
        child: user.when(
          // 가입 직후 다시 읽는 동안 이전 값(null)을 쓰면 가입 화면으로 잘못 돌아간다
          skipLoadingOnRefresh: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ErrorRetryView(
            message: '정보를 불러오지 못했어요.',
            onRetry: () => ref.invalidate(currentUserProvider),
          ),
          data: (user) {
            if (user == null) {
              // 가입 정보가 없으면 가입부터
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => context.go('/onboarding'),
              );
              return const SizedBox.shrink();
            }
            // 방금 연결됐으면 축하 화면을 먼저 보여준다
            if (ref.watch(justPairedProvider)) {
              return _PairedView(role: user.role);
            }
            return user.role == UserRole.child
                ? const _ChildInviteView()
                : const _ParentJoinView();
          },
        ),
      ),
    );
  }
}

/// Figma WF-003 초대 코드 생성·대기 / 코드 만료 (자녀)
class _ChildInviteView extends ConsumerStatefulWidget {
  const _ChildInviteView();

  @override
  ConsumerState<_ChildInviteView> createState() => _ChildInviteViewState();
}

class _ChildInviteViewState extends ConsumerState<_ChildInviteView>
    with WidgetsBindingObserver {
  static const pollInterval = Duration(seconds: 3);
  Timer? _poll;
  bool _checking = false;

  /// `새 코드 받기`로 다시 받는 중인지
  bool _renewing = false;

  /// 새로 받았는데도 기기 시각으로는 지나 보이는 코드. 기기 시각이 틀렸을 수 있어
  /// 이 코드는 만료로 보지 않는다(계속 `새 코드 받기`만 보이지 않게).
  String? _trustedCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(pollInterval, (_) => _checkPaired());
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 초대 화면을 켜 둔 채 다음 날 돌아와도 바로 확인한다
    if (state == AppLifecycleState.resumed) _checkPaired();
  }

  Future<void> _checkPaired() async {
    if (_checking) return;
    _checking = true;
    try {
      final paired = await ref.read(pairingRepositoryProvider).isPaired();
      if (paired && mounted) {
        _poll?.cancel();
        ref.read(justPairedProvider.notifier).mark();
      }
    } catch (e) {
      // 로그인 만료면 가입 화면으로, 잠깐의 네트워크 오류는 다음 확인 때 다시 시도한다.
      if (mounted && await handleSessionExpired(context, ref, e)) {
        _poll?.cancel();
      }
    } finally {
      _checking = false;
    }
  }

  /// 서버는 만료된 초대 대신 새 초대를 만들어 준다.
  void _renew() {
    setState(() => _renewing = true);
    ref.invalidate(invitationProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(invitationProvider, (_, next) {
      final invitation = next.value;
      // 다시 받는 동안(로딩)에도 value에는 옛 코드가 남아 있어 새 코드가 올 때까지 기다린다
      if (_renewing && !next.isLoading && invitation != null) {
        _renewing = false;
        if (!DateTime.now().isBefore(invitation.expiresAt)) {
          _trustedCode = invitation.inviteCode;
        }
      }
      final e = next.error;
      if (e == null) return;
      _renewing = false;
      if (isAlreadyPaired(e)) {
        context.go('/today');
        // 저장소가 연결됨으로 바뀌었으니 마이페이지 등이 새 정보를 읽게 한다
        ref.invalidate(currentUserProvider);
      } else {
        handleSessionExpired(context, ref, e);
      }
    });

    final invitation = ref.watch(invitationProvider);
    return invitation.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetryView(
        message: '초대 코드를 만들지 못했어요.',
        onRetry: () => ref.invalidate(invitationProvider),
      ),
      data: (invitation) => _InviteContent(
        invitation: invitation,
        trusted: invitation.inviteCode == _trustedCode,
        onRenew: _renew,
      ),
    );
  }
}

class _InviteContent extends ConsumerStatefulWidget {
  const _InviteContent({
    required this.invitation,
    required this.trusted,
    required this.onRenew,
  });

  final Invitation invitation;

  /// true면 기기 시각과 상관없이 쓸 수 있는 코드로 본다.
  final bool trusted;
  final VoidCallback onRenew;

  @override
  ConsumerState<_InviteContent> createState() => _InviteContentState();
}

class _InviteContentState extends ConsumerState<_InviteContent> {
  /// 남은 시간을 1초마다 다시 그린다.
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  Future<void> _share() async {
    try {
      await ref.read(shareTextProvider)(inviteShareMessage(widget.invitation));
    } catch (_) {
      // 공유 창을 못 열면 복사로 안내한다
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유 창을 열지 못했어요. 코드를 복사해서 보내 주세요.')),
      );
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.invitation.inviteCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('코드를 복사했어요.')));
  }

  @override
  Widget build(BuildContext context) {
    final invitation = widget.invitation;
    final code = invitation.inviteCode;
    final remaining = invitation.expiresAt.difference(DateTime.now());
    final expired = !widget.trusted && remaining <= Duration.zero;

    final cells = Semantics(
      label: '초대 코드 ${code.split('').join(' ')}',
      excludeSemantics: true,
      child: CodeCells(code: code, length: code.length, dimmed: expired),
    );

    if (expired) {
      return StepLayout(
        actions: [
          FilledButton(onPressed: widget.onRenew, child: const Text('새 코드 받기')),
        ],
        children: [
          const PageTitle(title: '코드가 만료됐어요', subtitle: '새 코드를 만들어 다시 알려 주세요'),
          const SizedBox(height: 16),
          cells,
          const SizedBox(height: 16),
          const ErrorText('코드가 만료됐어요'),
        ],
      );
    }

    return StepLayout(
      actions: [
        FilledButton(onPressed: _copy, child: const Text('코드 복사하기')),
        OutlinedButton(onPressed: _share, child: const Text('공유하기')),
      ],
      children: [
        const PageTitle(title: '초대 코드가 만들어졌어요', subtitle: '부모님께 이 코드를 알려 주세요'),
        const SizedBox(height: 16),
        cells,
        const SizedBox(height: 16),
        Text(
          widget.trusted
              ? '${formatExpiry(invitation.expiresAt)}까지 쓸 수 있어요'
              : remainingText(remaining, invitation.expiresAt),
          style: AppText.bodyS,
        ),
        const SizedBox(height: 16),
        const Text('부모님이 코드를 입력하면 자동으로 연결돼요', style: AppText.bodyS),
      ],
    );
  }
}

/// 초대 코드가 만료되기까지 남은 시간 안내.
///
/// 1시간 안이면 분·초, 하루 안이면 시간·분, 그보다 길면 만료 시각을 보여준다.
String remainingText(Duration remaining, DateTime expiresAt) {
  if (remaining >= const Duration(days: 1)) {
    return '${formatExpiry(expiresAt)}까지 쓸 수 있어요';
  }
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes % 60;
  if (hours > 0) return '$hours시간 $minutes분 뒤에 코드가 만료돼요';
  final seconds = remaining.inSeconds % 60;
  return '$minutes분 $seconds초 뒤에 코드가 만료돼요';
}

/// Figma WF-004 초대 코드 입력 / 잘못된 코드 (부모)
class _ParentJoinView extends ConsumerStatefulWidget {
  const _ParentJoinView();

  @override
  ConsumerState<_ParentJoinView> createState() => _ParentJoinViewState();
}

class _ParentJoinViewState extends ConsumerState<_ParentJoinView> {
  static const codeLength = 6;
  final _code = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _code.addListener(_onChanged);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _code.removeListener(_onChanged);
    _focus.removeListener(_onFocusChanged);
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    ref.read(joinControllerProvider.notifier).clearError();
    setState(() {}); // 칸과 버튼 상태 갱신
  }

  void _onFocusChanged() => setState(() {});

  void _submit() {
    if (_code.text.length != codeLength) return;
    FocusScope.of(context).unfocus();
    ref.read(joinControllerProvider.notifier).join(_code.text);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(joinControllerProvider, (_, next) {
      final e = next.error;
      if (next.value == true) {
        ref.read(justPairedProvider.notifier).mark();
      } else if (e != null) {
        handleSessionExpired(context, ref, e);
      }
    });

    final state = ref.watch(joinControllerProvider);
    final code = _code.text;
    final canSubmit = code.length == codeLength && !state.isLoading;
    final error = state.error;

    return StepLayout(
      actions: [
        FilledButton(
          onPressed: canSubmit ? _submit : null,
          child: state.isLoading
              ? const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.textOnPrimary,
                  ),
                )
              : const Text('연결하기'),
        ),
      ],
      children: [
        const PageTitle(title: '초대 코드를 입력해 주세요', subtitle: '자녀가 알려 준 6자리 숫자예요'),
        const SizedBox(height: 16),
        // 칸은 보여주기만 하고, 위에 겹친 투명한 입력칸이 숫자를 받는다.
        Stack(
          children: [
            CodeCells(
              code: code,
              length: codeLength,
              focusedIndex: _focus.hasFocus && code.length < codeLength
                  ? code.length
                  : null,
              error: error != null,
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                // 투명해도 화면 읽기 프로그램은 입력칸을 찾을 수 있어야 한다
                alwaysIncludeSemantics: true,
                child: TextField(
                  key: const Key('inviteCodeField'),
                  controller: _code,
                  focusNode: _focus,
                  enabled: !state.isLoading,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: codeLength,
                  showCursor: false, // 길게 눌러 붙여넣기는 그대로 둔다(공유받은 코드)
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  style: AppText.caption,
                  decoration: const InputDecoration(
                    hintText: '초대 코드 6자리',
                    counterText: '',
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (error != null)
          ErrorText(pairingErrorMessage(error))
        else
          const Text('숫자만 입력할 수 있어요', style: AppText.bodyS),
      ],
    );
  }
}

/// Figma WF-005 연결 완료: 연결을 축하하고 홈으로 안내한다.
class _PairedView extends ConsumerWidget {
  const _PairedView({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = role == UserRole.child ? '부모님과' : '자녀와';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              AppIcons.smileWink,
              size: 72,
              color: AppColors.textBrand,
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                '$partner 연결됐어요',
                textAlign: TextAlign.center,
                style: AppText.headingM,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '이제 하루 한 질문으로\n이야기를 나눠요',
              textAlign: TextAlign.center,
              style: AppText.bodyM.copyWith(color: AppColors.textSub),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                context.go('/today');
                // 저장소에는 연결됨으로 바뀌었으니 마이페이지 등이 새 정보를 읽게 한다.
                // 이동 뒤에 비워야 이 화면이 로딩으로 바뀌며 깜빡이지 않는다.
                ref.invalidate(currentUserProvider);
              },
              child: const Text('홈으로 가기'),
            ),
          ],
        ),
      ),
    );
  }
}
