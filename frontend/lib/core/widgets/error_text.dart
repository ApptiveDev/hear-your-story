import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

/// Figma `Message/Error`: 빨간 느낌표와 굵은 안내 글.
///
/// 화면 읽기 프로그램이 바로 읽도록 나타날 때 알린다.
class ErrorText extends StatelessWidget {
  const ErrorText(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.exclamation, color: AppColors.error, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppText.labelM.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
