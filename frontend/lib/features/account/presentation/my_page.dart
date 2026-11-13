import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/auth_flags.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../onboarding/data/auth_providers.dart';
import '../../onboarding/domain/app_user.dart';
import '../../onboarding/presentation/session.dart';
import '../data/account_providers.dart';

const logoutConfirmMessage = '같은 역할로 다시 시작하면 이야기가 그대로 이어져요.';
const kakaoLogoutConfirmMessage = '같은 카카오 계정으로 다시 로그인하면\n이야기가 그대로 이어져요.';
const deleteConfirmMessage =
    '내가 남긴 목소리·글·사진을 모두 지우고 연결도 끊어요.\n'
    '상대방이 남긴 답은 그대로 남아요.\n'
    '탈퇴는 되돌릴 수 없어요.';

/// 내 정보와 로그아웃·탈퇴·안내 항목을 모아 둔 화면
class MyPage extends ConsumerStatefulWidget {
  const MyPage({super.key});

  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  bool _busy = false;

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true && mounted;
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await _confirm(
      title: '로그아웃할까요?',
      message: ref.read(kakaoAuthEnabledProvider)
          ? kakaoLogoutConfirmMessage
          : logoutConfirmMessage,
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
        appBar: AppBar(title: const Text('마이페이지')),
        body: SafeArea(
          child: AbsorbPointer(
            absorbing: _busy, // 탈퇴를 요청하는 동안 다른 항목을 누르지 못하게 한다
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (user != null) _ProfileCard(user: user),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('로그아웃'),
                  onTap: _signOut,
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('개인정보 처리방침'),
                  onTap: () =>
                      _showInfo('개인정보 처리방침', AppConfig.privacyPolicyUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('문의하기'),
                  onTap: () => _showInfo('문의하기', AppConfig.supportContact),
                ),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('앱 버전'),
                  trailing: Text(AppConfig.appVersion),
                ),
                if (AppConfig.accountDeletionApi) ...[
                  const Divider(height: 32),
                  ListTile(
                    leading: const Icon(Icons.person_remove_outlined),
                    title: const Text('탈퇴하기'),
                    trailing: _busy
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _deleteAccount,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final role = user.role == UserRole.parent ? '부모님' : '자녀';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_circle, size: 48, color: AppColors.dark),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: AppText.greeting),
                const SizedBox(height: 4),
                Text(role, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
