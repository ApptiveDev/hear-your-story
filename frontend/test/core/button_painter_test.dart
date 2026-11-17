import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/theme/app_tokens.dart';
import 'package:life_record/core/theme/button_painter.dart';

void main() {
  test(
    'inner shadows brighten the top, shade the bottom and stay inside',
    () async {
      Future<List<int>> render(bool pressed) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.translate(10, 10);
        const shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.buttonL)),
        );
        canvas.drawPath(
          shape.getOuterPath(const Rect.fromLTWH(0, 0, 200, 70)),
          Paint()..color = AppColors.actionPrimary,
        );
        ButtonInnerShadowPainter(
          shape: shape,
          textDirection: TextDirection.ltr,
          pressed: pressed,
        ).paint(canvas, const Size(200, 70));
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
      expect(normal[(5 * 220 + 110) * 4 + 3], 0);
      expect(normal[(11 * 220 + 11) * 4 + 3], 0);
      expect(red(normal, 110, 45), 205); // Primary center stays unchanged.
    },
  );
}
