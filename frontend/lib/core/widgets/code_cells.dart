import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Figma `Input/Code`: 숫자 한 자리씩 들어가는 칸 여러 개.
///
/// 보여주기만 한다. 입력은 위에 겹친 `TextField`가 받는다(부모 코드 입력).
class CodeCells extends StatelessWidget {
  const CodeCells({
    super.key,
    required this.code,
    this.length = 6,
    this.focusedIndex,
    this.error = false,
    this.dimmed = false,
  });

  final String code;
  final int length;

  /// 다음에 입력될 칸. 주황 테두리로 보여준다.
  final int? focusedIndex;

  /// 모든 칸을 빨간 테두리로 (잘못된 코드)
  final bool error;

  /// 흐리게 (만료된 코드)
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Row(
        children: [
          for (var i = 0; i < length; i++) ...[
            if (i > 0) const SizedBox(width: 9),
            Expanded(child: _cell(i)),
          ],
        ],
      ),
    );
  }

  Widget _cell(int i) {
    final focused = !error && i == focusedIndex;
    final Color border;
    if (error) {
      border = AppColors.error;
    } else if (focused) {
      border = AppColors.borderPrimary;
    } else {
      border = AppColors.borderSoft;
    }
    return Container(
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppRadius.codeCell),
        border: Border.all(color: border, width: error || focused ? 3 : 2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          i < code.length ? code[i] : '',
          style: AppText.buttonL.copyWith(color: AppColors.textStrong),
        ),
      ),
    );
  }
}
