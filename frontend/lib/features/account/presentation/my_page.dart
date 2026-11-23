import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_tab_shell.dart';
import '../../../core/widgets/choice_dialog.dart';
import '../../onboarding/data/auth_providers.dart';
import '../../onboarding/domain/app_user.dart';
import '../../onboarding/presentation/session.dart';
import '../data/account_providers.dart';

const kakaoLogoutConfirmMessage = '같은 카카오 계정으로 다시 로그인하면\n이야기가 그대로 이어져요.';
const deleteConfirmMessage =
    '내가 남긴 목소리·글·사진을 모두 지우고 연결도 끊어요.\n'
    '상대방이 남긴 답은 그대로 남아요.\n'
    '탈퇴는 되돌릴 수 없어요.';
const uiconsAttribution = 'Uicons by Flaticon';

/// 내 정보와 로그아웃·탈퇴·안내 항목을 모아 둔 화면
class MyPage extends ConsumerStatefulWidget {
  const MyPage({super.key});

  static const title = '마이';

  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  bool _busy = false;

  /// Figma `Dialog/Confirm`: 위에 실행 버튼, 아래에 취소
  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final ok = await showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: action,
    );
    return ok && mounted;
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await _confirm(
      title: '로그아웃할까요?',
      message: kakaoLogoutConfirmMessage,
      action: '로그아웃',
    )) {
      return;
    }
    if (!mounted) return;
    try {
      // 카카오 로그아웃까지 포함한 기존 로그아웃을 그대로 쓴다
      await signOut(context);
    } on Object {
      // 저장소 오류 등으로 정리하지 못하면 이 화면에 남아 다시 시도하게 한다
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('로그아웃하지 못했어요. 다시 시도해 주세요.')),
        );
    }
  }

  Future<void> _deleteAccount() async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!await _confirm(
      title: '정말 탈퇴할까요?',
      message: deleteConfirmMessage,
      action: '탈퇴하기',
    )) {
      return;
    }
    // 요청 중 화면이 사라져도(예: 401로 가입 화면 이동) 끝까지 처리하도록
    // await 전에 필요한 객체를 미리 잡아 둔다. dispose된 뒤에는 ref를 쓸 수 없다.
    final repository = ref.read(accountRepositoryProvider);
    final auth = ref.read(authRepositoryProvider);
    final session = ref.read(sessionExpiryProvider);
    setState(() => _busy = true);
    try {
      await repository.deleteAccount();
    } on ApiException catch (e) {
      // 이미 탈퇴를 처리하는 중이면 서버가 지우고 있으니 같은 결과로 본다
      if (e.errorCode != 'ACCOUNT_DELETION_IN_PROGRESS') {
        await _showDeleteFailure(messenger, e);
        return;
      }
    } on Object {
      await _showDeleteFailure(messenger, null);
      return;
    }
    // 서버가 탈퇴를 받았다. 기기 정리가 실패해도 완료로 보고 다음 요청의 401에 맡긴다.
    try {
      await auth.logout(); // 토큰(access·refresh)·사용자 정보·카카오 로그인을 지운다
      await session.clearLocal(); // 화면이 쓰던 로그인 상태도 비운다
    } on Object {
      // 아래에서 완료 화면으로 보낸다
    }
    router.go('/account-deleted');
  }

  Future<void> _showDeleteFailure(
    ScaffoldMessengerState messenger,
    ApiException? error,
  ) async {
    if (!mounted) return;
    setState(() => _busy = false); // 다시 눌러 볼 수 있게 푼다
    if (error != null && await handleSessionExpired(context, ref, error)) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(error?.userMessage ?? '문제가 생겼어요. 다시 시도해 주세요.')),
      );
  }

  void _showInfo(String title, String value) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SelectableText(value.isEmpty ? '준비 중이에요.' : value),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    return PopScope(
      canPop: !_busy, // 탈퇴를 요청하는 동안은 뒤로 가지 못하게 한다
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: AbsorbPointer(
            absorbing: _busy, // 탈퇴를 요청하는 동안 다른 항목을 누르지 못하게 한다
            child: ListView(
              padding: tabPagePadding(context),
              children: [
                Semantics(
                  header: true,
                  child: const Text(MyPage.title, style: AppText.headingXL),
                ),
                const SizedBox(height: 16),
                if (user != null) ...[
                  _ProfileCard(user: user),
                  const SizedBox(height: 16),
                ],
                _MenuGroup(
                  children: [
                    _MenuRow(
                      icon: AppIcons.addressBook,
                      label: '개인정보 처리방침',
                      onTap: () => context.push('/my/privacy'),
                    ),
                    _MenuRow(
                      icon: AppIcons.bookAlt,
                      label: '이용약관',
                      onTap: () => context.push('/my/terms'),
                    ),
                    _MenuRow(
                      icon: AppIcons.headset,
                      label: '문의하기',
                      onTap: () => _showInfo('문의하기', AppConfig.supportContact),
                    ),
                    const _MenuRow(
                      icon: AppIcons.asterisk,
                      label: '앱 버전',
                      value: AppConfig.appVersion,
                    ),
                    // Flaticon 무료 라이선스 조건: 앱 안에 출처 표기 (assets/fonts/README.md)
                    const _MenuRow(
                      icon: AppIcons.palette,
                      label: '아이콘 출처',
                      value: uiconsAttribution,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _MenuGroup(
                  children: [
                    _MenuRow(
                      icon: AppIcons.undo,
                      label: '로그아웃',
                      onTap: _signOut,
                    ),
                    if (AppConfig.accountDeletionApi)
                      _MenuRow(
                        icon: AppIcons.signOut,
                        label: '탈퇴하기',
                        bold: true,
                        busy: _busy,
                        onTap: _deleteAccount,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma `Card/Profile`: 아이콘, 이름, 역할과 연결 상태
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final isParent = user.role == UserRole.parent;
    final partner = isParent ? '자녀와' : '부모님과';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceWhite,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isParent ? AppIcons.heart : AppIcons.childHead,
                  size: 40,
                  color: AppColors.textBrand,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: AppText.headingL),
                    const SizedBox(height: 2),
                    Text(
                      isParent ? '부모' : '자녀',
                      style: AppText.labelL.copyWith(color: AppColors.textSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '연결 상태',
            style: AppText.labelM.copyWith(color: AppColors.textBrand),
          ),
          const SizedBox(height: 4),
          Text(
            user.isPaired ? '$partner 연결되어 있어요' : '아직 연결되지 않았어요',
            style: AppText.bodyM.copyWith(color: AppColors.textStrong),
          ),
        ],
      ),
    );
  }
}

/// Figma `List`: 테두리로 묶은 메뉴 줄 모음
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.cardSmall);
    return Material(
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.borderSoft, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: children),
      ),
    );
  }
}

/// Figma `List/Row`: 아이콘, 이름, 오른쪽 화살표 또는 값
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.bold = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;

  /// 오른쪽에 보여줄 값 (앱 버전 등). 있으면 화살표 대신 보인다.
  final String? value;
  final VoidCallback? onTap;
  final bool bold;

  /// 요청 중이면 화살표 대신 불러오는 표시를 보인다.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final Widget trailing;
    if (busy) {
      trailing = const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (value != null) {
      trailing = Flexible(
        child: Text(value, textAlign: TextAlign.right, style: AppText.bodyS),
      );
    } else if (onTap != null) {
      trailing = const Icon(
        AppIcons.arrowRight,
        size: 24,
        color: AppColors.borderSoft,
      );
    } else {
      trailing = const SizedBox.shrink();
    }
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 62),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 24, color: AppColors.textBrand),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.textBody,
                    fontWeight: bold ? FontWeight.w700 : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
