import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/core/storage/token_storage.dart';
import 'package:life_record/features/onboarding/data/auth_repository_impl.dart';
import 'package:life_record/features/onboarding/data/device_id_storage.dart';
import 'package:life_record/features/onboarding/data/user_storage.dart';
import 'package:life_record/features/onboarding/domain/app_user.dart';

import 'fake_auth_data_source.dart';

void main() {
  const secure = FlutterSecureStorage();
  late FakeAuthDataSource dataSource;
  late TokenStorage tokenStorage;
  late UserStorage userStorage;
  late AuthRepositoryImpl repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    dataSource = FakeAuthDataSource();
    tokenStorage = TokenStorage(secure);
    userStorage = UserStorage(secure);
    repository = AuthRepositoryImpl(
      dataSource: dataSource,
      deviceIdStorage: DeviceIdStorage(secure),
      tokenStorage: tokenStorage,
      userStorage: userStorage,
    );
  });

  test('가입하면 토큰과 사용자 정보를 저장한다', () async {
    final user = await repository.signUp(name: '김민지', role: UserRole.child);

    expect(user.name, '김민지');
    expect(user.role, UserRole.child);
    expect(user.isPaired, isFalse);
    expect(await tokenStorage.read(), 'token_for_김민지');

    final saved = await userStorage.read();
    expect(saved?.id, 'usr_test');
    expect(saved?.role, UserRole.child);
  });

  test('이름 앞뒤 공백을 지우고 역할을 API 값으로 보낸다', () async {
    await repository.signUp(name: '  김영희 ', role: UserRole.parent);

    expect(dataSource.requests.single['name'], '김영희');
    expect(dataSource.requests.single['role'], 'PARENT');
  });

  test('다시 가입해도 같은 기기 ID를 보낸다', () async {
    await repository.signUp(name: '김영희', role: UserRole.parent);
    await repository.signUp(name: '김영희', role: UserRole.parent);

    final ids = dataSource.requests.map((r) => r['deviceId']).toSet();
    expect(ids, hasLength(1));
  });

  test('저장된 사용자 정보가 손상되면 비우고 null을 돌려준다', () async {
    FlutterSecureStorage.setMockInitialValues({'current_user': '{broken'});

    expect(await userStorage.read(), isNull);
    expect(await secure.read(key: 'current_user'), isNull);
  });

  group('서버에서 사용자 다시 받기 (GET /users/me)', () {
    const cached = AppUser(
      id: 'usr_test',
      name: '김민지',
      role: UserRole.child,
      pairingStatus: PairingStatus.paired,
    );
    Map<String, dynamic> me({String pairingStatus = 'UNPAIRED'}) => {
      'id': 'usr_test',
      'name': '김민지',
      'role': 'CHILD',
      'pairingStatus': pairingStatus,
    };

    setUp(() async {
      await tokenStorage.save('token');
      await userStorage.save(cached);
    });

    test('서버가 알려준 상태로 바꿔 저장한다', () async {
      dataSource.me = me();

      final user = await repository.restoreUser(cached: cached);

      expect(user.isPaired, isFalse);
      expect((await userStorage.read())?.isPaired, isFalse);
    });

    test('로그인이 끝났으면(401) 에러를 그대로 알리고 저장된 정보는 두고 간다', () async {
      dataSource.meError = ApiException(statusCode: 401);

      await expectLater(
        repository.restoreUser(cached: cached),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      // 지우는 일은 SessionExpiry가 안내와 함께 한다
      expect((await userStorage.read())?.isPaired, isTrue);
    });

    for (final (label, error) in [
      ('인터넷이 끊기면', ApiException()),
      ('서버 오류(503)면', ApiException(statusCode: 503)),
      ('아직 없는 API(404)면', ApiException(statusCode: 404)),
    ]) {
      test('$label 저장된 정보로 들어간다', () async {
        dataSource.meError = error;

        final user = await repository.restoreUser(cached: cached);

        expect(user, same(cached));
        expect((await userStorage.read())?.isPaired, isTrue);
      });
    }

    test('응답 모양이 다르면 저장된 정보로 들어간다', () async {
      dataSource.me = {'id': 'usr_test', 'role': 'ADMIN'};

      final user = await repository.restoreUser(cached: cached);

      expect(user, same(cached));
      expect((await userStorage.read())?.isPaired, isTrue);
    });

    // testWidgets는 가짜 시계로 돌아서 5초를 실제로 기다리지 않는다
    testWidgets('서버가 오래 답하지 않으면 기다리지 않고 저장된 정보로 들어간다', (tester) async {
      dataSource
        ..me = me()
        ..meGate = Completer<void>().future; // 끝나지 않는 요청
      AppUser? user;
      unawaited(repository.restoreUser(cached: cached).then((u) => user = u));

      await tester.pump(const Duration(seconds: 4));
      expect(user, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(user, same(cached));
    });

    test('기다리는 사이 로그아웃하면 사용자 정보를 되살리지 않는다', () async {
      final gate = Completer<void>();
      dataSource
        ..me = me()
        ..meGate = gate.future;

      final restoring = repository.restoreUser(cached: cached);
      await pumpEventQueue();
      await tokenStorage.clear();
      await userStorage.clear();
      gate.complete();
      await restoring;

      expect(await userStorage.read(), isNull);
    });
  });
}
