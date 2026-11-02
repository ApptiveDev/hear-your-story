import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../today/presentation/today_provider.dart';
import '../data/child_answer_providers.dart';
import '../domain/answer_validator.dart';
import '../domain/child_answer.dart';

enum SubmitStatus { idle, submitting, success, failure }

/// 제출 요청 상태만 가진다. 입력 중인 텍스트는 화면의
/// TextEditingController가 들고 있어서 실패해도 사라지지 않는다.
class ChildAnswerSubmitState {
  const ChildAnswerSubmitState({
    this.status = SubmitStatus.idle,
    this.result,
    this.errorMessage,
    this.fieldErrorMessage,
    this.isLocked = false,
    this.isSessionExpired = false,
  });

  final SubmitStatus status;

  /// 마지막으로 성공한 제출 결과. 수정 모드로 돌아가도 유지한다.
  final ChildAnswer? result;

  /// 스낵바로 보여줄 안내 문구
  final String? errorMessage;

  /// 입력창 아래에 보여줄 서버 검증 문구
  final String? fieldErrorMessage;

  /// 409 ANSWER_LOCKED: 이미 공개되어 수정할 수 없음
  final bool isLocked;

  /// 401: 로그인이 만료되어 화면이 가입 화면으로 보낸다
  final bool isSessionExpired;

  bool get isSubmitting => status == SubmitStatus.submitting;
}

class ChildAnswerController extends Notifier<ChildAnswerSubmitState> {
  static const lockedMessage = '이미 공개된 답변은 수정할 수 없어요.';
  static const validationMessage = '답변은 1자 이상 1000자 이하로 적어 주세요.';
  static const unknownMessage = '문제가 생겼어요. 다시 시도해 주세요.';

  @override
  ChildAnswerSubmitState build() => const ChildAnswerSubmitState();

  Future<void> submit({
    required String assignmentId,
    required String text,
  }) async {
    if (state.isSubmitting) return; // 중복 탭 방지
    if (AnswerValidator.validate(text) != AnswerValidation.valid) return;

    state = ChildAnswerSubmitState(
      status: SubmitStatus.submitting,
      result: state.result,
    );

    try {
      final answer = await ref
          .read(childAnswerRepositoryProvider)
          .submit(assignmentId: assignmentId, text: text);
      if (!ref.mounted) return; // 기다리는 사이 화면이 닫혔으면 무시
      state = ChildAnswerSubmitState(
        status: SubmitStatus.success,
        result: answer,
      );
      // 홈이 새 제출 상태를 다시 불러오게 한다 ("홈으로"는 go라서 홈 화면이 재사용됨)
      ref.invalidate(todayProvider);
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = _failureFrom(e);
      // 이미 공개된 답이면 화면이 홈으로 보내므로 홈도 공개 상태로 갱신
      if (state.isLocked) ref.invalidate(todayProvider);
    } catch (_) {
      if (!ref.mounted) return;
      state = ChildAnswerSubmitState(
        status: SubmitStatus.failure,
        result: state.result,
        errorMessage: unknownMessage,
      );
    }
  }

  /// 제출 완료 화면에서 "답변 수정하기"를 눌렀을 때
  void startEditing() {
    state = ChildAnswerSubmitState(result: state.result);
  }

  /// 입력이 바뀌면 이전 서버 검증 문구를 지운다.
  void clearFieldError() {
    if (state.fieldErrorMessage == null) return;
    state = ChildAnswerSubmitState(
      status: state.status,
      result: state.result,
      errorMessage: state.errorMessage,
      isLocked: state.isLocked,
    );
  }

  ChildAnswerSubmitState _failureFrom(ApiException e) {
    if (e.statusCode == 401) {
      return ChildAnswerSubmitState(
        status: SubmitStatus.failure,
        result: state.result,
        isSessionExpired: true,
      );
    }
    switch (e.errorCode) {
      case 'ANSWER_LOCKED':
        return ChildAnswerSubmitState(
          status: SubmitStatus.failure,
          result: state.result,
          errorMessage: lockedMessage,
          isLocked: true,
        );
      case 'VALIDATION_ERROR':
        return ChildAnswerSubmitState(
          status: SubmitStatus.failure,
          result: state.result,
          fieldErrorMessage: validationMessage,
        );
      default: // 네트워크, 403, 429, 5xx → 공통 안내 문구
        return ChildAnswerSubmitState(
          status: SubmitStatus.failure,
          result: state.result,
          errorMessage: e.userMessage,
        );
    }
  }
}

/// 로그인 만료(401)로 가입 화면에 갔을 때 쓰던 글을 assignmentId별로 잠시 보관한다.
/// 같은 역할로 다시 가입하면 같은 계정·같은 질문으로 돌아오므로 답변 화면이 되살린다.
/// 앱을 끄면 사라진다.
final childAnswerDraftProvider = Provider<Map<String, String>>((ref) => {});

final childAnswerControllerProvider =
    NotifierProvider.autoDispose<ChildAnswerController, ChildAnswerSubmitState>(
      ChildAnswerController.new,
    );
