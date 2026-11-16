import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Figma `Title/Page`: 큰 제목과 그 아래 한 줄 설명.
class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(title, style: AppText.headingXL)),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle, style: AppText.bodyS),
        ],
      ],
    );
  }
}
