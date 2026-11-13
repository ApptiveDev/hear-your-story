import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/features/account/data/account_repository_impl.dart';

void main() {
  /// [respond]가 돌려준 응답(또는 실패)으로 요청에 답하는 저장소와, 받은 요청을 돌려준다.
  ({ApiAccountRepository repo, List<RequestOptions> requests}) build(
    void Function(RequestInterceptorHandler handler, RequestOptions options)
    respond,
  ) {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          respond(handler, options);
        },
      ),
    );
    return (repo: ApiAccountRepository(dio), requests: requests);
  }

  test('탈퇴는 DELETE /users/me로 요청한다 (202)', () async {
    final (:repo, :requests) = build(
      (handler, options) => handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 202,
          data: {
            'deletionRequestId': 'del_1',
            'status': 'PROCESSING',
            'requestedAt': '2026-11-04T15:00:00+09:00',
          },
        ),
      ),
    );

    await repo.deleteAccount();

    expect(requests.single.method, 'DELETE');
    expect(requests.single.uri.path, '/api/v1/users/me');
  });

  test('이미 탈퇴 처리 중이면 409 errorCode를 ApiException으로 전달한다', () async {
    final (:repo, requests: _) = build(
      (handler, options) => handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: 409,
            data: {
              'errorCode': 'ACCOUNT_DELETION_IN_PROGRESS',
              'traceId': 'trace_1',
            },
          ),
        ),
      ),
    );

    await expectLater(
      repo.deleteAccount(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having(
              (e) => e.errorCode,
              'errorCode',
              'ACCOUNT_DELETION_IN_PROGRESS',
            ),
      ),
    );
  });

  test('401은 statusCode를 그대로 전달한다', () async {
    final (:repo, requests: _) = build(
      (handler, options) => handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 401),
        ),
      ),
    );

    await expectLater(
      repo.deleteAccount(),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
    );
  });

  test('네트워크 오류는 statusCode 없는 ApiException이다', () async {
    final (:repo, requests: _) = build(
      (handler, options) => handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      ),
    );

    await expectLater(
      repo.deleteAccount(),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', isNull),
      ),
    );
  });
}
