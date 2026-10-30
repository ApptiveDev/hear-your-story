import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../onboarding/data/auth_providers.dart';
import '../../onboarding/domain/app_user.dart';
import '../../onboarding/presentation/session.dart';
import '../../onboarding/presentation/widgets/step_header.dart';
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

  /// 만료돼서 새로 받은 숫자. 기기 시각이 틀려도 같은 숫자로 계속 다시 받지 않는다.
  String? _expiredCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(pollInterval, (_) => _onTick());
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
    if (state == AppLifecycleState.resumed) _onTick();
  }

  void _onTick() {
    _refreshIfExpired();
    _checkPaired();
  }

  /// 유효 시간이 지난 숫자를 보여주고 있으면 새 숫자를 받는다.
  /// 서버는 만료된 초대 대신 새 초대를 만들어 준다.
  void _refreshIfExpired() {
    final invitation = ref.read(invitationProvider).value;
    if (invitation == null ||
        invitation.inviteCode == _expiredCode ||
        DateTime.now().isBefore(invitation.expiresAt)) {
      return;
    }
    _expiredCode = invitation.inviteCode;
    ref.invalidate(invitationProvider);
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

  @override
  Widget build(BuildContext context) {
    ref.listen(invitationProvider, (_, next) {
      final code = next.value?.inviteCode;
      if (_expiredCode != null && code != null && code != _expiredCode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('시간이 지나 새 숫자로 바뀌었어요.\n부모님께 새 숫자를 알려 주세요.'),
          ),
        );
        _expiredCode = null;
      }
      final e = next.error;
      if (e == null) return;
      if (isAlreadyPaired(e)) {
        context.go('/today');
      } else {
        handleSessionExpired(context, ref, e);
      }
    });

    final invitation = ref.watch(invitationProvider);
    return invitation.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetryView(
        message: '초대 숫자를 만들지 못했어요.',
        onRetry: () => ref.invalidate(invitationProvider),
      ),
      data: (invitation) => _InviteContent(invitation: invitation),
    );
  }
}

class _InviteContent extends ConsumerWidget {
  const _InviteContent({required this.invitation});
  final Invitation invitation;

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(shareTextProvider)(inviteShareMessage(invitation));
    } catch (_) {
      // 공유 창을 못 열면 복사로 안내한다
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보내기를 열지 못했어요. 숫자를 복사해서 보내 주세요.')),
      );
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: invitation.inviteCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('숫자를 복사했어요.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final code = invitation.inviteCode;
    final spaced = code.length == 6
        ? '${code.substring(0, 3)} ${code.substring(3)}'
        : code;

    return ListView(
      padding: _sidePadding,
      children: [
        const StepHeader(step: 3),
        const SizedBox(height: 64),
        Text(
          '부모님을\n초대해 주세요',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '아래 숫자를\n부모님께 전달해 주세요',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 40),
        Center(
          child: Semantics(
            label: '초대 숫자 ${code.split('').join(' ')}',
            excludeSemantics: true,
            child: Container(
              width: 240,
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.button),
                boxShadow: AppShadows.numberBox,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(spaced, style: AppText.number),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${formatExpiry(invitation.expiresAt)}까지 쓸 수 있어요.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 40),
        FilledButton.icon(
          onPressed: () => _share(context, ref),
          icon: const Icon(Icons.send),
          label: const Text('부모님께 보내기'),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _copy(context),
          icon: const Icon(Icons.copy),
          label: const Text('숫자 복사하기'),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text('연결되면 자동으로 넘어가요.', style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// 좌우 여백. 버튼(331)이 393 화면 가운데 오도록 한다.
const _sidePadding = EdgeInsets.symmetric(horizontal: 31);

class _ParentJoinView extends ConsumerStatefulWidget {
  const _ParentJoinView();

  @override
  ConsumerState<_ParentJoinView> createState() => _ParentJoinViewState();
}

class _ParentJoinViewState extends ConsumerState<_ParentJoinView> {
  static const codeLength = 6;
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _code.addListener(_onChanged);
  }

  @override
  void dispose() {
    _code.removeListener(_onChanged);
    _code.dispose();
    super.dispose();
  }

  void _onChanged() {
    ref.read(joinControllerProvider.notifier).clearError();
    setState(() {}); // 버튼 활성 상태 갱신
  }

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
    final theme = Theme.of(context);
    final canSubmit = _code.text.length == codeLength && !state.isLoading;

    return ListView(
      padding: _sidePadding.add(const EdgeInsets.only(bottom: 24)),
      children: [
        const StepHeader(step: 3),
        const SizedBox(height: 64),
        Text(
          '자녀와 연결해요',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '자녀에게 받은\n숫자 6자리를 입력해 주세요',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 40),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            boxShadow: AppShadows.numberBox,
          ),
          child: TextField(
            controller: _code,
            enabled: !state.isLoading,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: codeLength,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: AppText.number.copyWith(fontSize: 44, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: '000000',
              hintStyle: AppText.number.copyWith(
                fontSize: 44,
                letterSpacing: 8,
                color: AppColors.disabled,
              ),
              counterText: '',
            ),
          ),
        ),
        if (state.hasError) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pairingErrorMessage(state.error!),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: canSubmit ? _submit : null,
          child: state.isLoading
              ? const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.bg,
                  ),
                )
              : const Text('연결하기'),
        ),
      ],
    );
  }
}

/// Figma "페어링 완료": 연결을 축하하고 첫 질문으로 안내한다.
class _PairedView extends StatelessWidget {
  const _PairedView({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final partner = role == UserRole.child ? '부모님과' : '자녀와';
    return ListView(
      padding: _sidePadding.add(const EdgeInsets.only(bottom: 24)),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.base, width: 3),
            ),
            child: const ExcludeSemantics(
              child: Text('💞', style: TextStyle(fontSize: 56)),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Semantics(
          liveRegion: true,
          child: Text(
            '연결 되었어요!',
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '이제 $partner\n매일 서로의 이야기를 들어보아요',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: 48),
        FilledButton(
          onPressed: () => context.go('/today'),
          child: const Text('시작하기'),
        ),
      ],
    );
  }
}
