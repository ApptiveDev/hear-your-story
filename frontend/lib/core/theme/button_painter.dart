import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// 주 버튼 모양. 배치나 터치 판정은 그대로 두고 Figma의 안팎 그림자를 함께 그린다.
///
/// backgroundBuilder는 버튼 모양으로 잘려서 바깥 그림자를 그릴 수 없어, 잘리지 않는
/// 테두리 그리기 단계에서 그린다.
class DepthButtonShape extends RoundedRectangleBorder {
  const DepthButtonShape({
    super.side,
    super.borderRadius,
    this.pressed = false,
  });

  final bool pressed;

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    super.paint(canvas, rect, textDirection: textDirection);
    if (rect.isEmpty) return;
    final outline = getOuterPath(rect, textDirection: textDirection);

    canvas.save();
    canvas.clipPath(_outside(outline, rect.inflate(64)));
    for (final shadow
        in pressed ? AppShadows.buttonPressed : AppShadows.button) {
      canvas.drawPath(outline.shift(shadow.offset), shadow.toPaint());
    }
    canvas.restore();

    canvas.save();
    canvas.clipPath(outline);
    for (final shadow
        in pressed ? AppInnerShadows.buttonPressed : AppInnerShadows.button) {
      // 이동한 모양의 바깥 영역을 흐리게 그려 원래 모양의 안쪽에 그림자를 만든다.
      // 바깥 경계는 흐림 효과에 영향을 주지 않도록 충분히 멀리 둔다.
      final extent = shadow.blurSigma * 4 + shadow.offset.distance + 1;
      canvas.drawPath(
        _outside(outline.shift(shadow.offset), rect.inflate(extent)),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  static Path _outside(Path outline, Rect bounds) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(bounds)
    ..addPath(outline, Offset.zero);

  @override
  DepthButtonShape copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
  }) => DepthButtonShape(
    side: side ?? this.side,
    borderRadius: borderRadius ?? this.borderRadius,
    pressed: pressed,
  );

  // 부모 클래스의 보간은 그림자 없는 모양을 돌려줘 누를 때 깜빡인다. 바로 바꾼다.
  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => this;

  @override
  bool operator ==(Object other) =>
      super == other && other is DepthButtonShape && other.pressed == pressed;

  @override
  int get hashCode => Object.hash(super.hashCode, pressed);
}
