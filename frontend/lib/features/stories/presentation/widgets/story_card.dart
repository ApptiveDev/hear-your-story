import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../onboarding/data/auth_providers.dart';
import '../../../onboarding/domain/app_user.dart';
import '../../domain/story.dart';
import 'child_story_card.dart';
import 'parent_story_card.dart';

/// 로그인한 사람의 역할에 맞는 카드를 보여준다.
class StoryCard extends ConsumerWidget {
  const StoryCard({super.key, required this.story});
  final Story story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserProvider).value?.role;
    // 역할을 아직 모르면 부모 전용 API를 부르지 않는 자녀 카드로 둔다.
    return role == UserRole.parent
        ? ParentStoryCard(story: story)
        : ChildStoryCard(story: story);
  }
}

/// 듣기 영역을 그려야 하는지.
bool hasStoryAudio(Story story, UserRole? role) => role == UserRole.parent
    ? hasParentStoryAudio(story)
    : hasChildStoryAudio(story);

/// 역할에 맞는 듣기 영역: 부모는 자녀 답 TTS, 자녀는 부모님 원본 목소리.
class StoryAudio extends ConsumerWidget {
  const StoryAudio({super.key, required this.story});
  final Story story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserProvider).value?.role;
    return role == UserRole.parent
        ? ParentStoryAudio(story: story)
        : ChildStoryAudio(story: story);
  }
}
