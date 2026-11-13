import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/core/storage/token_storage.dart';
import 'package:life_record/features/onboarding/data/auth_repository_impl.dart';
import 'package:life_record/features/onboarding/data/user_storage.dart';
import 'package:life_record/features/onboarding/data/kakao_sign_in.dart';
import 'package:life_record/features/onboarding/domain/app_user.dart';
import 'package:life_record/features/onboarding/domain/login_result.dart';

import 'fake_auth_data_source.dart';

void main() {
  const secure = FlutterSecureStorage();
  late FakeAuthDataSource dataSource;
  late TokenStorage tokenStorage;
  late UserStorage userStorage;
  late AuthRepositoryImpl repository;
  late FakeKakao kakao;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    dataSource = FakeAuthDataSource();
    kakao = FakeKakao();
    tokenStorage = TokenStorage(secure);
    userStorage = UserStorage(secure);
    repository = AuthRepositoryImpl(
      dataSource: dataSource,
      tokenStorage: tokenStorage,
      userStorage: userStorage,
      kakaoSignIn: kakao,
    );
  });

  Future<void> prepareRegistration() async {
    dataSource.kakao = kakaoLoginJson(status: 'REGISTRATION_REQUIRED');
    await repository.loginWithKakao();
  }

  test('가입하면 토큰과 사용자 정보를 저장한다', () async {
    await prepareRegistration();
    final user = await repository.signUp(name: '김민지', role: UserRole.child);

    expect(user.name, '김민지');
    expect(user.role, UserRole.child);
    expect(user.isPaired, isFalse);
    expect(await tokenStorage.read(), 'token_for_김민지');
    expect(await tokenStorage.readRefresh(), 'refresh_for_김민지');

    final saved = await userStorage.read();
    expect(saved?.id, 'usr_test');
    expect(saved?.role, UserRole.child);
  });

  test('이름 앞뒤 공백을 지우고 역할을 API 값으로 보낸다', () async {
    await prepareRegistration();
    await repository.signUp(name: '  김영희 ', role: UserRole.parent);

    expect(dataSource.requests.single['name'], '김영희');
    expect(dataSource.requests.single['role'], 'PARENT');
  });

  test('카카오 로그인에서 받은 가입용 token을 가입 요청에만 보낸다', () async {
    await prepareRegistration();
    await repository.signUp(name: '김영희', role: UserRole.parent);

    expect(
      dataSource.requests.single['registrationToken'],
      'registration-token',
    );
    await expectLater(
      repository.signUp(name: '김영희', role: UserRole.parent),
      throwsStateError,
    );
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

  group('카카오 로그인', () {
    test('기존 계정이면 토큰 두 개와 사용자 정보를 저장한다', () async {
      dataSource.kakao = kakaoLoginJson();

      final result = await repository.loginWithKakao();

      expect(result.authStatus, AuthStatus.authenticated);
      expect(result.user?.name, '김영희');
      expect(await tokenStorage.read(), 'kakao-access');
      expect(await tokenStorage.readRefresh(), 'kakao-refresh');
      expect((await userStorage.read())?.id, 'usr_kakao');
    });

    test('카카오 id token만 서버에 보낸다', () async {
      dataSource.kakao = kakaoLoginJson();

      await repository.loginWithKakao();

      final request = dataSource.kakaoRequests.single;
      expect(request['idToken'], 'id-token-1');
      expect(request.containsKey('deviceId'), isFalse);
    });

    test('처음이면 가입용 token만 메모리에 두고 예전 로그인 정보는 지운다', () async {
      await userStorage.save(
        const AppUser(
          id: 'usr_old',
          name: '예전',
          role: UserRole.child,
          pairingStatus: PairingStatus.paired,
        ),
      );
      dataSource.kakao = kakaoLoginJson(status: 'REGISTRATION_REQUIRED');

      final result = await repository.loginWithKakao();

      expect(result.authStatus, AuthStatus.registrationRequired);
      expect(result.user, isNull);
      expect(await tokenStorage.read(), isNull);
      expect(await tokenStorage.readRefresh(), isNull);
      expect(await userStorage.read(), isNull);
    });

    test('처음 로그인 후 가입을 마치면 서비스 token 두 개를 저장한다', () async {
      dataSource.kakao = kakaoLoginJson(status: 'REGISTRATION_REQUIRED');
      await repository.loginWithKakao();

      await repository.signUp(name: '김민지', role: UserRole.child);

      expect(await tokenStorage.read(), 'token_for_김민지');
      expect(await tokenStorage.readRefresh(), 'refresh_for_김민지');
    });

    test('카카오 확인이 끝나면 서버에 묻기 전에 알린다', () async {
      dataSource.kakao = kakaoLoginJson();
      int? requestsWhenVerified;

      await repository.loginWithKakao(
        onVerified: () =>
            requestsWhenVerified = dataSource.kakaoRequests.length,
      );

      expect(kakao.signInCalls, 1);
      expect(requestsWhenVerified, 0);
    });

    test('계정을 고르게 하면 카카오에도 그렇게 요청한다', () async {
      dataSource.kakao = kakaoLoginJson();

      await repository.loginWithKakao(chooseAccount: true);

      expect(kakao.chooseAccount, [true]);
      expect(dataSource.kakaoRequests.single['idToken'], 'id-token-2');
    });

    test('카카오 창을 닫으면 서버에 묻지 않고 아무것도 저장하지 않는다', () async {
      kakao.error = const KakaoSignInCancelled();

      await expectLater(
        repository.loginWithKakao(),
        throwsA(isA<KakaoSignInCancelled>()),
      );
      expect(dataSource.kakaoRequests, isEmpty);
      expect(await tokenStorage.read(), isNull);
    });

    test('서버가 거절하면 아무것도 저장하지 않는다', () async {
      dataSource.kakaoError = ApiException(statusCode: 401);

      await expectLater(
        repository.loginWithKakao(),
        throwsA(isA<ApiException>()),
      );
      expect(await tokenStorage.read(), isNull);
      expect(await tokenStorage.readRefresh(), isNull);
    });

    for (final (label, json) in [
      ('AUTHENTICATED인데 사용자가 없으면', {...kakaoLoginJson(), 'user': null}),
      ('모르는 상태 값이면', kakaoLoginJson(status: 'MERGED')),
      (
        '가입 필요인데 사용자가 있으면',
        {
          ...kakaoLoginJson(status: 'REGISTRATION_REQUIRED'),
          'user': kakaoLoginJson()['user'],
        },
      ),
      ('refresh token이 없으면', {...kakaoLoginJson(), 'refreshToken': null}),
    ]) {
      test('$label 응답 오류로 보고 저장하지 않는다', () async {
        dataSource.kakao = json;

        await expectLater(repository.loginWithKakao(), throwsA(anything));
        expect(await tokenStorage.read(), isNull);
      });
    }

    test('로그아웃하면 서버 token을 폐기하고 로컬 token·사용자를 지운다', () async {
      dataSource.kakao = kakaoLoginJson();
      await repository.loginWithKakao();

      await repository.logout();

      expect(await tokenStorage.read(), isNull);
      expect(await tokenStorage.readRefresh(), isNull);
      expect(await userStorage.read(), isNull);
      expect(dataSource.logoutRequests, ['kakao-refresh']);
      expect(kakao.signOutCalls, 1);
    });

    test('서버 로그아웃이 실패해도 로컬 로그인 정보는 지운다', () async {
      dataSource
        ..kakao = kakaoLoginJson()
        ..logoutError = ApiException();
      await repository.loginWithKakao();

      await repository.logout();

      expect(await tokenStorage.read(), isNull);
      expect(await tokenStorage.readRefresh(), isNull);
      expect(await userStorage.read(), isNull);
      expect(kakao.signOutCalls, 1);
    });
  });
}
