import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/onboarding/data/user_storage.dart';
import 'package:life_record/features/onboarding/domain/app_user.dart';
import 'package:life_record/features/pairing/data/pairing_repository_impl.dart';

import 'fake_pairing_data_source.dart';

const _child = AppUser(
  id: 'usr_child',
  name: '김민지',
  role: UserRole.child,
  pairingStatus: PairingStatus.unpaired,
);

void main() {
  late UserStorage userStorage;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    userStorage = UserStorage(const FlutterSecureStorage());
    await userStorage.save(_child);
  });

  test('초대 코드와 만료 시각을 읽는다', () async {
    final repo = PairingRepositoryImpl(FakePairingDataSource(), userStorage);

    final invitation = await repo.createInvitation();

    expect(invitation.inviteCode, '482913');
    expect(invitation.expiresAt, DateTime.parse('2099-09-26T21:10:00+09:00'));
  });

  test('연결에 성공하면 저장된 사용자를 PAIRED로 바꾼다', () async {
    final dataSource = FakePairingDataSource();
    final repo = PairingRepositoryImpl(dataSource, userStorage);

    await repo.join('482913');

    expect(dataSource.joinedCodes, ['482913']);
    expect((await userStorage.read())?.isPaired, isTrue);
  });

  test('아직 연결 전이면 저장된 사용자를 바꾸지 않는다', () async {
    final repo = PairingRepositoryImpl(
      FakePairingDataSource(pairedAfterChecks: 2),
      userStorage,
    );

    expect(await repo.isPaired(), isFalse);
    expect((await userStorage.read())?.isPaired, isFalse);

    expect(await repo.isPaired(), isTrue);
    expect((await userStorage.read())?.isPaired, isTrue);
  });

  group('이미 연결됨(ALREADY_PAIRED)을 받으면', () {
    ApiException alreadyPaired() =>
        ApiException(statusCode: 409, errorCode: 'ALREADY_PAIRED');

    test('부모가 실제로 연결돼 있으면 성공으로 본다', () async {
      final repo = PairingRepositoryImpl(
        FakePairingDataSource(joinError: alreadyPaired()),
        userStorage,
      );

      await repo.join('482913');

      expect((await userStorage.read())?.isPaired, isTrue);
    });

    test('자녀가 초대 코드를 받을 때면 연결됨으로 저장하고 오류를 알린다', () async {
      final repo = PairingRepositoryImpl(
        FakePairingDataSource(invitationError: alreadyPaired()),
        userStorage,
      );

      await expectLater(repo.createInvitation(), throwsA(isA<ApiException>()));
      expect((await userStorage.read())?.isPaired, isTrue);
    });

    test('자녀가 다른 분과 연결된 숫자면 오류를 그대로 알린다', () async {
      final repo = PairingRepositoryImpl(
        FakePairingDataSource(
          joinError: alreadyPaired(),
          pairedAfterChecks: 99,
        ),
        userStorage,
      );

      await expectLater(
        repo.join('482913'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            'ALREADY_PAIRED',
          ),
        ),
      );
      expect((await userStorage.read())?.isPaired, isFalse);
    });
  });
}
