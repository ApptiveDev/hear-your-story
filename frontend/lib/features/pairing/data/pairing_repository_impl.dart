import '../../../core/network/api_exception.dart';
import '../../onboarding/data/user_storage.dart';
import '../../onboarding/domain/app_user.dart';
import '../domain/pairing_repository.dart';
import 'pairing_data_source.dart';

class PairingRepositoryImpl implements PairingRepository {
  PairingRepositoryImpl(this._dataSource, this._userStorage);

  final PairingDataSource _dataSource;
  final UserStorage _userStorage;

  @override
  Future<Invitation> createInvitation() async {
    try {
      return Invitation.fromJson(await _dataSource.createInvitation());
    } on ApiException catch (e) {
      // 자녀가 이미 연결돼 있으면 저장해 두고 화면이 홈으로 가게 오류를 그대로 알린다
      if (e.errorCode == 'ALREADY_PAIRED') await _markPaired();
      rethrow;
    }
  }

  @override
  Future<void> join(String inviteCode) async {
    try {
      await _dataSource.join(inviteCode);
    } on ApiException catch (e) {
      // 부모가 이미 연결됐으면 성공과 같다. 숫자를 만든 자녀가 다른 부모와
      // 연결된 경우에도 같은 오류가 오므로 실제 연결 여부를 확인한다.
      if (e.errorCode != 'ALREADY_PAIRED' || !await isPaired()) rethrow;
      return;
    }
    await _markPaired();
  }

  @override
  Future<bool> isPaired() async {
    final paired = await _dataSource.isPaired();
    if (paired) await _markPaired();
    return paired;
  }

  // 앱을 다시 켰을 때 페어링 화면을 건너뛸 수 있게 저장해 둔다.
  Future<void> _markPaired() async {
    final user = await _userStorage.read();
    if (user == null || user.isPaired) return;
    await _userStorage.save(user.copyWith(pairingStatus: PairingStatus.paired));
  }
}
