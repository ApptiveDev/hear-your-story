import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

/// 아래 탭 하나.
class AppTab {
  const AppTab(this.label, this.icon, this.location);
  final String label;
  final IconData icon;
  final String location;
}

/// Figma `Tab/Bar`의 탭들. 달력은 월별 조회를 켠 빌드에서만 보인다.
List<AppTab> appTabs({bool calendar = AppConfig.storiesMonthApi}) => [
  const AppTab('홈', AppIcons.home, '/today'),
  const AppTab('책장', AppIcons.books, '/stories'),
  if (calendar) const AppTab('달력', AppIcons.calendar, '/stories/calendar'),
  const AppTab('마이', AppIcons.user, '/my'),
];

/// 지금 주소에 맞는 탭 위치. 더 긴 주소(`/stories/calendar`)를 먼저 맞춘다.
int tabIndexFor(String location, List<AppTab> tabs) {
  var best = 0;
  var bestLength = -1;
  for (final (i, tab) in tabs.indexed) {
    final matches =
        location == tab.location || location.startsWith('${tab.location}/');
    if (matches && tab.location.length > bestLength) {
      best = i;
      bestLength = tab.location.length;
    }
  }
  return best;
}

/// 탭 화면 스크롤 여백. 끝까지 내리면 내용이 탭 막대 위로 올라온다.
EdgeInsets tabPagePadding(BuildContext context, {double top = 32}) =>
    EdgeInsets.fromLTRB(
      AppSizes.screenPadding,
      top,
      AppSizes.screenPadding,
      AppSizes.screenPadding + MediaQuery.paddingOf(context).bottom,
    );

/// 홈·책장·달력·마이 화면을 감싸고 아래에 탭 막대를 둔다.
class AppTabShell extends StatelessWidget {
  const AppTabShell({
    super.key,
    required this.location,
    required this.child,
    this.tabs,
  });

  final String location;
  final Widget child;

  /// 테스트에서 달력 탭을 켜고 끌 때만 넘긴다.
  final List<AppTab>? tabs;

  @override
  Widget build(BuildContext context) {
    final tabs = this.tabs ?? appTabs();
    final current = tabIndexFor(location, tabs);
    // 탭은 go로 바꾸므로 되돌아갈 화면이 없다. 홈이 아닌 탭에서 뒤로가기는
    // 앱을 닫지 않고 홈으로 보낸다.
    return PopScope(
      canPop: current == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(tabs.first.location);
      },
      child: Scaffold(
        // 막대 뒤로 화면이 이어져 보이게 한다. 막대 높이는 화면의 아래 안전 영역으로
        // 전달되므로 각 화면이 스크롤 끝에 그만큼 여백을 둔다([tabPagePadding]).
        extendBody: true,
        body: child,
        bottomNavigationBar: AppTabBar(
          tabs: tabs,
          currentIndex: current,
          onTap: (i) {
            if (i != current) context.go(tabs[i].location);
          },
        ),
      ),
    );
  }
}

/// Figma `Tab/Bar`: 알약 모양 막대. 고른 탭은 진한 갈색 알약으로 채운다.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AppTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 8, 18, 12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bgUnder,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.tabBar,
          ),
          child: Row(
            children: [
              for (final (i, tab) in tabs.indexed)
                Expanded(
                  child: _TabItem(
                    tab: tab,
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textOnPrimary : AppColors.textBrand;
    return Semantics(
      button: true,
      selected: selected,
      label: '${tab.label} 탭',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.actionPrimaryDark : Colors.transparent,
        borderRadius: BorderRadius.circular(32),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Column(
              // 아래 막대는 높이 제한 없이 놓이므로 내용만큼만 차지해야 한다.
              // (max면 탭 막대가 화면 전체를 차지해 위 화면이 보이지 않는다)
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tab.icon, size: 28, color: color),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tab.label,
                    style: AppText.labelM.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
