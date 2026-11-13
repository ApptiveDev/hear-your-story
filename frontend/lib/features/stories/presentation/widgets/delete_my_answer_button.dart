import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../onboarding/presentation/session.dart';
import '../story_answer_deleter.dart';

/// 지난 이야기 카드에서 내 답(부모: 녹음, 자녀: 글)을 지우는 버튼.
///
/// 누르면 지워지는 범위를 먼저 보여주고, 확인한 경우에만 지운다.
class DeleteMyAnswerButton extends ConsumerStatefulWidget {
  const DeleteMyAnswerButton({
    super.key,
    required this.label,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.doneMessage,
    required this.onDelete,
  });

  final String label;
  final String confirmTitle;
  final String confirmMessage;
  final String doneMessage;
  final Future<void> Function(StoryAnswerDeleter deleter) onDelete;

  @override
  ConsumerState<DeleteMyAnswerButton> createState() =>
      _DeleteMyAnswerButtonState();
}

class _DeleteMyAnswerButtonState extends ConsumerState<DeleteMyAnswerButton> {
  bool _deleting = false;

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.confirmTitle),
        content: Text(widget.confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // 지운 뒤에는 카드가 바뀌며 이 버튼이 사라지므로 안내할 곳을 미리 잡아 둔다
    final messenger = ScaffoldMessenger.of(context);
    final deleter = ref.read(storyAnswerDeleterProvider);
    setState(() => _deleting = true);
    try {
      await widget.onDelete(deleter);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(widget.doneMessage)));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (await handleSessionExpired(context, ref, e)) return;
      if (e.statusCode == 404) deleter.reloadAll();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_failureMessage(e))));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  static String _failureMessage(ApiException e) {
    if (e.statusCode == 404) return '이미 지워진 기록이에요.';
    if (e.statusCode == 403) return '내가 남긴 기록만 지울 수 있어요.';
    return e.userMessage;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: _deleting ? null : _confirmAndDelete,
        icon: _deleting
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.delete_outline),
        label: Text(widget.label),
      ),
    );
  }
}
