import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/choice_dialog.dart';
import '../../../core/widgets/note_paper.dart';
import '../../../core/widgets/step_layout.dart';
import '../../onboarding/presentation/session.dart';
import '../domain/answer_validator.dart';
import 'child_answer_args.dart';
import 'child_answer_controller.dart';
import 'widgets/answer_input.dart';
import 'widgets/answer_submitted_view.dart';
import 'widgets/question_card.dart';

class ChildAnswerPage extends ConsumerStatefulWidget {
  const ChildAnswerPage({super.key, required this.args});
  final ChildAnswerArgs args;

  @override
  ConsumerState<ChildAnswerPage> createState() => _ChildAnswerPageState();
}

class _ChildAnswerPageState extends ConsumerState<ChildAnswerPage> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    final draft = ref
        .read(childAnswerDraftProvider)
        .remove(widget.args.assignmentId);
    _text = TextEditingController(text: draft ?? widget.args.initialText ?? '');
    _text.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    ref.read(childAnswerControllerProvider.notifier).clearFieldError();
    setState(() {}); // 글자 수·버튼 활성 상태 갱신
  }

  /// 마지막으로 서버에 저장된 텍스트 (없으면 빈 문자열)
  String _savedText(ChildAnswerSubmitState s) =>
      s.result?.text ?? widget.args.initialText ?? '';

  /// 저장 안 된 변경이 있는지
  bool _isDirty(ChildAnswerSubmitState s) =>
      s.status != SubmitStatus.success &&
      AnswerValidator.normalize(_text.text) !=
          AnswerValidator.normalize(_savedText(s));

  void _submit() {
    FocusScope.of(context).unfocus(); // 키보드 내리기
    ref
        .read(childAnswerControllerProvider.notifier)
        .submit(assignmentId: widget.args.assignmentId, text: _text.text);
  }

  void _goHome() => context.go('/today');

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      _goHome();
    }
  }

  /// Figma WF-019 이탈 확인: 저장하지 않은 글이 있으면 한 번 더 묻는다.
  Future<void> _confirmLeave() async {
    final editing = _isEditing(ref.read(childAnswerControllerProvider));
    final leave = await showChoiceDialog(
      context,
      title: editing ? '고친 내용이 저장되지 않았어요' : '쓴 내용이 저장되지 않았어요',
      message: editing
          ? '고친 내용을 잃고 싶지 않다면\n계속 고치기를 눌러주세요'
          : '쓴 내용을 잃고 싶지 않다면\n계속 쓰기를 눌러주세요',
      stayLabel: editing ? '계속 고치기' : '계속 쓰기',
      leaveLabel: '나가기',
    );
    if (leave && mounted) _leave();
  }

  /// 헤더 `이전`과 수정 화면의 `취소`
  void _onBack() {
    final s = ref.read(childAnswerControllerProvider);
    if (s.isSubmitting) return;
    if (_isDirty(s)) {
      _confirmLeave();
    } else {
      _leave();
    }
  }

  bool _isEditing(ChildAnswerSubmitState s) =>
      widget.args.isEditing || s.result != null;

  /// 실패로 바뀌는 순간 한 번만 스낵바를 띄운다.
  void _onStateChanged(
    ChildAnswerSubmitState? prev,
    ChildAnswerSubmitState next,
  ) {
    if (next.status != SubmitStatus.failure) return;
    if (prev?.status == SubmitStatus.failure) return;

    if (next.isSessionExpired) {
      ref.read(childAnswerDraftProvider)[widget.args.assignmentId] = _text.text;
      handleSessionExpired(context, ref, ApiException(statusCode: 401));
      return;
    }

    final message = next.errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            action: next.isLocked
                ? null
                : SnackBarAction(label: '다시 시도', onPressed: _submit),
          ),
        );
    }
    if (next.isLocked) _goHome(); // 공개 상태는 홈이 다시 조회한다
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(childAnswerControllerProvider, _onStateChanged);
    final s = ref.watch(childAnswerControllerProvider);

    // 제출 완료 (Figma WF-018 전송 완료)
    if (s.status == SubmitStatus.success && s.result != null) {
      return Scaffold(
        body: SafeArea(
          child: AnswerSubmittedView(
            answerText: s.result!.text,
            onHome: _goHome,
            onEdit: () {
              _text.text = s.result!.text;
              ref.read(childAnswerControllerProvider.notifier).startEditing();
            },
          ),
        ),
      );
    }

    final isEditing = _isEditing(s);
    final isValid =
        AnswerValidator.validate(_text.text) == AnswerValidation.valid;
    final dirty = _isDirty(s);
    // 수정 모드에서는 내용이 바뀌었을 때만 보낼 수 있다.
    final canSubmit = isValid && !s.isSubmitting && (!isEditing || dirty);

    return PopScope(
      canPop: !dirty || s.isSubmitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        body: SafeArea(
          child: s.isSubmitting
              ? _sending(isEditing)
              : isEditing
              ? _editing(s, canSubmit)
              : _writing(s, canSubmit),
        ),
      ),
    );
  }

  /// Figma WF-017 새 답변 작성
  Widget _writing(ChildAnswerSubmitState s, bool canSubmit) {
    return StepLayout(
      onBack: _onBack,
      actions: [
        FilledButton(
          onPressed: canSubmit ? _submit : null,
          child: const Text('보내기'),
        ),
      ],
      children: [
        QuestionCard(questionText: widget.args.questionText),
        const SizedBox(height: 24),
        AnswerInput(controller: _text, serverErrorText: s.fieldErrorMessage),
      ],
    );
  }

  /// Figma WF-019 제출 후 수정
  Widget _editing(ChildAnswerSubmitState s, bool canSubmit) {
    return StepLayout(
      onBack: _onBack,
      actions: [
        FilledButton(
          onPressed: canSubmit ? _submit : null,
          child: const Text('저장하기'),
        ),
        OutlinedButton(onPressed: _onBack, child: const Text('취소')),
      ],
      children: [
        Text(
          '답변을 고치고 있어요',
          style: AppText.headingL.copyWith(color: AppColors.textBrand),
        ),
        const SizedBox(height: 24),
        AnswerInput(controller: _text, serverErrorText: s.fieldErrorMessage),
        const SizedBox(height: 24),
        const Text('고친 내용은 저장해야 반영돼요', style: AppText.bodyS),
      ],
    );
  }

  /// Figma WF-018 전송 중
  Widget _sending(bool isEditing) {
    return StepLayout(
      actions: const [FilledButton(onPressed: null, child: Text('보내는 중이에요'))],
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            isEditing ? '고친 답변을 저장하고 있어요' : '답변을 보내고 있어요',
            style: AppText.headingL.copyWith(color: AppColors.textBrand),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '잠시만 기다려 주세요',
          style: AppText.bodyL.copyWith(color: AppColors.textSub),
        ),
        const SizedBox(height: 24),
        NotePaper(label: '내 답변', text: _text.text),
      ],
    );
  }
}
