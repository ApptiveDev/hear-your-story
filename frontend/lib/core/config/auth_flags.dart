import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// 카카오 로그인 흐름(토큰 갱신, `GET /users/me` 복구)을 쓸지. 테스트에서 바꿔 끼운다.
///
/// 계약 1.2·5.14가 초안이라 기본은 꺼져 있고, 꺼져 있으면 기존 가입·401 처리를 그대로 쓴다.
final kakaoAuthEnabledProvider = Provider<bool>((ref) => AppConfig.kakaoAuth);
