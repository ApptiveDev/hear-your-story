import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// Figma WF-017 `Question`: `#오늘의 질문`과 질문 글.
class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.questionText});
  final String questionText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('#오늘의 질문', style: AppText.labelL),
        const SizedBox(height: 6),
        Text(questionText, style: AppText.headingM),
      ],
    );
  }
}
