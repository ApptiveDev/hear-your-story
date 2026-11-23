import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/error_text.dart';
import '../../domain/answer_validator.dart';

/// Figma `Input/TextArea`: 흰 상자 안에 글과 오른쪽 아래 글자 수.
/// 쓰는 중(Typing)에는 주황 굵은 테두리.
///
/// 1000자를 넘겨도 잘라내지 않고 안내만 한다.
/// (붙여넣은 긴 글이 몰래 잘리지 않게)
class AnswerInput extends StatefulWidget {
  const AnswerInput({
    super.key,
    required this.controller,
    this.serverErrorText,
    this.enabled = true,
    this.hintText = '생각나는 대로 편하게 적어 주세요.',
  });

  final TextEditingController controller;
  final String? serverErrorText;
  final bool enabled;
  final String hintText;

  static const tooLongMessage = '${AnswerValidator.maxLength}자까지 적을 수 있어요.';

  @override
  State<AnswerInput> createState() => _AnswerInputState();
}

class _AnswerInputState extends State<AnswerInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final length = AnswerValidator.length(text);
    final tooLong = AnswerValidator.validate(text) == AnswerValidation.tooLong;
    final error = tooLong ? AnswerInput.tooLongMessage : widget.serverErrorText;

    final Color border;
    final double borderWidth;
    if (error != null) {
      border = AppColors.error;
      borderWidth = 2;
    } else if (_focus.hasFocus) {
      border = AppColors.borderPrimary;
      borderWidth = 3;
    } else {
      border = AppColors.borderSoft;
      borderWidth = 2;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: widget.enabled ? _focus.requestFocus : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 220),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(AppRadius.cardSmall),
              border: Border.all(color: border, width: borderWidth),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  minLines: 5,
                  maxLines: 10,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: AppText.bodyL.copyWith(color: AppColors.textStrong),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: AppText.bodyL.copyWith(color: AppColors.textSub),
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$length / ${AnswerValidator.maxLength}',
                  textAlign: TextAlign.right,
                  style: AppText.bodyS.copyWith(
                    color: tooLong ? AppColors.error : AppColors.textSub,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...[const SizedBox(height: 12), ErrorText(error)],
      ],
    );
  }
}
