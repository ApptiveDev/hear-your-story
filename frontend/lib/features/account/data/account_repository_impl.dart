import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/account_repository.dart';

class MockAccountRepository implements AccountRepository {
  MockAccountRepository({
    this.failWith,
    this.delay = const Duration(milliseconds: 500),
  });

  final ApiException? failWith;
  final Duration delay;

  @override
  Future<void> deleteAccount() async {
    await Future.delayed(delay); // 로딩 확인용
    if (failWith != null) throw failWith!;
  }
}

class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository(this._dio);
  final Dio _dio;

  @override
  Future<void> deleteAccount() async {
    try {
      await _dio.delete('/users/me'); // 202 Accepted
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
