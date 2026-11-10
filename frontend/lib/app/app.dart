import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/session_expired_signal.dart';
import '../core/theme/app_theme.dart';
import '../features/onboarding/presentation/session.dart';
import 'router.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// 어느 화면에서 난 401이든 여기서 로그인 정보를 지우고 가입 화면으로 보낸다.
  Future<void> _onSessionExpired() async {
    // 화면이 같은 401을 먼저 처리할 수 있게 한 박자 늦춘다. (예: 자녀 답변 화면은
    // 쓰던 글을 childAnswerDraftProvider에 맡긴 뒤 이동해야 한다)
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await ref
        .read(sessionExpiryProvider)
        .expire(
          router: ref.read(routerProvider),
          messenger: _messengerKey.currentState,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionExpiredSignalProvider, (_, _) => _onSessionExpired());
    return MaterialApp.router(
      title: '들려줘요',
      theme: AppTheme.light(),
      scaffoldMessengerKey: _messengerKey,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
