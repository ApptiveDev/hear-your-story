import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../onboarding/data/auth_providers.dart';
import '../../onboarding/domain/app_user.dart';
import '../../onboarding/presentation/session.dart';
import '../data/account_providers.dart';
import 'account_session.dart';

const logoutConfirmMessage = '같은 역할로 다시 시작하면 이야기가 그대로 이어져요.';
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
    final router = GoRouter.of(context);
    if (!await _confirm(
      title: '로그아웃할까요?',
      message: logoutConfirmMessage,
      action: '로그아웃',
    )) {
      return;
    }
    await ref.read(accountSessionProvider).clear();
    router.go('/onboarding');
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
    setState(() => _busy = true);
    try {
      await ref.read(accountRepositoryProvider).deleteAccount();
    } on ApiException catch (e) {
      // 이미 탈퇴를 처리하는 중이면 서버가 지우고 있으니 같은 결과로 본다
      if (e.errorCode != 'ACCOUNT_DELETION_IN_PROGRESS') {
        if (!mounted) return;
        setState(() => _busy = false);
        if (await handleSessionExpired(context, ref, e)) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.userMessage)));
        return;
      }
    }
    // 성공하면 바로 로그인 정보를 지우고 완료 화면으로 간다
    await ref.read(accountSessionProvider).clear();
    router.go('/account-deleted');
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
    return Scaffold(
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
                onTap: () => _showInfo('개인정보 처리방침', AppConfig.privacyPolicyUrl),
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
