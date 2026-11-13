import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_providers.dart';
import '../data/kakao_sign_in.dart';
import '../domain/login_result.dart';

/// 로그인 진행 단계. 계약 5.14의 VERIFYING → RESTORING 흐름.
enum LoginPhase {
  idle,

  /// 카카오에서 본인 확인 중
  verifying,

  /// 서버에서 이전 기록을 찾는 중
  restoring,
}

class KakaoLoginState {
  const KakaoLoginState({
    this.phase = LoginPhase.idle,
    this.result,
    this.error,
  });

  final LoginPhase phase;

  /// 서버가 알려준 계정 상태. 로그인 전이거나 창을 닫았으면 null
  final LoginResult? result;
  final Object? error;

  bool get busy => phase != LoginPhase.idle;

  /// 본인 확인은 됐지만 이전 기록을 찾지 못해 사용자의 선택을 기다린다
  bool get recoveryFailed =>
      result?.recoveryStatus == RecoveryStatus.recoveryFailed;
}

/// 카카오 로그인 요청 상태.
class KakaoLoginController extends Notifier<KakaoLoginState> {
  @override
  KakaoLoginState build() => const KakaoLoginState();

  Future<void> login({bool chooseAccount = false}) async {
    if (state.busy) return; // 연타 방지

    state = const KakaoLoginState(phase: LoginPhase.verifying);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .loginWithKakao(
            chooseAccount: chooseAccount,
            onVerified: () {
              if (ref.mounted) {
                state = const KakaoLoginState(phase: LoginPhase.restoring);
              }
            },
          );
      if (!ref.mounted) return;
      // 기존 계정이면 저장한 사용자로 다시 읽게 한다 (홈·페어링 분기에서 사용)
      if (result.user != null) ref.invalidate(currentUserProvider);
      state = KakaoLoginState(result: result);
    } on KakaoSignInCancelled {
      // 카카오 창을 닫은 것은 오류가 아니다. 안내 없이 처음 상태로 돌아간다
      if (ref.mounted) state = const KakaoLoginState();
    } on Object catch (e) {
      if (ref.mounted) state = KakaoLoginState(error: e);
    }
  }

  /// 이전 기록을 찾지 못했지만 이 카카오 계정으로 새로 시작한다(역할·이름 입력).
  void startFresh() {
    if (!state.recoveryFailed) return;
    state = const KakaoLoginState(
      result: LoginResult(user: null, recoveryStatus: RecoveryStatus.newUser),
    );
  }

  /// 이전 기록을 찾지 못했을 때 다른 카카오 계정으로 다시 로그인한다.
  /// 지금 계정의 토큰을 지우고 카카오 계정 선택부터 다시 한다.
  Future<void> useOtherAccount() async {
    if (state.busy) return;
    state = const KakaoLoginState(phase: LoginPhase.verifying);
    await ref.read(authRepositoryProvider).logout();
    if (!ref.mounted) return;
    state = const KakaoLoginState();
    await login(chooseAccount: true);
  }
}

final kakaoLoginControllerProvider =
    NotifierProvider.autoDispose<KakaoLoginController, KakaoLoginState>(
      KakaoLoginController.new,
    );
