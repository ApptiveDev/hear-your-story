import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Figma `Note/Page`·`Note/Paper`의 종이: 카드색 바탕에 왼쪽 구멍(`Paper/Hole`),
/// 갈색 여백선(`Margin line`), 가로 줄(`Lines`)을 그린다. 글은 [child]에 넣는다.
///
/// 구멍·여백선은 종이 높이에 맞춰 늘어난다. 가로 줄은 글 줄 높이(30)에 맞춘 값이라
/// 글씨를 키우면 어긋나므로 [lines]가 켜져 있어도 1배일 때만 그린다.
class NotebookPaper extends StatelessWidget {
  const NotebookPaper({super.key, required this.child, this.lines = false});

  final Widget child;

  /// 첫 글줄(높이 30짜리 이름표 아래)부터 30마다 가로 줄을 그린다.
  final bool lines;

  /// 구멍·여백선 자리를 뺀 글 시작 위치
  static const contentLeft = 52.0;
  static const _top = 12.0;

  @override
  Widget build(BuildContext context) {
    final aligned = MediaQuery.textScalerOf(context).scale(1) <= 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.note),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.note),
        child: CustomPaint(
          painter: _PaperPainter(lines: lines && aligned),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(contentLeft, _top, 20, 18),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PaperPainter extends CustomPainter {
  const _PaperPainter({required this.lines});
  final bool lines;

  @override
  void paint(Canvas canvas, Size size) {
    if (lines) {
      final line = Paint()..color = AppColors.borderSoft;
      // 이름표(30) 아래 첫 글줄 끝에서 시작해 30마다 1px 줄
      for (var y = 12.0 + 30 + 29; y < size.height; y += 30) {
        canvas.drawRect(
          Rect.fromLTWH(NotebookPaper.contentLeft, y, size.width - 72, 1),
          line,
        );
      }
    }

    // 구멍: 31 간격, 위에서 10 띄움. 종이 밖에서 안으로 뚫린 홈 + 둥근 끝
    final hole = Paint()..color = AppColors.bgApp;
    for (var y = 10.0; y + 31 <= size.height; y += 31) {
      canvas
        ..drawRect(Rect.fromLTWH(0, y + 13, 22, 5), hole)
        ..drawCircle(Offset(22, y + 15.5), 8, hole);
    }

    canvas.drawRect(
      Rect.fromLTRB(42, 10, 43, size.height - 10),
      Paint()..color = const Color(0xFFCD8F66), // 여백선 (Figma Margin line)
    );
  }

  @override
  bool shouldRepaint(_PaperPainter old) => old.lines != lines;
}
