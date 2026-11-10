import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/retry_policy.dart';
import '../data/stories_providers.dart';
import '../domain/story.dart';

/// 달력 한 달치 이야기. [month]는 `YYYY-MM`.
final storiesMonthProvider = FutureProvider.autoDispose
    .family<List<Story>, String>(
      (ref, month) => ref.read(storiesRepositoryProvider).fetchMonth(month),
      retry: retryTransientOnly,
    );
