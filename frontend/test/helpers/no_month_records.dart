import 'package:life_record/features/stories/data/stories_providers.dart';

import '../features/stories/fake_stories_repository.dart';

/// 홈 "N월 기록"이 Mock의 지연 타이머를 남기지 않도록 빈 달을 돌려주는 override.
final noMonthRecords = storiesRepositoryProvider.overrideWithValue(
  FakeStoriesRepository({}),
);
