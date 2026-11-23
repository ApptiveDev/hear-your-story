import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'notebook_paper.dart';

/// Figma `Note/Paper`: 이름표와 글이 적힌 쪽지 (내 답변, 내 이야기).
class NotePaper extends StatelessWidget {
  const NotePaper({super.key, required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) => NotebookPaper(
    margin: false,
    child: NoteEntry(label: label, text: text),
  );
}

/// [NotebookPaper]에 적는 한 사람의 글: (아이콘) + 이름표 한 줄 + 글
class NoteEntry extends StatelessWidget {
  const NoteEntry({
    super.key,
    this.icon,
    required this.label,
    required this.text,
    this.waiting = false,
  });

  final IconData? icon;
  final String label;
  final String text;

  /// 글 대신 기다리는 안내를 보여준다. 흐린 글씨로, 나타나면 읽어준다.
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final lineHeight = NotebookPaper.lineHeight(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 가로 줄이 글 밑에 놓이게 이름표는 늘 한 줄 높이다. 길면 줄바꿈 대신 줄인다.
        SizedBox(
          height: lineHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 24, color: AppColors.textBrand),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: AppText.labelM.copyWith(color: AppColors.textBrand),
                ),
              ],
            ),
          ),
        ),
        Semantics(
          liveRegion: waiting,
          child: Text(
            text,
            style: AppText.bodyL.copyWith(
              color: waiting ? AppColors.textSub : AppColors.textStrong,
            ),
          ),
        ),
      ],
    );
  }
}
