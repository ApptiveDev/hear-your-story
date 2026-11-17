import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/theme/app_theme.dart';
import 'package:life_record/core/theme/app_tokens.dart';
import 'package:life_record/core/theme/button_painter.dart';

Finder get shadowPaint => find.byWidgetPredicate(
  (widget) =>
      widget is CustomPaint && widget.painter is ButtonInnerShadowPainter,
);

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
    ButtonInnerShadowPainter painter() =>
        tester.widget<CustomPaint>(shadowPaint).painter!
            as ButtonInnerShadowPainter;
    expect(painter().pressed, isFalse);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    expect(painter().pressed, isTrue);
    expect(tester.getSize(button), before);
    expect(calls, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(painter().pressed, isFalse);
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
    expect(shadowPaint, findsNothing);
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
    expect(shadowPaint, findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
    final style = AppTheme.light().filledButtonTheme.style!;
    expect(style.textStyle!.resolve({}), AppText.buttonL);
    expect(style.elevation!.resolve({WidgetState.pressed}), 1);
    expect(
      style.elevation!.resolve({WidgetState.disabled, WidgetState.pressed}),
      0,
    );
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
    final painter =
        tester.widget<CustomPaint>(shadowPaint).painter!
            as ButtonInnerShadowPainter;
    expect(painter.shape, shape);
    expect(tester.getSize(shadowPaint).height, 47);
    expect(tester.takeException(), isNull);
  });
}
