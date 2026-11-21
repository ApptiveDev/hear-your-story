import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/widgets/note_paper.dart';

import '../helpers/phone_size.dart';

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('쪽지는 글씨 $scale배에서도 글을 모두 보여준다', (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
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
    });
  }
}
