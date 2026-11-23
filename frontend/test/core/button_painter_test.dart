import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/theme/app_tokens.dart';
import 'package:life_record/core/theme/button_painter.dart';

void main() {
  test(
    'inner shadows shade the fill and outer shadow adds a solid lower edge',
    () async {
      Future<List<int>> render(bool pressed) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.translate(10, 10);
        final shape = DepthButtonShape(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadius.buttonL),
          ),
          pressed: pressed,
        );
        canvas.drawPath(
          shape.getOuterPath(const Rect.fromLTWH(0, 0, 200, 70)),
          Paint()..color = AppColors.actionPrimary,
        );
        shape.paint(canvas, const Rect.fromLTWH(0, 0, 200, 70));
        final picture = recorder.endRecording();
        final image = await picture.toImage(220, 90);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final result = bytes!.buffer.asUint8List().toList();
        image.dispose();
        picture.dispose();
        return result;
      }

      final normal = await render(false);
      final pressed = await render(true);
      int red(List<int> pixels, int x, int y) => pixels[(y * 220 + x) * 4];
      expect(red(normal, 110, 12), greaterThan(red(normal, 110, 45)));
      expect(red(normal, 110, 77), lessThan(red(normal, 110, 45)));
      expect(red(pressed, 110, 76), greaterThan(red(normal, 110, 76)));
      // 버튼 아래 4px까지 갈색 단이 보이고, 누르면 1px로 줄어든다.
      int alpha(List<int> pixels, int y) => pixels[(y * 220 + 110) * 4 + 3];
      expect(alpha(normal, 83), greaterThanOrEqualTo(128));
      expect(alpha(pressed, 80), greaterThanOrEqualTo(127));
      expect(alpha(pressed, 82), 0);
      expect(red(normal, 110, 45), 205); // 주 버튼 중앙의 색은 바뀌지 않는다.
    },
  );
}
