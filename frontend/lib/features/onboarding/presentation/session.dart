import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_providers.dart';
import 'kakao_login_controller.dart';

/// 앱을 켰을 때 가입 화면 대신 갈 곳. 로그인 정보가 없으면 null(가입 화면 유지).
///
/// 라우터에 redirect를 두지 않고 가입 화면에서 판단한다. 첫 화면이 `/onboarding`이라
/// 결과가 같고, 여러 사람이 함께 고치는 router.dart를 건드리지 않아도 된다.
///
/// 카카오 로그인을 켜면 서버(`GET /users/me`)에서 사용자를 다시 받는다. 상대가 연결을
/// 끊었으면 페어링으로 보낸다. 인터넷이 없으면 저장된 정보로 들어가고, 로그인이
/// 끝났으면(401) 에러로 알려서 가입 화면이 [handleSessionExpired]로 처리한다.
final launchDestinationProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final token = await ref.read(tokenStorageProvider).read();
  var user = await ref.read(currentUserProvider.future);
  if (token == null || user == null) return null;
  user = await ref.read(authRepositoryProvider).restoreUser(cached: user);
  if (!ref.mounted) return null;
  // 홈·페어링 화면이 새로 받은 사용자를 읽게 한다
  ref.invalidate(currentUserProvider);
  return user.isPaired ? '/today' : '/pairing';
});

/// 로그인 만료(401) 처리. 토큰·사용자 정보를 지우고 안내를 띄운 뒤 가입 화면으로 보낸다.
///
/// 앱 최상단(`App`)이 Dio interceptor의 신호를 받아 부르고, 화면은
/// [handleSessionExpired]로 부른다. 같은 401을 둘 다 받아도 안내와 이동은 한 번만 한다.
///
/// 토큰과 사용자 정보를 함께 지워야 한다. 사용자 정보만 남으면 가입 화면이 다시
/// 홈으로 보내서 401이 반복된다.
class SessionExpiry {
  SessionExpiry(this._ref);
  final Ref _ref;
  Future<void>? _running;

  Future<void> expire({
    required GoRouter router,
    ScaffoldMessengerState? messenger,
  }) {
    // 여러 요청이 한꺼번에 401을 받으면 먼저 시작한 처리를 함께 기다린다
    return _running ??= _expire(
      router,
      messenger,
    ).whenComplete(() => _running = null);
  }

  Future<void> _expire(
    GoRouter router,
    ScaffoldMessengerState? messenger,
  ) async {
    await clearLocal();

    messenger?.showSnackBar(
      const SnackBar(content: Text('다시 로그인해 주세요.\n같은 카카오 계정이면 이야기가 이어져요.')),
    );
    router.go('/onboarding');
  }

  /// 기기에 남은 로그인 정보만 지운다. 안내·이동은 하지 않는다.
  /// 로그아웃·탈퇴도 같은 정리를 써야 하므로, 지울 것이 늘면 여기에만 더한다.
  Future<void> clearLocal() async {
    await _ref.read(tokenStorageProvider).clear();
    await _ref.read(userStorageProvider).clear();

    // 가입 중 메모리에만 있던 registration token도 함께 버린다.
    _ref.invalidate(authRepositoryProvider);
    
    _ref.invalidate(currentUserProvider);
    // 앱 시작 때 계산한 "갈 곳"이 남아 있으면 가입 화면이 그 값을 다시 쓴다
    _ref.invalidate(launchDestinationProvider);
    // 가입을 마치지 않은 채(역할 선택 중) 만료되면 같은 화면에 머무르므로 로그인 결과도 비운다
    _ref.invalidate(needsKakaoLoginProvider);
    _ref.invalidate(kakaoLoginControllerProvider);
  }
}

/// 카카오 로그인을 켰고 아직 로그인하지 않았는지. 로그인은 했지만 가입(역할·이름)을
/// 마치지 않았으면 false라서 가입 화면이 역할 선택부터 보여준다.
final needsKakaoLoginProvider = FutureProvider.autoDispose<bool>((ref) async {
  return await ref.read(tokenStorageProvider).read() == null;
});

/// 로그아웃. 기기의 로그인 정보를 지우고 가입(로그인) 화면으로 보낸다.
///
/// 화면이 사라진 뒤에도 정리를 마칠 수 있게 시작할 때 container와 router를 잡아 둔다.
Future<void> signOut(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final router = GoRouter.of(context);
  await container.read(authRepositoryProvider).logout();
  container
    ..invalidate(currentUserProvider)
    ..invalidate(launchDestinationProvider)
    ..invalidate(needsKakaoLoginProvider);
  router.go('/onboarding');
}

final sessionExpiryProvider = Provider<SessionExpiry>(SessionExpiry.new);

/// 화면에서 받은 에러가 401이면 [SessionExpiry]로 처리한다. 처리했으면 true.
///
/// 실제 API의 401은 Dio interceptor를 거쳐 앱 최상단이 처리하므로, 화면은 자기 오류
/// 안내 대신 이 함수를 부른다. Mock·테스트처럼 Dio를 거치지 않는 401도 같은 처리를
/// 받는다.
Future<bool> handleSessionExpired(
  BuildContext context,
  WidgetRef ref,
  Object error,
) async {
  if (error is! ApiException || error.statusCode != 401) return false;

  await ref
      .read(sessionExpiryProvider)
      .expire(
        router: GoRouter.of(context),
        messenger: ScaffoldMessenger.maybeOf(context),
      );
  return true;
}
