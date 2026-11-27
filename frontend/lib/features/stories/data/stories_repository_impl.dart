import '../../../core/network/api_exception.dart';
import '../domain/stories_repository.dart';
import '../domain/story.dart';
import 'stories_data_source.dart';
import 'stories_dto.dart';

class StoriesRepositoryImpl implements StoriesRepository {
  StoriesRepositoryImpl(this._dataSource);
  final StoriesDataSource _dataSource;

  /// 계약 기본값 20, 최대 50
  static const pageSize = 20;

  @override
  Future<StoryPage> fetchPage({String? cursor}) async {
    try {
      final json = await _dataSource.fetchStories(
        cursor: cursor,
        limit: pageSize,
      );
      return StoriesDto.pageFromJson(json);
    } on ApiException catch (e) {
      // 한 번도 연결하지 않은 사용자도 책장에 들어올 수 있다.
      if (e.errorCode != 'PAIR_NOT_FOUND') rethrow;
      return const StoryPage(items: [], nextCursor: null, hasNext: false);
    }
  }

  @override
  Future<List<Story>> fetchMonth(String month) async {
    try {
      final json = await _dataSource.fetchStoriesByMonth(month);
      return StoriesDto.pageFromJson(json).items;
    } on ApiException catch (e) {
      if (e.errorCode != 'PAIR_NOT_FOUND') rethrow;
      return const [];
    }
  }

  @override
  Future<void> deleteParentRecording(String recordingId) =>
      _dataSource.deleteRecording(recordingId);

  @override
  Future<void> deleteChildAnswer(String answerId) =>
      _dataSource.deleteAnswer(answerId);
}
