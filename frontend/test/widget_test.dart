import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_record/app/app.dart';

void main() {
  testWidgets('앱 실행 시 카카오 로그인 화면이 표시된다', (WidgetTester tester) async {
    // 앱을 켤 때 저장된 로그인 정보를 읽으므로 빈 저장소로 시작한다
    FlutterSecureStorage.setMockInitialValues({});
    // 앱 띄우기 (main.dart와 똑같이 ProviderScope로 감싸기)
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle(); // 화면 이동이 끝날 때까지 대기

    // 첫 화면(/onboarding)의 카카오 로그인 버튼이 보이는지 확인
    expect(find.text('카카오로 시작하기'), findsOneWidget);
  });
}
