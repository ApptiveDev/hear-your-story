import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/note_paper.dart';
import '../../../../core/widgets/step_layout.dart';

/// Figma WF-018 전송 완료. 공개 여부는 여기서 판단하지 않고 홈(GET /today)에 맡긴다.
/// 상대를 재촉하는 문구는 쓰지 않는다.
class AnswerSubmittedView extends StatelessWidget {
  const AnswerSubmittedView({
    super.key,
    required this.answerText,
    required this.onEdit,
    required this.onHome,
  });

  final String answerText;
  final VoidCallback onEdit;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return StepLayout(
      onBack: onHome,
      actions: [
        FilledButton(onPressed: onHome, child: const Text('홈으로 가기')),
        OutlinedButton(onPressed: onEdit, child: const Text('답변 수정하기')),
      ],
      children: [
        Center(
          child: ExcludeSemantics(
            child: Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.check,
                size: 40,
                color: AppColors.textBrand,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            '답변을 보냈어요',
            textAlign: TextAlign.center,
            style: AppText.headingL.copyWith(color: AppColors.textBrand),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '부모님이 답변하면 함께 열려요',
          textAlign: TextAlign.center,
          style: AppText.bodyL.copyWith(color: AppColors.textSub),
        ),
        const SizedBox(height: 24),
        NotePaper(label: '내 답변', text: answerText),
      ],
    );
  }
}
