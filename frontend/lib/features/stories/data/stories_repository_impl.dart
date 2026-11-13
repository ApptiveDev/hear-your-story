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
    final json = await _dataSource.fetchStories(
      cursor: cursor,
      limit: pageSize,
    );
    return StoriesDto.pageFromJson(json);
  }

  @override
  Future<List<Story>> fetchMonth(String month) async {
    final json = await _dataSource.fetchStoriesByMonth(month);
    return StoriesDto.pageFromJson(json).items;
  }

  @override
  Future<void> deleteParentRecording(String recordingId) =>
      _dataSource.deleteRecording(recordingId);

  @override
  Future<void> deleteChildAnswer(String answerId) =>
      _dataSource.deleteAnswer(answerId);
}
