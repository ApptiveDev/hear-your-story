import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';

/// 탈퇴를 요청한 뒤 보여주는 완료 화면. 로그인 정보는 이미 지워진 상태다.
class AccountDeletedPage extends StatelessWidget {
  const AccountDeletedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 뒤로 가도 로그인 전 화면밖에 없다
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 72,
                  color: AppColors.base,
                ),
                const SizedBox(height: 24),
                Text(
                  '탈퇴를 시작했어요',
                  textAlign: TextAlign.center,
                  style: AppText.subTitle,
                ),
                const SizedBox(height: 16),
                Text(
                  '남긴 기록은 순서대로 지워져요.\n그동안 함께해 주셔서 고마워요.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => context.go('/onboarding'),
                  child: const Text('처음으로'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
