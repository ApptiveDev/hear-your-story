import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// 배치나 터치 판정에 영향을 주지 않고 Figma의 안쪽 그림자를 그린다.
class ButtonInnerShadowPainter extends CustomPainter {
  const ButtonInnerShadowPainter({
    required this.shape,
    required this.textDirection,
    required this.pressed,
  });

  final OutlinedBorder shape;
  final TextDirection textDirection;
  final bool pressed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    final outline = shape.getOuterPath(bounds, textDirection: textDirection);
    final shadows = pressed
        ? AppInnerShadows.buttonPressed
        : AppInnerShadows.button;
    canvas.save();
    canvas.clipPath(outline);
    for (final shadow in shadows) {
      // 이동한 모양의 바깥 영역을 흐리게 그려 원래 모양의 안쪽에 그림자를 만든다.
      // 바깥 경계는 흐림 효과에 영향을 주지 않도록 충분히 멀리 둔다.
      final extent = shadow.blurSigma * 4 + shadow.offset.distance + 1;
      final outside = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(bounds.inflate(extent))
        ..addPath(outline.shift(shadow.offset), Offset.zero);
      canvas.drawPath(outside, shadow.toPaint());
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ButtonInnerShadowPainter oldDelegate) =>
      shape != oldDelegate.shape ||
      textDirection != oldDelegate.textDirection ||
      pressed != oldDelegate.pressed;

  @override
  bool? hitTest(Offset position) => false;
}
