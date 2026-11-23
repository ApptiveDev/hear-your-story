import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/theme/app_theme.dart';
import 'package:life_record/core/widgets/note_paper.dart';
import 'package:life_record/core/widgets/notebook_paper.dart';

import '../helpers/phone_size.dart';

void main() {
  for (final scale in [1.0, 1.15, 1.3, 2.0]) {
    testWidgets('쪽지는 글씨 $scale배에서도 글을 모두 보여준다', (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(24),
                child: NotePaper(
                  label: '내 이야기',
                  text: '겨울이면 할머니가 구워주신 군고구마가 제일 좋았단다.',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('내 이야기'), findsOneWidget);
      expect(find.textContaining('군고구마'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 가로 줄 간격이 글씨 크기와 함께 벌어져 글줄마다 바로 밑에 놓인다
      final paint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PaperPainter,
      );
      final unit = (tester.widget<CustomPaint>(paint).painter! as PaperPainter)
          .lineHeight;
      expect(unit, closeTo(30 * scale, 0.01));
      final text = find.textContaining('군고구마');
      expect(
        tester.getTopLeft(text).dy - tester.getTopLeft(paint).dy,
        closeTo(12 + unit, 0.01),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)),
      );
      final lines = paragraph.size.height / unit;
      expect(lines, greaterThan(1));
      expect(lines, closeTo(lines.roundToDouble(), 0.05));
    });
  }
}
