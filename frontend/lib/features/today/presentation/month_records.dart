import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_tokens.dart';
import '../../stories/presentation/stories_calendar_page.dart';
import '../../stories/presentation/stories_month_provider.dart';
import 'today_provider.dart';

/// 홈 맨 아래 "N월 기록": 이번 달 공개된 이야기를 최신순으로 보여준다.
/// 홈의 주 행동을 방해하지 않도록 불러오는 중·실패·빈 달에는 아무것도 그리지 않는다.
class MonthRecords extends ConsumerWidget {
  const MonthRecords({super.key, this.now});

  /// 테스트에서 "오늘"을 고정할 때 쓴다.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 월별 API가 배포되지 않은 빌드에서는 호출하지 않는다.
    if (!AppConfig.storiesMonthApi) return const SizedBox.shrink();
    // 계약의 month 기준 시간대는 Asia/Seoul이다.
    final today =
        now?.call() ?? DateTime.now().toUtc().add(const Duration(hours: 9));
    final month = monthKey(today);
    // 홈을 새로고침하거나 상대 답으로 오늘 이야기가 공개되면 이번 달 기록도 다시 본다.
    ref.listen(todayProvider, (previous, next) {
      // 처음 불러온 값은 건너뛴다(이미 같은 때에 불러오는 중).
      final before = previous?.value;
      final changed =
          before != null && next.hasValue && !identical(before, next.value);
      if (changed) ref.invalidate(storiesMonthProvider(month));
    });
    final stories = ref.watch(storiesMonthProvider(month)).value;
    if (stories == null || stories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Semantics(
          header: true,
          child: Text(
            '${today.month}월 기록',
            style: AppText.headingM.copyWith(color: AppColors.textBrand),
          ),
        ),
        // 디자인(WF-006)처럼 가장 최근 이야기가 위에 온다.
        for (final story in stories.reversed) ...[
          const SizedBox(height: 12),
          StoryRecordRow(story: story, month: month),
        ],
      ],
    );
  }
}
