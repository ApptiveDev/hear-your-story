import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_header.dart';

/// 한 단계씩 진행하는 화면의 틀: 위 헤더, 가운데 스크롤되는 내용, 아래 고정 버튼.
///
/// Figma 393 프레임의 좌우 여백 24, 헤더와 내용 사이 24, 버튼 사이 12를 따른다.
/// 글씨를 키워도 내용만 스크롤되고 버튼은 항상 화면 아래에 보인다.
class StepLayout extends StatelessWidget {
  const StepLayout({
    super.key,
    this.onBack,
    this.showTextScale = true,
    required this.children,
    required this.actions,
  });

  /// null이면 헤더에 `이전`을 그리지 않는다.
  final VoidCallback? onBack;

  /// 헤더 오른쪽 `글자 크기` 버튼. Figma에 버튼이 없는 화면(가입·페어링)은 false.
  final bool showTextScale;
  final List<Widget> children;

  /// 아래에 고정할 버튼. 위에서부터 차례로 쌓는다.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        16,
        AppSizes.screenPadding,
        AppSizes.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppHeader(onBack: onBack, showTextScale: showTextScale),
          const SizedBox(height: 24),
          // 한 화면 분량이라 ListView 대신 모두 그려 둔다. 화면 밖으로 밀린 안내도
          // 화면 읽기 프로그램과 테스트가 찾을 수 있다.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
          for (final (i, action) in actions.indexed) ...[
            SizedBox(height: i == 0 ? 24 : 12),
            action,
          ],
        ],
      ),
    );
  }
}
