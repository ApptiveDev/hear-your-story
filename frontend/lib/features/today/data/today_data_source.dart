import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../onboarding/data/user_storage.dart';

abstract class TodayDataSource {
  Future<Map<String, dynamic>> fetchToday();
}

class MockTodayDataSource implements TodayDataSource {
  /// 다른 상태를 볼 때: flutter run --dart-define=MOCK_TODAY=revealed
  /// 지원 값: waiting_for_both(기본), waiting_for_parent, waiting_for_child,
  /// revealed, deleted, PAIR_NOT_FOUND, TODAY_ASSIGNMENT_NOT_FOUND, NETWORK
  MockTodayDataSource(
    this._userStorage, {
    this.delay = const Duration(milliseconds: 500),
  });

  final UserStorage _userStorage;
  final Duration delay;

  static const _scenario = String.fromEnvironment(
    'MOCK_TODAY',
    defaultValue: 'waiting_for_both',
  );

  @override
  Future<Map<String, dynamic>> fetchToday() async {
    await Future.delayed(delay);
    switch (_scenario) {
      case 'PAIR_NOT_FOUND':
        throw ApiException(statusCode: 409, errorCode: _scenario);
      case 'TODAY_ASSIGNMENT_NOT_FOUND':
        throw ApiException(statusCode: 404, errorCode: _scenario);
      case 'NETWORK':
        throw ApiException();
    }

    final raw = await rootBundle.loadString(
      'assets/mocks/today_$_scenario.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (_scenario == 'waiting_for_both') {
      // 아무도 답하지 않은 상태는 역할과 상관없으므로 가입한 역할로 보여준다
      final user = await _userStorage.read();
      if (user != null) json['viewerRole'] = user.role.apiValue;
    }
    return json;
  }
}

class ApiTodayDataSource implements TodayDataSource {
  ApiTodayDataSource(this._dio);
  final Dio _dio;

  @override
  Future<Map<String, dynamic>> fetchToday() async {
    try {
      final res = await _dio.get('/today');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
