import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
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
    _text = TextEditingController(text: widget.args.initialText ?? '');
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

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('작성을 그만둘까요?'),
        content: const Text('지금 나가면 작성 중인 답변이 저장되지 않아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 쓰기'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) _leave();
  }

  /// 실패로 바뀌는 순간 한 번만 스낵바를 띄운다.
  void _onStateChanged(
    ChildAnswerSubmitState? prev,
    ChildAnswerSubmitState next,
  ) {
    if (next.status != SubmitStatus.failure) return;
    if (prev?.status == SubmitStatus.failure) return;

    if (next.isSessionExpired) {
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

    // 제출 완료
    if (s.status == SubmitStatus.success && s.result != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('오늘의 답변')),
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

    // 작성 / 수정
    final isEditing = widget.args.isEditing || s.result != null;
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
        appBar: AppBar(title: Text(isEditing ? '답변 수정' : '오늘의 답변')),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  children: [
                    QuestionCard(questionText: widget.args.questionText),
                    const SizedBox(height: 24),
                    AnswerInput(
                      controller: _text,
                      enabled: !s.isSubmitting,
                      serverErrorText: s.fieldErrorMessage,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: FilledButton(
                  onPressed: canSubmit ? _submit : null,
                  child: s.isSubmitting
                      ? const SizedBox.square(
                          dimension: 28,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : Text(isEditing ? '수정 완료' : '답변 보내기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
