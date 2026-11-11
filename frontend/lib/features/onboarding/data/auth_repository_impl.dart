import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import 'auth_data_source.dart';
import 'device_id_storage.dart';
import 'sign_up_response.dart';
import 'user_storage.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this._dataSource,
    required this._deviceIdStorage,
    required this._tokenStorage,
    required this._userStorage,
  });

  final AuthDataSource _dataSource;
  final DeviceIdStorage _deviceIdStorage;
  final TokenStorage _tokenStorage;
  final UserStorage _userStorage;

  /// 앱을 켤 때 서버 응답을 기다리는 최대 시간. 넘으면 저장된 정보로 들어간다.
  static const restoreTimeout = Duration(seconds: 5);

  @override
  Future<AppUser> signUp({required String name, required UserRole role}) async {
    final deviceId = await _deviceIdStorage.getOrCreate();
    final json = await _dataSource.signUp(
      name: name.trim(),
      role: role.apiValue,
      deviceId: deviceId,
    );
    final response = SignUpResponse.fromJson(json);

    await _tokenStorage.save(response.accessToken);
    await _userStorage.save(response.user);
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
}
