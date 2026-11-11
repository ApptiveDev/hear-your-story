import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_providers.dart';
import '../data/kakao_sign_in.dart';
import '../domain/login_result.dart';

/// 카카오 로그인 요청 상태. 성공하면 서버가 알려준 계정 상태를 담는다.
class KakaoLoginController extends Notifier<AsyncValue<LoginResult?>> {
  @override
  AsyncValue<LoginResult?> build() => const AsyncData(null);

  Future<void> login() async {
    if (state.isLoading) return; // 연타 방지

    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).loginWithKakao(),
    );
    if (!ref.mounted) return;
    // 카카오 창을 닫은 것은 오류가 아니다. 안내 없이 처음 상태로 돌아간다
    if (result.error is KakaoSignInCancelled) {
      state = const AsyncData(null);
      return;
    }
    // 기존 계정이면 저장한 사용자로 다시 읽게 한다 (홈·페어링 분기에서 사용)
    if (result.hasValue) ref.invalidate(currentUserProvider);
    state = result;
  }
}

final kakaoLoginControllerProvider =
    NotifierProvider.autoDispose<
      KakaoLoginController,
      AsyncValue<LoginResult?>
    >(KakaoLoginController.new);
