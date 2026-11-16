import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Figma `Dialog/Confirm`: 제목, 안내, 위아래로 놓인 큰 버튼 두 개.
///
/// 위 버튼(주 버튼)은 지금 하던 일을 이어가고, 아래 버튼이 [leaveLabel]이다.
/// [leaveLabel]을 누르면 true, 그 밖에는 false를 돌려준다.
Future<bool> showChoiceDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String stayLabel,
  required String leaveLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.surfaceWhite,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSizes.screenPadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.headingM.copyWith(color: AppColors.textBrand),
              ),
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: AppText.bodyL),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(stayLabel),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(leaveLabel),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
