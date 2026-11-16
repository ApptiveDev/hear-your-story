import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// 가입 단계 머리: 왼쪽 이전 화살표와 가운데 진행 막대 3개.
///
/// 단계는 역할 선택(1) → 이름(2) → 초대·연결(3).
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step, this.onBack});

  static const total = 3;

  /// 지금 단계 (1부터). 지난 단계까지 진하게 칠한다.
  final int step;

  /// null이면 이전 화살표를 그리지 않는다.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$total단계 중 $step단계',
      child: SizedBox(
        height: 64,
        child: Stack(
          children: [
            if (onBack != null)
              Align(
                alignment: Alignment.topLeft,
                child: BackButton(
                  onPressed: onBack,
                  color: AppColors.textBrand,
                  style: IconButton.styleFrom(
                    iconSize: AppSizes.iconL,
                    minimumSize: const Size.square(48),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 1; i <= total; i++) ...[
                      if (i > 1) const SizedBox(width: 10),
                      Container(
                        width: AppSizes.stepBarWidth,
                        height: AppSizes.stepBarHeight,
                        decoration: BoxDecoration(
                          color: i <= step
                              ? AppColors.actionPrimaryDark
                              : AppColors.borderDisabled,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
