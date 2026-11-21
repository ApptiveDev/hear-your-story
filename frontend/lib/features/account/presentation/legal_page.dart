import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/page_title.dart';
import '../domain/legal_documents.dart';

/// Figma 마이 > 개인정보 처리방침·이용약관: 제목 아래 항목별 본문을 읽는 화면.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            0,
            AppSizes.screenPadding,
            AppSizes.screenPadding,
          ),
          children: [
            AppHeader(
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/my'),
            ),
            const SizedBox(height: 24),
            PageTitle(title: document.title, subtitle: document.summary),
            for (final section in document.sections) ...[
              const SizedBox(height: 28),
              Semantics(
                header: true,
                child: Text(
                  section.heading,
                  style: AppText.labelL.copyWith(color: AppColors.textStrong),
                ),
              ),
              for (final paragraph in section.paragraphs) ...[
                const SizedBox(height: 8),
                Text(
                  paragraph,
                  style: AppText.bodyM.copyWith(color: AppColors.textSub),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
