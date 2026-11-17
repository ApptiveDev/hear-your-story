import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Paints Figma's inner shadows without changing layout or hit testing.
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
      // Blur the outside of a shifted shape into its original interior.
      // Keep the outer edge far enough away that it cannot affect the blur.
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
