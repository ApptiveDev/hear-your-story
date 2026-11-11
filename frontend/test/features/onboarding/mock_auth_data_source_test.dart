import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/onboarding/data/auth_data_source.dart';
import 'package:life_record/features/onboarding/data/user_storage.dart';
import 'package:life_record/features/onboarding/domain/app_user.dart';

void main() {
  const secure = FlutterSecureStorage();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Mock GET /users/me는 기기에 저장된 사용자를 서버 응답처럼 돌려준다', () async {
    final storage = UserStorage(secure);
    await storage.save(
      const AppUser(
        id: 'usr_test',
        name: '김민지',
        role: UserRole.child,
        pairingStatus: PairingStatus.paired,
      ),
    );

    final json = await MockAuthDataSource(storage).fetchMe();

    expect(AppUser.fromJson(json).toJson(), {
      'id': 'usr_test',
      'name': '김민지',
      'role': 'CHILD',
      'pairingStatus': 'PAIRED',
    });
  });

  test('Mock GET /users/me는 가입 전이면 서버처럼 401을 준다', () async {
    await expectLater(
      MockAuthDataSource(UserStorage(secure)).fetchMe(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
  });
}
