import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 서버가 401(토큰 없음·만료)을 돌려줄 때마다 값이 1씩 오른다.
///
/// Dio interceptor가 올리고 앱 최상단(`App`)이 듣는다. 어느 화면·위젯에서 난 401이든
/// 로그인 정보 정리와 가입 화면 이동이 빠지지 않게 하려는 것이다.
final sessionExpiredSignalProvider =
    NotifierProvider<SessionExpiredSignal, int>(SessionExpiredSignal.new);

class SessionExpiredSignal extends Notifier<int> {
  @override
  int build() => 0;

  void emit() => state++;
}
