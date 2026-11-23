import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Figma `Note/Page`·`Note/Paper`의 종이: 카드색 바탕에 왼쪽 구멍(`Paper/Hole`)과
/// 글 밑 가로 줄(`Lines`)을 그린다. 글은 `NoteEntry`로 [child]에 넣는다.
///
/// 구멍은 종이 높이에 맞춰 늘어난다. 가로 줄 간격은 글 줄 높이([lineHeight])라서
/// 글씨를 키우면 같이 벌어진다.
class NotebookPaper extends StatelessWidget {
  const NotebookPaper({super.key, required this.child, this.margin = true});

  final Widget child;

  /// 왼쪽 세로 여백선(`Margin line`). Figma에서 `Note/Page`에만 있다.
  final bool margin;

  /// 구멍·여백선 자리를 뺀 글 시작 위치
  static const contentLeft = 52.0;
  static const _top = 12.0;

  /// 공책 한 줄 높이: 지금 글씨 크기에서 Body/L 글 한 줄
  static double lineHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(AppText.bodyL.fontSize!) *
      AppText.bodyL.height!;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.note),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.note),
        child: CustomPaint(
          painter: PaperPainter(
            lineHeight: lineHeight(context),
            margin: margin,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(contentLeft, _top, 20, 18),
            child: child,
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
class PaperPainter extends CustomPainter {
  const PaperPainter({required this.lineHeight, required this.margin});
  final double lineHeight;
  final bool margin;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = AppColors.borderSoft;
    // 이름표 한 줄 아래, 첫 글줄 끝에서 시작해 글줄마다 1px 줄
    for (
      var y = NotebookPaper._top + lineHeight * 2 - 1;
      y < size.height;
      y += lineHeight
    ) {
      canvas.drawRect(
        Rect.fromLTWH(NotebookPaper.contentLeft, y, size.width - 72, 1),
        line,
      );
    }

    // 구멍: 31 간격, 위에서 10 띄움. 종이 밖에서 안으로 뚫린 홈 + 둥근 끝
    final hole = Paint()..color = AppColors.bgApp;
    for (var y = 10.0; y + 31 <= size.height; y += 31) {
      canvas
        ..drawRect(Rect.fromLTWH(0, y + 13, 22, 5), hole)
        ..drawCircle(Offset(22, y + 15.5), 8, hole);
    }

    if (margin) {
      canvas.drawRect(
        Rect.fromLTRB(42, 10, 43, size.height - 10),
        Paint()..color = AppColors.noteMargin,
      );
    }
  }

  @override
  bool shouldRepaint(PaperPainter old) =>
      old.lineHeight != lineHeight || old.margin != margin;
}
