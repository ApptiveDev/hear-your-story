import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_storage.dart';
import '../../onboarding/data/auth_providers.dart';
import '../../onboarding/presentation/session.dart';

/// 로그아웃·탈퇴 뒤 기기에 남은 로그인 정보를 지운다.
///
/// 토큰과 사용자 정보를 함께 지우고, 앱 시작 때 계산한 "갈 곳"도 버린다. 하나라도
/// 남으면 가입 화면이 다시 홈으로 보낸다. `device_id`는 남긴다.
class AccountSession {
  AccountSession(this._ref);
  final Ref _ref;

  Future<void> clear() async {
    await _ref.read(tokenStorageProvider).clear();
    await _ref.read(userStorageProvider).clear();
    _ref.invalidate(currentUserProvider);
    _ref.invalidate(launchDestinationProvider);
  }
}

final accountSessionProvider = Provider<AccountSession>(AccountSession.new);
