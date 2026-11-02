import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/features/child_answer/domain/answer_validator.dart';

void main() {
  test('CI smoke: 답변 정규화는 내부 줄바꿈을 보존한다', () {
    const raw = '  첫 번째 기억\n두 번째 기억  ';

    expect(AnswerValidator.normalize(raw), '첫 번째 기억\n두 번째 기억');
    expect(AnswerValidator.validate(raw), AnswerValidation.valid);
  });
}
