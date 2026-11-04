import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/parent_answer/presentation/parent_answer_page.dart';
import '../features/recording/presentation/recording_args.dart';
import '../features/recording/presentation/recording_page.dart';
import 'parent_only_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/pairing/presentation/pairing_page.dart';
import '../features/today/presentation/today_page.dart';
import '../core/config/app_config.dart';
import '../features/child_answer/presentation/child_answer_args.dart';
import '../features/child_answer/presentation/child_answer_page.dart';
import '../features/stories/presentation/stories_calendar_page.dart';
import '../features/stories/presentation/stories_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  const demo = String.fromEnvironment('PART_B_DEMO');
  return GoRouter(
    // 홈 완성 전 B 단독 확인용. 실제 API·release에서는 적용하지 않는다.
    initialLocation: kDebugMode && AppConfig.useMock && demo == 'recording'
        ? '/recording'
        : kDebugMode && AppConfig.useMock && demo == 'answer'
        ? '/parent-answer'
        : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ), // A
      GoRoute(
        path: '/pairing',
        builder: (context, state) => const PairingPage(),
      ), // A
      GoRoute(
        path: '/today',
        builder: (context, state) => const TodayPage(),
      ), // A
      GoRoute(
        path: '/recording',
        redirect: (context, state) =>
            state.extra is! RecordingArgs && !AppConfig.useMock
            ? '/today'
            : null,
        builder: (context, state) => ParentOnlyPage(
          child: RecordingPage(
            args: state.extra is RecordingArgs
                ? state.extra! as RecordingArgs
                : RecordingArgs.demo,
          ),
        ),
      ), // B
      GoRoute(
        path: '/parent-answer',
        builder: (context, state) =>
            const ParentOnlyPage(child: ParentAnswerPage()),
      ), // B: 부모가 자녀의 글과 TTS를 확인
      GoRoute(
        path: '/child-answer',
        // 실제 API 모드에서 args 없이 들어오면 홈으로 돌려보낸다.
        redirect: (context, state) =>
            state.extra == null && !AppConfig.useMock ? '/today' : null,
        builder: (context, state) => ChildAnswerPage(
          args: state.extra as ChildAnswerArgs? ?? ChildAnswerArgs.demo,
        ),
      ), // C
      GoRoute(
        path: '/stories',
        builder: (context, state) => const StoriesPage(),
        routes: [
          GoRoute(
            path: 'calendar',
            // 월별 조회가 확정되기 전 실제 서버에서는 열지 않는다.
            redirect: (context, state) =>
                AppConfig.storiesMonthApi ? null : '/stories',
            builder: (context, state) => const StoriesCalendarPage(),
          ),
        ],
      ), // C
    ],
  );
});
