import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/retry_policy.dart';
import '../data/pairing_providers.dart';
import '../domain/pairing_repository.dart';

/// 자녀 화면에 보여줄 초대 코드
final invitationProvider = FutureProvider.autoDispose<Invitation>(
  (ref) => ref.read(pairingRepositoryProvider).createInvitation(),
  retry: retryTransientOnly,
);

/// 부모의 코드 입력 요청 상태. 연결에 성공하면 true.
class JoinController extends Notifier<AsyncValue<bool>> {
  @override
  AsyncValue<bool> build() => const AsyncData(false);

  Future<void> join(String inviteCode) async {
    if (state.isLoading) return;

    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await ref.read(pairingRepositoryProvider).join(inviteCode);
      return true;
    });
    if (!ref.mounted) return;
    state = result;
  }

  void clearError() {
    if (state.hasError) state = const AsyncData(false);
  }
}

final joinControllerProvider =
    NotifierProvider.autoDispose<JoinController, AsyncValue<bool>>(
      JoinController.new,
    );

/// 방금 연결됐는지. 연결 완료 화면을 한 번 보여주고 홈으로 보낸다.
class JustPaired extends Notifier<bool> {
  @override
  bool build() => false;

  void mark() => state = true;
}

final justPairedProvider = NotifierProvider.autoDispose<JustPaired, bool>(
  JustPaired.new,
);

/// 이미 연결된 상태라 페어링 화면을 건너뛰어야 하는 오류인지 (자녀의 초대 숫자 발급)
bool isAlreadyPaired(Object error) =>
    error is ApiException && error.errorCode == 'ALREADY_PAIRED';

/// 초대 코드 관련 오류를 사용자 문구로 바꾼다.
String pairingErrorMessage(Object error) {
  if (error is! ApiException) return '문제가 생겼어요. 다시 시도해 주세요.';
  switch (error.errorCode) {
    case 'INVITE_CODE_NOT_FOUND':
    case 'VALIDATION_ERROR':
      return '숫자를 다시 확인해 주세요.';
    case 'INVITE_CODE_USED':
      return '이미 사용된 숫자예요. 자녀에게 새 숫자를 받아 주세요.';
    case 'INVITE_CODE_EXPIRED':
      return '시간이 지난 숫자예요. 자녀에게 새 숫자를 받아 주세요.';
    case 'ALREADY_PAIRED': // 숫자를 만든 자녀가 이미 다른 분과 연결됨
      return '이미 다른 분과 연결된 숫자예요. 자녀에게 확인해 주세요.';
    default:
      return error.userMessage;
  }
}
