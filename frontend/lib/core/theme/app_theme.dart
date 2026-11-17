import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'button_painter.dart';

/// 앱 전체 테마. 값은 `app_tokens.dart`의 디자인 토큰(Figma v2)에서 가져온다.
///
/// 화면에서 `Theme.of(context).textTheme.headlineMedium` 등을 쓰면 디자인
/// 글자 스타일이 그대로 적용된다.
/// - headlineLarge = 홈 인사 (Heading/XL 30)
/// - headlineMedium = 화면 제목 (Heading/L 26)
/// - titleLarge = 카드·묶음 제목 (Heading/M 22)
/// - bodyLarge = 제목 아래 설명 (Body/L 20)
/// - bodyMedium = 짧은 안내 (Body/M 18)
/// - bodySmall = 보조 안내 (Body/S 16)
/// - labelLarge = 큰 버튼 글자 (Button/L 26)
///
/// Primary 버튼의 안쪽 그림자는 backgroundBuilder에서 공통으로 그린다.
/// 바깥 그림자는 Material elevation으로 근사한다. builder는 버튼 모양으로
/// 잘리므로 Figma의 두 바깥 그림자를 정확히 재현하지는 않는다.
class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.actionPrimary,
      onPrimary: AppColors.textOnPrimary,
      primaryContainer: AppColors.surfaceCard,
      onPrimaryContainer: AppColors.textStrong,
      secondary: AppColors.actionPrimaryLight,
      onSecondary: AppColors.textOnPrimary,
      secondaryContainer: AppColors.surfaceCard,
      onSecondaryContainer: AppColors.textStrong,
      error: AppColors.error,
      onError: AppColors.textOnPrimary,
      surface: AppColors.bgApp,
      onSurface: AppColors.textStrong,
      onSurfaceVariant: AppColors.textSub,
      surfaceContainerHighest: AppColors.surfaceCard,
      outline: AppColors.borderPrimary,
      outlineVariant: AppColors.borderSoft,
      shadow: Color(0xFF4B4743),
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.buttonL),
    );

    final outlinedStyle = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(AppSizes.buttonLOutlined),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
      backgroundColor: AppColors.surfaceWhite,
      foregroundColor: AppColors.textBrand,
      disabledBackgroundColor: AppColors.bgUnder,
      disabledForegroundColor: AppColors.textDisabled,
      textStyle: AppText.buttonL,
      iconSize: AppSizes.iconL,
      shape: buttonShape,
      elevation: 0,
    );

    OutlineInputBorder fieldBorder(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.field),
      borderSide: BorderSide(color: color, width: 2),
    );

    return ThemeData(
      colorScheme: scheme,
      fontFamily: AppFonts.pretendard,
      scaffoldBackgroundColor: AppColors.bgApp,
      textTheme: const TextTheme(
        headlineLarge: AppText.headingXL,
        headlineMedium: AppText.headingL,
        headlineSmall: AppText.headingM,
        titleLarge: AppText.headingM,
        bodyLarge: AppText.bodyL,
        bodyMedium: AppText.bodyM,
        bodySmall: AppText.bodyS,
        labelLarge: AppText.buttonL,
        labelMedium: AppText.labelM,
        labelSmall: AppText.caption,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textBrand,
        size: AppSizes.iconL,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgApp,
        foregroundColor: AppColors.textBrand,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppText.labelL,
        iconTheme: IconThemeData(
          color: AppColors.textBrand,
          size: AppSizes.iconL,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.buttonL),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              backgroundColor: AppColors.actionPrimary,
              foregroundColor: AppColors.textOnPrimary,
              disabledBackgroundColor: AppColors.borderSoft,
              disabledForegroundColor: AppColors.textDisabled,
              textStyle: AppText.buttonL,
              iconSize: AppSizes.iconL,
              shape: buttonShape,
              shadowColor: AppShadows.button.first.color,
            ).copyWith(
              elevation: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return 0;
                return states.contains(WidgetState.pressed) ? 1 : 3;
              }),
              backgroundBuilder: (context, states, child) {
                if (states.contains(WidgetState.disabled)) {
                  return child ?? const SizedBox.shrink();
                }
                // Respect local shape overrides (for example a smaller button).
                final widget = context.widget;
                final shape = widget is ButtonStyleButton
                    ? widget.style?.shape?.resolve(states)
                    : null;
                return CustomPaint(
                  painter: ButtonInnerShadowPainter(
                    shape: shape ?? buttonShape,
                    textDirection: Directionality.of(context),
                    pressed: states.contains(WidgetState.pressed),
                  ),
                  child: child,
                );
              },
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: outlinedStyle.copyWith(
          side: WidgetStateProperty.resolveWith(_outlinedSide),
          overlayColor: const WidgetStatePropertyAll(AppColors.surfaceCard),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textBrand,
          textStyle: AppText.labelL,
          iconSize: AppSizes.iconM,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceWhite,
        hintStyle: AppText.bodyL.copyWith(color: AppColors.textSub),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 21,
        ),
        border: fieldBorder(AppColors.borderSoft),
        enabledBorder: fieldBorder(AppColors.borderSoft),
        focusedBorder: fieldBorder(AppColors.borderPrimary),
        errorBorder: fieldBorder(AppColors.error),
        focusedErrorBorder: fieldBorder(AppColors.error),
        disabledBorder: fieldBorder(AppColors.borderDisabled),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.actionPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: const Color(0xFF835E44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.actionPrimary,
        linearTrackColor: AppColors.borderSoft,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textStrong,
        contentTextStyle: AppText.bodyM.copyWith(
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }

  /// 테두리 버튼 선. 비활성일 때만 회색 선을 쓴다.
  static BorderSide _outlinedSide(Set<WidgetState> states) {
    final disabled = states.contains(WidgetState.disabled);
    final color = disabled ? AppColors.borderDisabled : AppColors.borderPrimary;
    return BorderSide(color: color, width: 2);
  }
}
