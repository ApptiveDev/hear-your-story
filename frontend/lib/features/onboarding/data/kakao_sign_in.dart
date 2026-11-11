import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../../core/config/app_config.dart';

/// 사용자가 카카오 로그인 창을 닫았다. 오류 안내 없이 원래 화면에 머문다.
class KakaoSignInCancelled implements Exception {
  const KakaoSignInCancelled();
}

/// 카카오 로그인에 실패했다. [cause]는 문의·디버깅용이고 화면에 보여주지 않는다.
class KakaoSignInFailed implements Exception {
  const KakaoSignInFailed(this.cause);
  final Object? cause;

  @override
  String toString() => 'KakaoSignInFailed($cause)';
}

/// 카카오 계정으로 본인 확인을 하고 OIDC id token을 받는다.
///
/// 서버가 id token을 검증해 우리 서비스 토큰을 준다. 카카오 access token은 앱에서
/// 쓰지 않으므로 서버로 보내지 않는다.
abstract class KakaoSignIn {
  /// 실패하면 [KakaoSignInCancelled]나 [KakaoSignInFailed]를 던진다.
  Future<String> signIn();

  /// 카카오 SDK에 남은 로그인 정보를 지운다. 실패해도 던지지 않는다.
  Future<void> signOut();
}

class KakaoSdkSignIn implements KakaoSignIn {
  @override
  Future<String> signIn() async {
    if (AppConfig.kakaoNativeAppKey.isEmpty) {
      throw const KakaoSignInFailed('KAKAO_NATIVE_APP_KEY 없이 빌드했다');
    }
    final OAuthToken token;
    try {
      token = await _login();
    } on KakaoSignInCancelled {
      rethrow;
    } on Object catch (e) {
      if (_isCancel(e)) throw const KakaoSignInCancelled();
      throw KakaoSignInFailed(e);
    }
    final idToken = token.idToken;
    if (idToken == null) {
      // 카카오 개발자 콘솔에서 OpenID Connect를 켜지 않으면 id token이 오지 않는다
      throw const KakaoSignInFailed('id token이 없다 (OpenID Connect 설정 확인)');
    }
    return idToken;
  }

  /// 카카오톡이 있으면 카카오톡으로, 없거나 카카오톡 로그인이 안 되면 카카오 계정으로.
  Future<OAuthToken> _login() async {
    if (!await isKakaoTalkInstalled()) {
      return UserApi.instance.loginWithKakaoAccount();
    }
    try {
      return await UserApi.instance.loginWithKakaoTalk();
    } on Object catch (e) {
      if (_isCancel(e)) throw const KakaoSignInCancelled();
      // 카카오톡에 연결된 계정이 없는 경우 등은 카카오 계정 로그인으로 다시 시도한다
      return UserApi.instance.loginWithKakaoAccount();
    }
  }

  static bool _isCancel(Object e) =>
      (e is PlatformException && e.code == 'CANCELED') ||
      (e is KakaoClientException && e.reason == ClientErrorCause.cancelled);

  @override
  Future<void> signOut() async {
    if (AppConfig.kakaoNativeAppKey.isEmpty) return;
    try {
      await UserApi.instance.logout();
    } on Object {
      // 카카오 쪽 토큰이 이미 만료됐어도 우리 앱 로그아웃은 계속한다
    }
  }
}

/// 카카오 앱 키 없이 화면과 서버 흐름을 확인하는 가짜 로그인.
class FakeKakaoSignIn implements KakaoSignIn {
  /// 다른 결과를 볼 때: --dart-define=MOCK_KAKAO_SIGN_IN=CANCELLED
  /// 지원 값: OK(기본), CANCELLED, FAILED
  static const _scenario = String.fromEnvironment(
    'MOCK_KAKAO_SIGN_IN',
    defaultValue: 'OK',
  );

  @override
  Future<String> signIn() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    switch (_scenario) {
      case 'CANCELLED':
        throw const KakaoSignInCancelled();
      case 'FAILED':
        throw const KakaoSignInFailed('가짜 실패');
    }
    return 'fake-kakao-id-token';
  }

  @override
  Future<void> signOut() async {}
}

final kakaoSignInProvider = Provider<KakaoSignIn>(
  (ref) => AppConfig.kakaoFakeLogin ? FakeKakaoSignIn() : KakaoSdkSignIn(),
);
