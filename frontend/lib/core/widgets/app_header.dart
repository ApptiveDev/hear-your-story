import 'package:flutter/material.dart';

import '../text_scale/text_scale_button.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

/// Figma `Header/Back`: 왼쪽 `← 이전`, 오른쪽 글자 크기 버튼.
///
/// 높이는 디자인과 같은 56 이상을 유지해서 버튼이 없어도 아래 내용 위치가 바뀌지
/// 않게 한다. 글씨를 키우면 그만큼 높아진다.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.onBack});

  /// null이면 `이전`을 그리지 않는다.
  final VoidCallback? onBack;

  static const height = 56.0;

  @override
  Widget build(BuildContext context) {
    final onBack = this.onBack;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: height),
      child: Row(
        children: [
          if (onBack != null)
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(AppIcons.arrowLeft, size: 22),
              label: const Text('이전'),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.fromLTRB(0, 6, 12, 6),
                textStyle: AppText.labelL,
              ),
            ),
          const Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextScaleButton(),
            ),
          ),
        ],
      ),
    );
  }
}
