import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/core/config/auth_flags.dart';
import 'package:life_record/core/network/api_exception.dart';
import 'package:life_record/core/network/dio_provider.dart';
import 'package:life_record/core/network/session_expired_signal.dart';

typedef _Reply = (int status, Object? body);

/// 경로별로 응답하는 가짜 서버. 요청 본문은 실제처럼 끝까지 읽는다.
class _FakeServer implements HttpClientAdapter {
  _FakeServer(this.handle);

  Future<_Reply> Function(RequestOptions options) handle;
  final requests = <RequestOptions>[];

  int count(String path) => requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
    final (status, body) = await handle(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late _FakeServer server;
  late Dio dio;
  late int expired;
  const storage = FlutterSecureStorage();

  /// 새 토큰이면 성공, 아니면 401
  Future<_Reply> api(RequestOptions o) async =>
      o.headers['Authorization'] == 'Bearer new-access'
      ? (200, {'ok': true})
      : (401, {'errorCode': 'TOKEN_EXPIRED'});

  Future<_Reply> refreshOk(RequestOptions o) async =>
      (200, {'accessToken': 'new-access', 'refreshToken': 'refresh-2'});

  void start({
    Map<String, String>? stored,
    bool refreshEnabled = true,
    Future<_Reply> Function(RequestOptions)? onRefresh,
    Future<_Reply> Function(RequestOptions)? onApi,
  }) {
    FlutterSecureStorage.setMockInitialValues(
      stored ?? {'access_token': 'old-access', 'refresh_token': 'refresh-1'},
    );
    server = _FakeServer(
      (o) => o.path == '/auth/refresh'
          ? (onRefresh ?? refreshOk)(o)
          : (onApi ?? api)(o),
    );
    container = ProviderContainer(
      overrides: [kakaoAuthEnabledProvider.overrideWithValue(refreshEnabled)],
    );
    addTearDown(container.dispose);
    expired = 0;
    container.listen(sessionExpiredSignalProvider, (_, _) => expired++);
    dio = container.read(dioProvider)..httpClientAdapter = server;
  }

  Future<ApiException> failure(Future<Object?> request) async {
    try {
      await request;
    } on DioException catch (e) {
      return ApiException.fromDio(e);
    }
    fail('요청이 실패해야 한다');
  }

  test('401이면 토큰을 갱신하고 원래 요청을 다시 보낸다', () async {
    start();

    final res = await dio.get<dynamic>('/today');

    expect(res.data, {'ok': true});
    expect(server.count('/auth/refresh'), 1);
    expect(server.count('/today'), 2);
    expect(await storage.read(key: 'access_token'), 'new-access');
    expect(await storage.read(key: 'refresh_token'), 'refresh-2');
    expect(expired, 0);
  });

  test('갱신 요청은 인증 헤더 없이 refresh token만 보낸다', () async {
    start();

    await dio.get<dynamic>('/today');

    final refresh = server.requests.firstWhere(
      (r) => r.path == '/auth/refresh',
    );
    expect(refresh.data, {'refreshToken': 'refresh-1'});
    expect(refresh.headers.containsKey('Authorization'), isFalse);
  });

  test('동시에 401이 여러 개 와도 갱신은 한 번만 한다', () async {
    final gate = Completer<void>();
    start(
      onRefresh: (o) async {
        await gate.future;
        return refreshOk(o);
      },
    );

    final all = Future.wait([
      dio.get<dynamic>('/today'),
      dio.get<dynamic>('/stories'),
      dio.get<dynamic>('/users/me'),
    ]);
    await pumpEventQueue();
    gate.complete();
    final results = await all;

    expect(results.map((r) => r.data), everyElement({'ok': true}));
    expect(server.count('/auth/refresh'), 1);
    expect(expired, 0);
  });

  test('다른 요청이 이미 갱신했으면 갱신 없이 새 토큰으로 다시 보낸다', () async {
    final slow = Completer<void>();
    start(
      onApi: (o) async {
        if (o.headers['Authorization'] == 'Bearer old-access') {
          await slow.future;
        }
        return api(o);
      },
    );

    final request = dio.get<dynamic>('/today');
    await pumpEventQueue();
    // 이 요청이 응답을 기다리는 사이 다른 곳에서 갱신이 끝났다
    await storage.write(key: 'access_token', value: 'new-access');
    slow.complete();

    expect((await request).data, {'ok': true});
    expect(server.count('/auth/refresh'), 0);
  });

  test('refresh token이 거절되면 로그인 만료로 처리한다', () async {
    start(onRefresh: (o) async => (401, {'errorCode': 'INVALID_REFRESH'}));

    final error = await failure(dio.get<dynamic>('/today'));

    expect(error.statusCode, 401);
    expect(expired, 1);
    expect(server.count('/today'), 1);
  });

  test('refresh token이 없으면 갱신하지 않고 로그인 만료로 처리한다', () async {
    start(stored: {'access_token': 'old-access'});

    final error = await failure(dio.get<dynamic>('/today'));

    expect(error.statusCode, 401);
    expect(server.count('/auth/refresh'), 0);
    expect(expired, 1);
  });

  test('갱신 중 인터넷이 끊기면 로그아웃하지 않고 연결 오류로 알린다', () async {
    start(
      onRefresh: (o) async => throw DioException.connectionError(
        requestOptions: o,
        reason: 'offline',
      ),
    );

    final error = await failure(dio.get<dynamic>('/today'));

    expect(error.statusCode, isNull);
    expect(error.userMessage, '인터넷 연결을 확인해 주세요.');
    expect(expired, 0);
    expect(await storage.read(key: 'refresh_token'), 'refresh-1');
  });

  test('갱신 서버가 5xx면 로그아웃하지 않고 잠시 후 다시 시도하게 한다', () async {
    start(onRefresh: (o) async => (503, {'errorCode': 'UNAVAILABLE'}));

    final error = await failure(dio.get<dynamic>('/today'));

    expect(error.statusCode, 503);
    expect(expired, 0);
    expect(await storage.read(key: 'access_token'), 'old-access');
  });

  test('다시 보낸 요청도 401이면 더 갱신하지 않고 로그인 만료로 처리한다', () async {
    start(onApi: (o) async => (401, {'errorCode': 'TOKEN_EXPIRED'}));

    final error = await failure(dio.get<dynamic>('/today'));

    expect(error.statusCode, 401);
    expect(server.count('/auth/refresh'), 1);
    expect(server.count('/today'), 2);
    expect(expired, 1);
  });

  test('갱신을 기다리는 사이 로그아웃하면 토큰을 되살리지 않는다', () async {
    final gate = Completer<void>();
    start(
      onRefresh: (o) async {
        await gate.future;
        return refreshOk(o);
      },
    );

    final request = failure(dio.get<dynamic>('/today'));
    await pumpEventQueue();
    await storage.deleteAll(); // 로그아웃
    gate.complete();

    expect((await request).statusCode, 401);
    expect(await storage.read(key: 'access_token'), isNull);
    expect(await storage.read(key: 'refresh_token'), isNull);
  });

  test('서버가 refresh token을 바꿔 주지 않으면 쓰던 것을 유지한다', () async {
    start(onRefresh: (o) async => (200, {'accessToken': 'new-access'}));

    await dio.get<dynamic>('/today');

    expect(await storage.read(key: 'refresh_token'), 'refresh-1');
  });

  test('녹음 업로드(FormData)도 갱신 후 다시 보낸다', () async {
    start();
    final dir = await Directory.systemTemp.createTemp('auth_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/a.m4a')..writeAsBytesSync([1, 2, 3]);

    final res = await dio.post<dynamic>(
      '/assignments/asg_1/recording',
      data: FormData.fromMap({
        'audioFile': await MultipartFile.fromFile(file.path),
      }),
    );

    expect(res.data, {'ok': true});
    expect(server.count('/assignments/asg_1/recording'), 2);
  });

  test('갱신을 끈 기존 가입 방식은 401이면 바로 로그인 만료로 처리한다', () async {
    start(refreshEnabled: false);

    final error = await failure(dio.get<dynamic>('/today'));

    expect(error.statusCode, 401);
    expect(server.count('/auth/refresh'), 0);
    expect(expired, 1);
  });
}
