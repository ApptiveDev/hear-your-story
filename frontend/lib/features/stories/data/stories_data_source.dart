import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';

abstract class StoriesDataSource {
  Future<Map<String, dynamic>> fetchStories({String? cursor, int limit = 20});

  /// [month]는 `YYYY-MM`. 계약상 cursor·limit과 함께 보내지 않는다.
  Future<Map<String, dynamic>> fetchStoriesByMonth(String month);

  /// 부모 본인의 녹음을 지운다. (계약 5.12 초안)
  Future<void> deleteRecording(String recordingId);

  /// 자녀 본인의 답을 지운다. (계약 5.15 초안)
  Future<void> deleteAnswer(String answerId);
}

class MockStoriesDataSource implements StoriesDataSource {
  /// 에뮬레이터에서 상태별 화면을 볼 때는:
  /// flutter run --dart-define=MOCK_STORIES=paged
  /// 지원 값: first_page(기본, 계약 예시), paged, empty, deleted(삭제된 답), NETWORK
  MockStoriesDataSource({
    this.scenario = _definedScenario,
    this.failWith,
    this.delay = const Duration(milliseconds: 500),
  });

  static const _definedScenario = String.fromEnvironment('MOCK_STORIES');

  final String scenario;
  final ApiException? failWith;
  final Duration delay;

  /// 이번 실행에서 지운 녹음·답. 다시 조회하면 서버처럼 DELETED로 돌려준다.
  final _deletedRecordingIds = <String>{};
  final _deletedAnswerIds = <String>{};

  static const Map<String, dynamic> _deletedParentAnswer = {
    'availability': 'DELETED',
    'recordingId': null,
    'processingStatus': null,
    'originalAudioUrl': null,
    'originalAudioExpiresAt': null,
    'sttText': null,
    'summaryText': null,
    'processingNotice': '부모님이 이 음성 기록을 삭제했어요.',
  };

  static const Map<String, dynamic> _deletedChildAnswer = {
    'availability': 'DELETED',
    'answerId': null,
    'text': null,
    'ttsStatus': null,
  };

  @override
  Future<Map<String, dynamic>> fetchStories({
    String? cursor,
    int limit = 20,
  }) async {
    await Future.delayed(delay); // 로딩 화면 확인용
    if (failWith != null) throw failWith!;

    final String file;
    switch (scenario) {
      case 'NETWORK':
        throw ApiException(); // statusCode 없음 = 연결 실패
      case 'empty':
        file = 'stories_empty';
      case 'paged':
        file = cursor == null ? 'stories_paged_1' : 'stories_paged_2';
      case 'deleted':
        file = 'story_recording_deleted';
      default:
        file = 'stories_first_page';
    }

    return _load(file);
  }

  @override
  Future<Map<String, dynamic>> fetchStoriesByMonth(String month) async {
    await Future.delayed(delay); // 로딩 화면 확인용
    if (failWith != null) throw failWith!;
    if (scenario == 'NETWORK') throw ApiException();

    // 예시 데이터는 2026년 11월뿐이고 다른 달은 이야기가 없는 달로 둔다.
    final hasStories = scenario != 'empty' && month == '2026-11';
    return _load(hasStories ? 'stories_month_2026_11' : 'stories_empty');
  }

  @override
  Future<void> deleteRecording(String recordingId) async {
    await Future.delayed(delay);
    if (failWith != null) throw failWith!;
    if (scenario == 'NETWORK') throw ApiException();
    _deletedRecordingIds.add(recordingId);
  }

  @override
  Future<void> deleteAnswer(String answerId) async {
    await Future.delayed(delay);
    if (failWith != null) throw failWith!;
    if (scenario == 'NETWORK') throw ApiException();
    _deletedAnswerIds.add(answerId);
  }

  Future<Map<String, dynamic>> _load(String file) async {
    final raw = await rootBundle.loadString('assets/mocks/$file.json');
    return _applyDeletions(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// 지운 녹음·답을 `availability=DELETED` 응답으로 바꾼다.
  Map<String, dynamic> _applyDeletions(Map<String, dynamic> page) {
    for (final item in page['items'] as List<dynamic>) {
      final story = item as Map<String, dynamic>;
      final parent = story['parentAnswer'] as Map<String, dynamic>;
      if (_deletedRecordingIds.contains(parent['recordingId'])) {
        story['parentAnswer'] = _deletedParentAnswer;
      }
      final child = story['childAnswer'] as Map<String, dynamic>;
      if (_deletedAnswerIds.contains(child['answerId'])) {
        story['childAnswer'] = _deletedChildAnswer;
      }
    }
    return page;
  }
}

class ApiStoriesDataSource implements StoriesDataSource {
  ApiStoriesDataSource(this._dio);
  final Dio _dio;

  @override
  Future<Map<String, dynamic>> fetchStories({
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get(
        '/stories',
        queryParameters: {'limit': limit, 'cursor': ?cursor},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Map<String, dynamic>> fetchStoriesByMonth(String month) async {
    try {
      final res = await _dio.get('/stories', queryParameters: {'month': month});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> deleteRecording(String recordingId) async {
    try {
      await _dio.delete('/recordings/$recordingId');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> deleteAnswer(String answerId) async {
    try {
      await _dio.delete('/answers/$answerId');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
