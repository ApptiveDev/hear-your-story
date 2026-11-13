import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/login_result.dart';
import 'auth_data_source.dart';
import 'kakao_login_response.dart';
import 'kakao_sign_in.dart';
import 'sign_up_response.dart';
import 'user_storage.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this._dataSource,
    required this._tokenStorage,
    required this._userStorage,
    required this._kakaoSignIn,
  });

  final AuthDataSource _dataSource;
  final TokenStorage _tokenStorage;
  final UserStorage _userStorage;
  final KakaoSignIn _kakaoSignIn;
  String? _registrationToken;

  /// 앱을 켤 때 서버 응답을 기다리는 최대 시간. 넘으면 저장된 정보로 들어간다.
  static const restoreTimeout = Duration(seconds: 5);

  @override
  Future<AppUser> signUp({required String name, required UserRole role}) async {
    final registrationToken = _registrationToken;
    if (registrationToken == null) {
      throw StateError('카카오 로그인을 다시 진행해 주세요.');
    }
    final json = await _dataSource.signUp(
      name: name.trim(),
      role: role.apiValue,
      registrationToken: registrationToken,
    );
    final response = SignUpResponse.fromJson(json);

    await _tokenStorage.saveTokens(
      access: response.accessToken,
      refresh: response.refreshToken,
    );
    await _userStorage.save(response.user);
    _registrationToken = null;
    return response.user;
  }

  @override
  Future<AppUser> restoreUser({required AppUser cached}) async {
    final AppUser user;
    try {
      final json = await _dataSource.fetchMe().timeout(restoreTimeout);
      user = AppUser.fromJson(json);
    } on Object catch (e) {
      if (e is ApiException && e.statusCode == 401) rethrow;
      return cached;
    }
    // 기다리는 사이 로그인이 끝났으면(로그아웃·만료) 사용자 정보를 되살리지 않는다
    if (await _tokenStorage.read() == null) return user;
    await _userStorage.save(user);
    return user;
  }

  @override
  Future<LoginResult> loginWithKakao({
    bool chooseAccount = false,
    void Function()? onVerified,
  }) async {
    final idToken = await _kakaoSignIn.signIn(chooseAccount: chooseAccount);
    onVerified?.call();
    final response = KakaoLoginResponse.fromJson(
      await _dataSource.loginWithKakao(idToken: idToken),
    );

    final user = response.user;
    if (response.authStatus == AuthStatus.registrationRequired) {
      _registrationToken = response.registrationToken;
      await _tokenStorage.clear();
      // 예전 가입 정보가 남아 있으면 가입 화면이 홈으로 보내 버린다
      await _userStorage.clear();
    } else {
      _registrationToken = null;
      await _tokenStorage.saveTokens(
        access: response.accessToken!,
        refresh: response.refreshToken!,
      );
      await _userStorage.save(user!);
    }
    return response.toResult();
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.readRefresh();
    try {
      if (refreshToken != null) {
        await _dataSource.logout(refreshToken: refreshToken);
      }
    } on Object {
      // 서버 로그아웃 실패와 관계없이 이 기기의 세션은 반드시 정리한다
    } finally {
      _registrationToken = null;
      await _tokenStorage.clear();
      await _userStorage.clear();
      await _kakaoSignIn.signOut();
    }
  }
}
