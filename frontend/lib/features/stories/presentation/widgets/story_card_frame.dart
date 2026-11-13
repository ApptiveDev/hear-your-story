import 'package:flutter/material.dart';

import '../../domain/story.dart';

/// 부모·자녀 카드가 같이 쓰는 틀: 날짜 + 질문 + 역할별 내용
class StoryCardFrame extends StatelessWidget {
  const StoryCardFrame({
    super.key,
    required this.story,
    required this.children,
  });
  final Story story;
  final List<Widget> children;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  /// 2026-09-24 → "9월 24일 목요일"
  static String formatDate(DateTime d) =>
      '${d.month}월 ${d.day}일 ${_weekdays[d.weekday - 1]}요일';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatDate(story.assignedDate),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(story.questionText, style: theme.textTheme.titleLarge),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class AnswerSection extends StatelessWidget {
  const AnswerSection({super.key, required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(text, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

/// 부모 답을 화면에 보여줄 글로 바꾼다: 정리본 → 원문 → 안내 문구.
/// 지워진 답은 서버 안내 문구를 쓰고, 없으면 기본 문구를 쓴다.
String parentAnswerText(StoryParentAnswer parent) {
  if (parent.isDeleted) {
    return parent.processingNotice ?? deletedParentAnswerText;
  }
  final text = parent.displayText;
  if (text != null) return text;
  if (parent.isProcessing) return '글로 정리하고 있어요.';
  return '목소리로 남긴 답이에요.';
}

/// 자녀 답을 화면에 보여줄 글로 바꾼다. 지워진 답은 안내 문구로 대신한다.
String childAnswerText(StoryChildAnswer child) {
  final text = child.text;
  if (child.isDeleted || text == null) return deletedChildAnswerText;
  return text;
}

/// 서버 안내 문구가 없을 때 쓰는 기본 문구
const deletedParentAnswerText = '부모님이 이 음성 기록을 삭제했어요.';
const deletedChildAnswerText = '삭제된 답이에요.';

/// 지우기 전에 보여주는 영향 범위 안내
const parentDeleteConfirmMessage =
    '목소리와 받아쓴 글, 정리된 글이 모두 지워져요.\n'
    '질문과 자녀의 답은 그대로 남아요.\n'
    '지운 녹음은 되돌릴 수 없어요.';
const childDeleteConfirmMessage =
    '내가 쓴 답과 부모님께 들려드린 목소리가 지워져요.\n'
    '질문과 부모님의 답은 그대로 남아요.\n'
    '지운 답은 되돌릴 수 없어요.';
