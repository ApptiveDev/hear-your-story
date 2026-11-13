import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';

/// 화면 아래(Scaffold.persistentFooterButtons)에 둘 로그아웃 버튼 목록.
List<Widget> logoutFooter(WidgetRef _) => const [LogoutButton()];

/// 로그아웃 버튼. 실수로 누르지 않게 한 번 더 묻는다.
class LogoutButton extends StatefulWidget {
  const LogoutButton({super.key});

  @override
  State<LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<LogoutButton> {
  bool _busy = false;

  Future<void> _confirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        content: const Text('같은 카카오 계정으로 다시 로그인하면\n이야기가 그대로 이어져요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    await signOut(context);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _busy ? null : _confirm,
      child: const Text('로그아웃'),
    );
  }
}
