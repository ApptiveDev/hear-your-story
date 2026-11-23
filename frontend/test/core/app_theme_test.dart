import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/theme/app_theme.dart';
import 'package:life_record/core/theme/app_tokens.dart';
import 'package:life_record/core/theme/button_painter.dart';
import 'package:life_record/core/widgets/choice_dialog.dart';

/// 버튼 Material이 실제로 그리는 모양
ShapeBorder? shapeOf(WidgetTester tester, Type button) => tester
    .widget<Material>(
      find.descendant(of: find.byType(button), matching: find.byType(Material)),
    )
    .shape;

void main() {
  testWidgets('primary press preserves geometry, semantics and callback', (
    tester,
  ) async {
    var calls = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: FilledButton(
                onPressed: () => calls++,
                child: const Text('Send'),
              ),
            ),
          ),
        ),
      ),
    );
    final button = find.byType(FilledButton);
    final before = tester.getSize(button);
    expect(before, const Size(300, 70));
    expect(
      tester.getSemantics(button),
      matchesSemantics(
        label: 'Send',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    DepthButtonShape shape() =>
        shapeOf(tester, FilledButton)! as DepthButtonShape;
    expect(shape().pressed, isFalse);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    expect(shape().pressed, isTrue);
    expect(tester.getSize(button), before);
    expect(calls, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(shape().pressed, isFalse);
    expect(calls, 1);
    semantics.dispose();
  });

  testWidgets('disabled and outline buttons remain flat', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              const FilledButton(onPressed: null, child: Text('Disabled')),
              OutlinedButton(onPressed: () {}, child: const Text('Outline')),
            ],
          ),
        ),
      ),
    );
    expect(shapeOf(tester, FilledButton), isNot(isA<DepthButtonShape>()));
    final disabledMaterial = tester.widget<Material>(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Material),
      ),
    );
    expect(disabledMaterial.elevation, 0);
    expect(disabledMaterial.color, AppColors.borderSoft);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(OutlinedButton)),
    );
    await tester.pump();
    expect(shapeOf(tester, OutlinedButton), isNot(isA<DepthButtonShape>()));
    await gesture.up();
    await tester.pumpAndSettle();
    final style = AppTheme.light().filledButtonTheme.style!;
    expect(style.textStyle!.resolve({}), AppText.buttonL);
    expect(style.elevation!.resolve({WidgetState.pressed}), 0);
  });

  testWidgets('local shape and small button dimensions are preserved', (
    tester,
  ) async {
    const shape = StadiumBorder();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: shape,
                minimumSize: const Size(110, 47),
                padding: const EdgeInsets.all(8),
                textStyle: AppText.buttonM,
              ),
              onPressed: () {},
              icon: const Icon(Icons.send),
              label: const Text('Send'),
            ),
          ),
        ),
      ),
    );
    expect(shapeOf(tester, FilledButton), shape);
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byType(FilledButton),
              matching: find.byType(Material),
            ),
          )
          .height,
      47,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('팝업 뒤 배경은 디자인의 갈색으로 어둡게 한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showChoiceDialog(
              context,
              title: '제목',
              message: '안내',
              stayLabel: '계속',
              leaveLabel: '나가기',
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<ModalBarrier>(find.byType(ModalBarrier)).last.color,
      AppColors.dim,
    );
  });
}
