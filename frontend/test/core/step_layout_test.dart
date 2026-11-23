import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/theme/app_tokens.dart';
import 'package:life_record/core/widgets/step_layout.dart';

import '../helpers/phone_size.dart';

void main() {
  for (final hasAction in [true, false]) {
    testWidgets('끝까지 스크롤해도 버튼 그림자 자리가 남는다 (아래 버튼: $hasAction)', (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StepLayout(
                onBack: () {},
                actions: [
                  if (hasAction)
                    OutlinedButton(onPressed: () {}, child: const Text('아래')),
                ],
                children: [
                  const SizedBox(height: 2000),
                  FilledButton(onPressed: () {}, child: const Text('듣기')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();

      final clip = tester.getRect(find.byType(SingleChildScrollView));
      final button = tester.getRect(find.byType(FilledButton));
      // 버튼 아래 4px 단과 좌우 그림자가 스크롤 영역에 잘리지 않는다
      expect(
        clip.bottom - button.bottom,
        greaterThan(AppShadows.button.first.offset.dy),
      );
      expect(button.left - clip.left, AppSizes.screenPadding);
      expect(clip.right - button.right, AppSizes.screenPadding);
      // 화면(또는 아래 버튼)과의 간격은 디자인대로 24
      final below = hasAction
          ? tester.getRect(find.widgetWithText(OutlinedButton, '아래')).top
          : tester.getRect(find.byType(Scaffold)).bottom;
      expect(below - button.bottom, 24);
    });
  }
}
