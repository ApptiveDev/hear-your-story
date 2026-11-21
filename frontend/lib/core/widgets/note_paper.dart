import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'notebook_paper.dart';

/// Figma `Note/Paper`: 이름표와 글이 적힌 쪽지 (내 답변, 내 이야기).
///
/// 왼쪽 종이 구멍·여백선·가로 줄은 [NotebookPaper]가 그린다.
class NotePaper extends StatelessWidget {
  const NotePaper({super.key, required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return NotebookPaper(
      lines: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 30,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: AppText.labelM.copyWith(color: AppColors.textBrand),
              ),
            ),
          ),
          Text(
            text,
            style: AppText.bodyL.copyWith(color: AppColors.textStrong),
          ),
        ],
      ),
    );
  }
}
