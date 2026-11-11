import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/app_user.dart';
import 'session.dart';
import 'sign_up_controller.dart';
import 'widgets/step_header.dart';

/// 역할 선택 → 이름 입력 → 가입. 한 화면에 주요 행동 하나만 둔다.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const nameMaxLength = 50; // 서버 CreateUserRequest와 동일

  final _nameController = TextEditingController();
  UserRole? _role;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final role = _role;
    final name = _nameController.text.trim();
    if (role == null || name.isEmpty) return;
    ref.read(signUpControllerProvider.notifier).submit(name: name, role: role);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(signUpControllerProvider, (_, next) {
      final user = next.value;
      if (user != null && !next.isLoading) {
        context.go(user.isPaired ? '/today' : '/pairing');
      }
    });

    // 이미 가입한 기기면 앱을 켤 때 바로 홈이나 페어링으로 보낸다
    ref.listen(launchDestinationProvider, (_, next) {
      // 다시 계산하는 중에는 이전 값이 실려 오므로 계산이 끝난 값에만 반응한다
      if (next.isLoading) return;
      // 서버가 로그인이 끝났다고(401) 하면 정보를 지우고 가입부터 하게 한다
      final error = next.error;
      if (error != null) {
        handleSessionExpired(context, ref, error);
        return;
      }
      final destination = next.value;
      if (destination != null) context.go(destination);
    });
    final launch = ref.watch(launchDestinationProvider);
    if (launch.isLoading || launch.value != null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final role = _role;
    final loading = ref.watch(signUpControllerProvider).isLoading;
    return Scaffold(
      body: SafeArea(
        child: role == null
            ? _RoleStep(onSelected: (r) => setState(() => _role = r))
            : _NameStep(
                role: role,
                controller: _nameController,
                maxLength: nameMaxLength,
                onSubmit: _submit,
                onBack: loading ? null : () => setState(() => _role = null),
              ),
      ),
    );
  }
}

/// 좌우 여백. 버튼(331)이 393 화면 가운데 오도록 한다.
const _sidePadding = EdgeInsets.symmetric(horizontal: 31);

class _RoleStep extends StatelessWidget {
  const _RoleStep({required this.onSelected});
  final ValueChanged<UserRole> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      // 제목(Figma 341px)이 한 줄에 들어가도록 좌우 16. 카드는 329로 가운데.
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const StepHeader(step: 1),
        const SizedBox(height: 56),
        const ExcludeSemantics(
          child: Text('🕊️', textAlign: TextAlign.center, style: _emoji),
        ),
        const SizedBox(height: 16),
        Text(
          '누구로 시작할까요?',
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '질문에 답해주실 분을\n선택해주세요',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: 56),
        _RoleCard(
          emoji: '👵',
          label: '부모님이에요',
          description: '질문에 목소리로 답해요',
          onTap: () => onSelected(UserRole.parent),
        ),
        const SizedBox(height: 16),
        _RoleCard(
          emoji: '🙋',
          label: '자녀예요',
          description: '부모님을 초대하고 글로 답해요',
          onTap: () => onSelected(UserRole.child),
        ),
        const SizedBox(height: 32),
        // 목소리를 남기기 전에 누가 듣는지 먼저 알린다 (경쟁 서비스 분석 인사이트 10)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline, size: 24),
                const SizedBox(width: 8),
                Expanded(child: Text(privacyNote, style: textTheme.bodyMedium)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

const _emoji = TextStyle(fontSize: 48, height: 1.2);

/// 가족끼리만 공유된다는 안내. 서버는 연결된 두 사람에게만 답과 음성 링크를 준다.
const privacyNote = '주고받은 목소리와 글은\n연결된 두 분만 듣고 볼 수 있어요.';

/// Figma 역할 카드: 329 너비, 안쪽 여백 40/70, 간격 12, 모서리 15.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.emoji,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final String emoji;
  final String label;

  /// 화면에는 없고 화면 읽기 프로그램에만 알려준다.
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 329),
        // 좁은 화면에서는 화면 폭, 넓은 화면에서는 329
        child: SizedBox(width: double.infinity, child: _card(context)),
      ),
    );
  }

  Widget _card(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $description',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: AppShadows.roleCard,
        ),
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.button),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: _emoji),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NameStep extends ConsumerWidget {
  const _NameStep({
    required this.role,
    required this.controller,
    required this.maxLength,
    required this.onSubmit,
    required this.onBack,
  });

  final UserRole role;
  final TextEditingController controller;
  final int maxLength;
  final VoidCallback onSubmit;

  /// 가입 요청 중에는 null(되돌아가지 못함)
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signUpControllerProvider);
    final textTheme = Theme.of(context).textTheme;
    final isParent = role == UserRole.parent;

    return ListView(
      padding: _sidePadding.add(const EdgeInsets.only(bottom: 24)),
      children: [
        StepHeader(step: 2, onBack: onBack ?? () {}),
        const SizedBox(height: 72),
        Text(
          isParent ? '성함을 알려주세요' : '이름을 알려주세요',
          style: textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          isParent ? '자녀에게 보여질 이름이에요' : '부모님께 보여질 이름이에요',
          style: AppText.label,
        ),
        const SizedBox(height: 48),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            boxShadow: AppShadows.field,
          ),
          child: TextField(
            controller: controller,
            enabled: !state.isLoading,
            autofocus: true,
            maxLength: maxLength,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            style: AppText.subTitle,
            decoration: InputDecoration(
              hintText: isParent ? '예: 김영희' : '예: 김민지',
              counterText: '',
            ),
          ),
        ),
        if (state.hasError) ...[
          const SizedBox(height: 16),
          _ErrorMessage(error: state.error!),
        ],
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final canSubmit =
                controller.text.trim().isNotEmpty && !state.isLoading;
            return FilledButton(
              onPressed: canSubmit ? onSubmit : null,
              child: state.isLoading
                  ? const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.bg,
                      ),
                    )
                  : const Text('시작하기'),
            );
          },
        ),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.error});
  final Object error;

  String get _message {
    final e = error;
    if (e is ApiException) {
      if (e.statusCode == 400) return '이름을 다시 확인해 주세요.';
      return e.userMessage;
    }
    return '문제가 생겼어요. 다시 시도해 주세요.';
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: color, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _message,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
