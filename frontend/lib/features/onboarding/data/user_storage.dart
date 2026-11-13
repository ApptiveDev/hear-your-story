import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/app_user.dart';

/// 로그인한 사용자 정보. 앱 재실행 때 역할과 페어링 여부를 알기 위해 저장해 둔다.
/// 카카오 로그인을 켜면 앱을 켤 때 `GET /users/me`로 새로 받아 덮어쓰고,
/// 인터넷이 없을 때는 이 값으로 들어간다.
class UserStorage {
  UserStorage(this._storage);
  final FlutterSecureStorage _storage;
  static const _key = 'current_user';

  Future<void> save(AppUser user) =>
      _storage.write(key: _key, value: jsonEncode(user.toJson()));

  Future<AppUser?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      // 저장 형식이 바뀌었거나 손상되면 다시 가입하게 한다.
      await clear();
      return null;
    }
  }

  Future<void> clear() => _storage.delete(key: _key);
}
