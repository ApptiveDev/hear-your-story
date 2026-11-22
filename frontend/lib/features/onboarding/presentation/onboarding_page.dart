import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_text.dart';
import '../../../core/widgets/page_title.dart';
import '../../../core/widgets/step_layout.dart';
import '../domain/app_user.dart';
import '../data/kakao_sign_in.dart';
import 'kakao_login_controller.dart';
import 'session.dart';
import 'sign_up_controller.dart';

/// 역할 선택 → 이름 입력 → 가입. 한 화면에 주요 행동 하나만 둔다.
///
/// 카카오 로그인을 켜면 맨 앞에 카카오 로그인을 둔다. 기존 계정이면 바로 홈이나
/// 페어링으로 가고, 처음이면 역할·이름을 받아 가입을 마친다.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  /// Figma WF-002 기준 10자. 서버(CreateUserRequest)는 50자까지 받는다.
  static const nameMaxLength = 10;
  static const nameRule = '이름은 1자 이상 $nameMaxLength자 이하로 입력해 주세요';

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _nameController = TextEditingController();
  UserRole? _role;

  /// 이름 입력에서 `이전`으로 돌아왔을 때 다시 골라 둘 역할
  UserRole? _lastRole;
  bool _recoveringRegistrationConflict = false;

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

  Future<void> _recoverRegisteredAccount() async {
    if (_recoveringRegistrationConflict) return;
    _recoveringRegistrationConflict = true;
    await ref.read(sessionExpiryProvider).clearLocal();
    if (!mounted) return;

    setState(() {
      _role = null;
      _lastRole = null;
      _nameController.clear();
      _recoveringRegistrationConflict = false;
    });
    ref.invalidate(signUpControllerProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('가입은 완료됐어요.\n같은 카카오 계정으로 다시 로그인해 주세요.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(signUpControllerProvider, (_, next) {
      final error = next.error;
      if (error is ApiException &&
          error.errorCode == 'KAKAO_ACCOUNT_ALREADY_REGISTERED') {
        unawaited(_recoverRegisteredAccount());
        return;
      }
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
    // 카카오 로그인 결과: 기존 계정이면 바로 들어가고, 처음이면 역할 선택으로 넘어간다
    ref.listen(kakaoLoginControllerProvider, (_, next) {
      final user = next.result?.user;
      if (user != null) context.go(user.isPaired ? '/today' : '/pairing');
    });

    final launch = ref.watch(launchDestinationProvider);
    final needsLogin = ref.watch(needsKakaoLoginProvider);
    final kakao = ref.watch(kakaoLoginControllerProvider);
    if (launch.isLoading ||
        launch.value != null ||
        needsLogin.isLoading ||
        kakao.result?.user != null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // 로그인 결과(NEW)를 받았으면 저장된 토큰을 다시 읽지 않고 역할 선택으로 간다
    if (needsLogin.value == true) {
      if (kakao.result == null) {
        return const Scaffold(body: SafeArea(child: _KakaoLoginStep()));
      }
    }

    final role = _role;
    final loading = ref.watch(signUpControllerProvider).isLoading;
    return Scaffold(
      body: SafeArea(
        child: role == null
            ? _RoleStep(
                initial: _lastRole,
                onNext: (r) => setState(() => _role = _lastRole = r),
              )
            : _NameStep(
                role: role,
                controller: _nameController,
                maxLength: OnboardingPage.nameMaxLength,
                onSubmit: _submit,
                onBack: loading ? null : () => setState(() => _role = null),
              ),
      ),
    );
  }
}

/// 좌우 여백. Figma 393 프레임의 좌우 24.
const _sidePadding = EdgeInsets.symmetric(horizontal: AppSizes.screenPadding);

/// Figma `LOGIN · 카카오 로그인`: 가운데 로고·앱 이름, 아래쪽 카카오 버튼과 약관 안내.
///
/// 화면이 남으면 로고를 가운데에 두고, 글씨를 키워 넘치면 스크롤한다.
class _KakaoLoginStep extends ConsumerWidget {
  const _KakaoLoginStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(kakaoLoginControllerProvider);
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: _sidePadding.add(
              const EdgeInsets.only(top: 24, bottom: 32),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(child: Center(child: _LoginHero())),
                const SizedBox(height: 40),
                if (state.error != null) ...[
                  _ErrorMessage(error: state.error!, login: true),
                  const SizedBox(height: 16),
                ],
                _KakaoLoginButton(
                  busy: state.busy,
                  onPressed: () =>
                      ref.read(kakaoLoginControllerProvider.notifier).login(),
                ),
                _PhaseText(phase: state.phase),
                const SizedBox(height: 16),
                const _TermsNotice(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Figma `Brand/Hero`: 하트 로고(임시), 앱 이름, 한 줄 소개.
class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 132,
            height: 132,
            decoration: const BoxDecoration(
              color: AppColors.surfaceCard,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              AppIcons.heart,
              size: 72,
              color: AppColors.textBrand,
            ),
          ),
        ),
        const SizedBox(height: 40),
        Semantics(
          header: true,
          child: const Text(
            '들려줘요',
            textAlign: TextAlign.center,
            style: AppText.headingXXL,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          keepWords('하루 한 질문으로 이어지는\n우리 가족 이야기'),
          textAlign: TextAlign.center,
          style: AppText.headingM.copyWith(color: AppColors.textSub),
        ),
      ],
    );
  }
}

/// Figma `Button/ 카카오 로그인`. 카카오 디자인 가이드대로 노란 바탕에 말풍선과
/// `카카오 로그인`을 쓴다. 앱 공통 버튼의 입체 효과는 넣지 않는다.
class _KakaoLoginButton extends StatelessWidget {
  const _KakaoLoginButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: busy ? null : onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.buttonL),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        backgroundColor: AppColors.kakaoBg,
        foregroundColor: AppColors.kakaoText,
        // 로그인 중에도 카카오 버튼 색을 유지한다
        disabledBackgroundColor: AppColors.kakaoBg,
        disabledForegroundColor: AppColors.kakaoText,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.buttonL),
        ),
        textStyle: AppText.buttonM,
      ),
      child: busy
          ? const _ButtonSpinner(color: AppColors.kakaoText)
          : const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _KakaoSymbol(),
                SizedBox(width: 10),
                Flexible(child: Text('카카오 로그인', textAlign: TextAlign.center)),
              ],
            ),
    );
  }
}

/// 카카오 말풍선 심볼 (Figma `카카오 로고`, 18x18).
class _KakaoSymbol extends StatelessWidget {
  const _KakaoSymbol();

  static const size = 18.0;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      // 글씨를 키우면 말풍선도 글자와 같은 비율로 키운다
      size: Size.square(MediaQuery.textScalerOf(context).scale(size)),
      painter: const _KakaoSymbolPainter(),
    ),
  );
}

class _KakaoSymbolPainter extends CustomPainter {
  const _KakaoSymbolPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Figma SVG 경로(18x18)를 그대로 옮겼다
    canvas.scale(size.width / _KakaoSymbol.size);
    final path = Path()
      ..moveTo(9, 0.6)
      ..cubicTo(4.029, 0.6, 0, 3.713, 0, 7.552)
      ..cubicTo(0, 9.94, 1.558, 12.045, 3.932, 13.297)
      ..lineTo(2.933, 16.945)
      ..cubicTo(2.845, 17.267, 3.213, 17.524, 3.496, 17.337)
      ..lineTo(7.873, 14.448)
      ..cubicTo(8.243, 14.484, 8.618, 14.505, 9, 14.505)
      ..cubicTo(13.971, 14.505, 18, 11.392, 18, 7.552)
      ..cubicTo(18, 3.713, 13.971, 0.6, 9, 0.6)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF000000));
  }

  @override
  bool shouldRepaint(_KakaoSymbolPainter oldDelegate) => false;
}

/// 줄을 바꿀 때 한국어 낱말 가운데가 끊기지 않게 글자 사이를 잇는다.
///
/// Flutter는 한글 글자마다 줄을 바꿀 수 있어서, 글씨를 키우면 `이어지는`이
/// `이 / 어지는`처럼 갈라진다. 띄어쓰기에서만 줄이 바뀌게 한다.
String keepWords(String text) =>
    text.split(' ').map((word) => word.split('').join(_join)).join(' ');

/// 보이지 않는 이음표(WORD JOINER). 이 자리에서는 줄을 바꾸지 않는다.
const _join = '\u2060';

/// 시작하면 약관에 동의한 것으로 본다는 안내. 약관 이름을 누르면 전문을 연다.
class _TermsNotice extends StatefulWidget {
  const _TermsNotice();

  @override
  State<_TermsNotice> createState() => _TermsNoticeState();
}

class _TermsNoticeState extends State<_TermsNotice> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => context.push('/my/terms');
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => context.push('/my/privacy');

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(decoration: TextDecoration.underline);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: keepWords('시작하면 ')),
          TextSpan(text: keepWords('이용약관'), style: link, recognizer: _terms),
          // 앞 낱말에 붙는 조사도 줄이 바뀌어 떨어지지 않게 잇는다
          TextSpan(text: '$_join${keepWords('과 ')}'),
          TextSpan(
            text: keepWords('개인정보 처리방침'),
            style: link,
            recognizer: _privacy,
          ),
          TextSpan(text: '$_join${keepWords('에\n동의한 것으로 봐요')}'),
        ],
      ),
      textAlign: TextAlign.center,
      style: AppText.bodyS.copyWith(height: 1.4),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner({this.color = AppColors.textOnPrimary});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 28,
    child: CircularProgressIndicator(strokeWidth: 3, color: color),
  );
}

/// 로그인이 오래 걸릴 때 지금 무엇을 하는지 알려준다.
class _PhaseText extends StatelessWidget {
  const _PhaseText({required this.phase});
  final LoginPhase phase;

  @override
  Widget build(BuildContext context) {
    final text = switch (phase) {
      LoginPhase.idle => null,
      LoginPhase.verifying => '카카오에서 확인하고 있어요',
      LoginPhase.restoring => '이전 기록을 찾고 있어요',
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Figma WF-001 역할 선택. 카드를 고른 뒤 `다음`을 눌러 넘어간다.
class _RoleStep extends StatefulWidget {
  const _RoleStep({required this.initial, required this.onNext});

  /// 이름 입력에서 돌아왔을 때 전에 고른 역할
  final UserRole? initial;
  final ValueChanged<UserRole> onNext;

  @override
  State<_RoleStep> createState() => _RoleStepState();
}

class _RoleStepState extends State<_RoleStep> {
  late UserRole? _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return StepLayout(
      showTextScale: false,
      actions: [
        FilledButton(
          onPressed: selected == null ? null : () => widget.onNext(selected),
          child: const Text('다음'),
        ),
      ],
      children: [
        const PageTitle(title: '누구로 시작할까요?', subtitle: '내 역할을 골라 주세요'),
        const SizedBox(height: 16),
        _RoleCard(
          icon: AppIcons.heart,
          label: '부모',
          description: '목소리로 질문에 답해요',
          selected: selected == UserRole.parent,
          onTap: () => setState(() => _selected = UserRole.parent),
        ),
        const SizedBox(height: 16),
        _RoleCard(
          icon: AppIcons.childHead,
          label: '자녀',
          description: '글로 질문에 답해요',
          selected: selected == UserRole.child,
          onTap: () => setState(() => _selected = UserRole.child),
        ),
        const SizedBox(height: 16),
        // 목소리를 남기기 전에 누가 듣는지 먼저 알린다 (경쟁 서비스 분석 인사이트 10)
        const Text(privacyNote, style: AppText.bodyS),
      ],
    );
  }
}

/// 가족끼리만 공유된다는 안내. 서버는 연결된 두 사람에게만 답과 음성 링크를 준다.
const privacyNote = '이름과 녹음은 연결된 가족에게만 보여요.';

/// Figma `Card/Role`: 아이콘, 역할 이름과 설명, 오른쪽 선택 표시.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $description',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.surfaceCard : AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.cardSmall),
          side: BorderSide(
            color: selected ? AppColors.borderPrimary : AppColors.borderSoft,
            width: selected ? 3 : 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 110),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.bgUnder,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 40, color: AppColors.textBrand),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: AppText.headingM),
                        const SizedBox(height: 4),
                        Text(description, style: AppText.bodyS),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _CheckMark(selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 역할 카드 오른쪽 동그라미. 고르면 주황 바탕에 체크가 들어간다.
class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.actionPrimary : AppColors.surfaceWhite,
        border: selected
            ? null
            : Border.all(color: AppColors.borderSoft, width: 2),
      ),
      child: selected
          ? const Icon(AppIcons.check, size: 14, color: AppColors.textOnPrimary)
          : null,
    );
  }
}

/// Figma WF-002 이름 입력.
class _NameStep extends ConsumerStatefulWidget {
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
  ConsumerState<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends ConsumerState<_NameStep> {
  /// 한 번이라도 글자를 넣었는지. 처음 열었을 때는 빈 칸이어도 오류로 보이지 않는다.
  late bool _edited = widget.controller.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signUpControllerProvider);
    final controller = widget.controller;
    final isParent = widget.role == UserRole.parent;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final text = controller.text;
        if (text.isNotEmpty) _edited = true;
        final empty = text.trim().isEmpty;
        final canSubmit = !empty && !state.isLoading;
        final serverError = state.error;

        return StepLayout(
          showTextScale: false,
          onBack: widget.onBack,
          actions: [
            FilledButton(
              onPressed: canSubmit ? widget.onSubmit : null,
              child: state.isLoading
                  ? const _ButtonSpinner()
                  : const Text('시작하기'),
            ),
          ],
          children: [
            const PageTitle(title: '이름을 알려 주세요', subtitle: '가족에게 보여질 이름이에요'),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: _RoleChip(
                icon: isParent ? AppIcons.heart : AppIcons.childHead,
                label: isParent ? '부모로 시작해요' : '자녀로 시작해요',
              ),
            ),
            const SizedBox(height: 16),
            const Text('이름', style: AppText.labelM),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              enabled: !state.isLoading,
              autofocus: true,
              maxLength: widget.maxLength,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (canSubmit) widget.onSubmit();
              },
              style: AppText.bodyL.copyWith(color: AppColors.textStrong),
              decoration: InputDecoration(
                hintText: '이름을 입력해 주세요',
                counterText: '',
                suffix: Text(
                  '${text.characters.length} / ${widget.maxLength}',
                  style: AppText.bodyS,
                ),
                error: _edited && empty
                    ? const ErrorText(OnboardingPage.nameRule)
                    : null,
              ),
            ),
            if (serverError != null) ...[
              const SizedBox(height: 16),
              _ErrorMessage(error: serverError),
            ],
          ],
        );
      },
    );
  }
}

/// Figma `Chip/Role`: 이름 입력에서 고른 역할을 보여준다.
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: AppColors.textBrand),
            const SizedBox(width: 8),
            Flexible(child: Text(label, style: AppText.labelM)),
          ],
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.error, this.login = false});
  final Object error;

  /// 카카오 로그인 오류. 서버가 본인 확인을 거절한 것(4xx)도 로그인 실패로 안내한다.
  final bool login;

  String get _message {
    final e = error;
    const loginFailed = '카카오 로그인에 실패했어요. 다시 시도해 주세요.';
    if (e is KakaoSignInFailed) return loginFailed;
    if (e is ApiException) {
      final status = e.statusCode;
      if (login && status != null && status < 500 && status != 429) {
        return loginFailed;
      }
      if (e.statusCode == 400) return '이름을 다시 확인해 주세요.';
      return e.userMessage;
    }
    return '문제가 생겼어요. 다시 시도해 주세요.';
  }

  @override
  Widget build(BuildContext context) => ErrorText(_message);
}
