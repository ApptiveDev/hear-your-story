import 'package:flutter_test/flutter_test.dart';

/// CI가 실패한 테스트를 잡는지 확인하는 검증용 테스트. 병합하지 않는다.
void main() {
  test('CI 실패 확인', () {
    expect(1 + 1, 3);
  });
}
