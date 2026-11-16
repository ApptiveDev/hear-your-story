import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Figma `Note/Paper`: 이름표와 글이 적힌 쪽지 (내 답변, 내 이야기).
///
/// 디자인의 왼쪽 종이 구멍·줄 장식은 빼고 바탕과 글만 옮겼다.
class NotePaper extends StatelessWidget {
  const NotePaper({super.key, required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.note),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: AppText.labelM.copyWith(color: AppColors.textBrand),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: AppText.bodyL.copyWith(color: AppColors.textStrong),
          ),
        ],
      ),
    );
  }
}
