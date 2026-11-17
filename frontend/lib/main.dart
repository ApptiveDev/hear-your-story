import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/text_scale/text_scale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.kakaoNativeAppKey.isNotEmpty) {
    await KakaoSdk.init(nativeAppKey: AppConfig.kakaoNativeAppKey);
  }
  // 첫 화면부터 고른 글자 크기로 그린다
  final textSize = await TextSizeStorage(const FlutterSecureStorage()).read();
  runApp(
    ProviderScope(
      overrides: [initialTextSizeProvider.overrideWithValue(textSize)],
      child: const App(),
    ),
  );
}
