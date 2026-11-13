import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/stories/data/stories_data_source.dart';
import 'package:life_record/features/stories/data/stories_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // assets 읽기에 필요

  StoriesRepositoryImpl repoFor(String scenario) => StoriesRepositoryImpl(
    MockStoriesDataSource(scenario: scenario, delay: Duration.zero),
  );

  test('계약 예시(first_page)를 그대로 파싱한다', () async {
    final page = await repoFor('first_page').fetchPage();

    expect(page.items, hasLength(1));
    expect(page.hasNext, isFalse);
    expect(page.nextCursor, isNull);

    final story = page.items.single;
    expect(story.questionText, '어릴 때 가장 좋아했던 놀이는 무엇이었나요?');
    expect(story.assignedDate, DateTime(2026, 9, 24));
    expect(story.parentAnswer.displayText, '어린 시절 동네 친구들과 고무줄 놀이를 즐겼어요.');
    expect(story.childAnswer.text, '저는 놀이터에서 숨바꼭질하던 시간이 기억나요.');
  });

  test('availability가 없는 이전 응답은 볼 수 있는 답으로 읽는다', () async {
    final story = (await repoFor('first_page').fetchPage()).items.single;

    expect(story.parentAnswer.isDeleted, isFalse);
    expect(story.childAnswer.isDeleted, isFalse);
  });

  test('삭제된 답(DELETED)이 섞여도 페이지 전체를 파싱한다', () async {
    final page = await repoFor('deleted').fetchPage();

    expect(page.items, hasLength(2));

    final parentDeleted = page.items[0].parentAnswer;
    expect(parentDeleted.isDeleted, isTrue);
    expect(parentDeleted.recordingId, isNull);
    expect(parentDeleted.processingStatus, isNull);
    expect(parentDeleted.originalAudioUrl, isNull);
    expect(parentDeleted.isProcessing, isFalse); // 정리 중으로 보지 않음
    expect(page.items[0].childAnswer.isDeleted, isFalse);

    final childDeleted = page.items[1].childAnswer;
    expect(childDeleted.isDeleted, isTrue);
    expect(childDeleted.answerId, isNull);
    expect(childDeleted.text, isNull);
    expect(childDeleted.isTtsReady, isFalse);
    expect(childDeleted.isTtsProcessing, isFalse);
    expect(page.items[1].parentAnswer.isDeleted, isFalse);
  });

  group('내 답 지우기', () {
    Future<Uri> requestedDelete(
      Future<void> Function(StoriesRepositoryImpl repo) action,
    ) async {
      late RequestOptions requested;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requested = options;
            handler.resolve(Response(requestOptions: options, statusCode: 204));
          },
        ),
      );
      await action(StoriesRepositoryImpl(ApiStoriesDataSource(dio)));
      expect(requested.method, 'DELETE');
      return requested.uri;
    }

    test('부모 녹음은 DELETE /recordings/{recordingId}로 지운다', () async {
      final uri = await requestedDelete(
        (repo) => repo.deleteParentRecording('rec_1'),
      );
      expect(uri.path, '/api/v1/recordings/rec_1');
    });

    test('자녀 답은 DELETE /answers/{answerId}로 지운다', () async {
      final uri = await requestedDelete(
        (repo) => repo.deleteChildAnswer('ans_1'),
      );
      expect(uri.path, '/api/v1/answers/ans_1');
    });

    test('Mock: 지운 쪽만 DELETED로 바뀌고 상대 답은 남는다', () async {
      final repo = repoFor('first_page');
      final before = (await repo.fetchPage()).items.single;

      await repo.deleteParentRecording(before.parentAnswer.recordingId!);
      final after = (await repo.fetchPage()).items.single;

      expect(after.parentAnswer.isDeleted, isTrue);
      expect(after.childAnswer.isDeleted, isFalse);
      expect(after.childAnswer.text, before.childAnswer.text);
    });
  });

  group('월별 조회', () {
    test('이야기가 있는 달을 날짜 오름차순으로 파싱한다', () async {
      final items = await repoFor('first_page').fetchMonth('2026-11');

      expect(items.map((s) => s.assignedDate), [
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 5),
        DateTime(2026, 11, 18),
      ]);
    });

    test('이야기가 없는 달은 빈 목록이다', () async {
      expect(await repoFor('first_page').fetchMonth('2026-10'), isEmpty);
      expect(await repoFor('empty').fetchMonth('2026-11'), isEmpty);
    });

    test('연결 실패를 그대로 알린다', () async {
      expect(
        repoFor('NETWORK').fetchMonth('2026-11'),
        throwsA(isA<ApiException>()),
      );
    });

    test('실제 API에는 month만 보내고 cursor·limit은 보내지 않는다', () async {
      late Uri requested;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requested = options.uri;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'items': [], 'nextCursor': null, 'hasNext': false},
              ),
            );
          },
        ),
      );

      await StoriesRepositoryImpl(ApiStoriesDataSource(dio))
          .fetchMonth('2026-11');

      expect(requested.path, '/api/v1/stories');
      expect(requested.queryParameters, {'month': '2026-11'});
    });
  });

  test('paged: cursor가 없으면 1페이지, 받은 cursor로 2페이지를 준다', () async {
    final repo = repoFor('paged');

    final first = await repo.fetchPage();
    expect(first.items, hasLength(3));
    expect(first.hasNext, isTrue);
    expect(first.nextCursor, isNotNull);

    final second = await repo.fetchPage(cursor: first.nextCursor);
    expect(second.items, hasLength(2));
    expect(second.hasNext, isFalse);
  });

  test('AI 처리 실패 이야기는 안내 문구를 보여준다', () async {
    final repo = repoFor('paged');
    final first = await repo.fetchPage();
    final second = await repo.fetchPage(cursor: first.nextCursor);

    final failed = second.items.first.parentAnswer;
    expect(failed.processingStatus, 'FAILED');
    expect(failed.summaryText, isNull);
    expect(failed.sttText, isNull);
    expect(failed.displayText, '음성 정리는 실패했지만 원본 녹음은 안전하게 저장되었습니다.');
  });

  test('empty: 빈 목록', () async {
    final page = await repoFor('empty').fetchPage();
    expect(page.items, isEmpty);
    expect(page.hasNext, isFalse);
  });
}
