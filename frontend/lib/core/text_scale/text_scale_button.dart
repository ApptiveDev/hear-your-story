import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_tokens.dart';
import 'text_scale.dart';

/// Figma `글자 크기 조정`: `가/가 글자 크기` 테두리 버튼. 누를 때마다 보통 ↔ 크게.
///
/// 화면 읽기 프로그램에는 지금 크게 보고 있는지(켜짐·꺼짐)를 알려준다.
class TextScaleButton extends ConsumerWidget {
  const TextScaleButton({super.key});

  static const height = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(textSizeProvider) == TextSize.large;
    // 버튼의 누르기 동작·켜짐 상태·이름을 한 덩어리로 읽게 한다. 버튼 안 글자
    // (`가/가 글자 크기`)는 읽지 않는다
    return MergeSemantics(
      child: Semantics(
        toggled: large,
        label: '글자 크게 보기',
        child: OutlinedButton(
          onPressed: () => ref.read(textSizeProvider.notifier).toggle(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, height),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            backgroundColor: AppColors.surfaceWhite,
            foregroundColor: AppColors.textBrand,
            side: const BorderSide(color: AppColors.borderPrimary, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.buttonM),
            ),
          ),
          // 헤더 한 줄에 `이전`과 함께 들어가야 해서, 글씨를 많이 키우면 버튼 글자만
          // 줄여서 넘치지 않게 한다
          child: ExcludeSemantics(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '가',
                      style: AppText.headingM.copyWith(
                        color: AppColors.textBrand,
                      ),
                    ),
                    TextSpan(
                      text: '/가  ',
                      style: AppText.labelM.copyWith(
                        color: AppColors.textBrand,
                      ),
                    ),
                    TextSpan(
                      text: '글자 크기',
                      style: AppText.buttonM.copyWith(
                        color: AppColors.textBrand,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
