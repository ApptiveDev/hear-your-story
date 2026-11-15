import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  if (AppConfig.kakaoNativeAppKey.isNotEmpty) {
    WidgetsFlutterBinding.ensureInitialized();
    await KakaoSdk.init(nativeAppKey: AppConfig.kakaoNativeAppKey);
  }
  runApp(const ProviderScope(child: App()));
}
