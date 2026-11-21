import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_record/app/app.dart';
import 'package:life_record/core/text_scale/text_scale.dart';
import 'package:life_record/core/text_scale/text_scale_button.dart';
import 'package:life_record/features/onboarding/presentation/session.dart';
import 'package:life_record/features/today/data/today_providers.dart';

import '../features/today/today_fixtures.dart';
import '../helpers/phone_size.dart';

const _storage = FlutterSecureStorage();
const _question = '어릴 때 가장 좋아했던 놀이는 무엇이었나요?';

Map<String, String> _signedIn({String? textSize}) => {
  'access_token': 'token',
  'current_user': jsonEncode({
    'id': 'usr_test',
    'name': '김민지',
    'role': 'CHILD',
    'pairingStatus': 'PAIRED',
  }),
  'text_size': ?textSize,
};

Future<void> _launchHome(
  WidgetTester tester, {
  TextSize initial = TextSize.normal,
  Map<String, String>? stored,
}) async {
  usePhoneSize(tester);
  FlutterSecureStorage.setMockInitialValues(stored ?? _signedIn());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialTextSizeProvider.overrideWithValue(initial),
        todayDataSourceProvider.overrideWithValue(
          FakeTodayDataSource(json: todayFixture('waiting_for_both')),
        ),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}

/// 질문 글자의 실제 글자 크기 배율
double _questionScale(WidgetTester tester) {
  final context = tester.element(find.text(_question));
  return MediaQuery.textScalerOf(context).scale(10) / 10;
}

void main() {
  group('글자 크기 배율', () {
    test('보통이면 휴대폰 설정을 그대로 쓴다', () {
      const system = TextScaler.linear(1.3);
      expect(applyTextSize(system, TextSize.normal), same(system));
    });

    for (final (system, expected) in [
      (1.0, 1.3),
      (1.3, 1.69),
      (1.6, 2.0), // 곱하면 2.08이지만 2배까지만
      (2.0, 2.0),
      (2.5, 2.5), // 휴대폰 설정이 더 크면 줄이지 않는다
    ]) {
      test('휴대폰 $system배 × 크게 → $expected배', () {
        final scaled = applyTextSize(TextScaler.linear(system), TextSize.large);
        expect(scaled.scale(10), closeTo(expected * 10, 0.001));
      });
    }
  });

  group('저장', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('저장한 적 없거나 모르는 값이면 보통', () async {
      final storage = TextSizeStorage(_storage);
      expect(await storage.read(), TextSize.normal);
      await _storage.write(key: 'text_size', value: 'huge');
      expect(await storage.read(), TextSize.normal);
    });

    test('크게를 저장하면 다음에 크게로 읽는다', () async {
      final storage = TextSizeStorage(_storage);
      await storage.save(TextSize.large);
      expect(await storage.read(), TextSize.large);
    });

    test('로그아웃·만료로 로그인 정보를 지워도 글자 크기는 남는다', () async {
      FlutterSecureStorage.setMockInitialValues(_signedIn(textSize: 'large'));
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(sessionExpiryProvider).clearLocal();

      expect(await _storage.read(key: 'access_token'), isNull);
      expect(await _storage.read(key: 'text_size'), 'large');
    });
  });

  testWidgets('홈의 글자 크기를 누르면 바로 커지고, 다시 누르면 돌아온다', (tester) async {
    await _launchHome(tester);
    expect(_questionScale(tester), 1.0);

    await tester.tap(find.byType(TextScaleButton));
    await tester.pumpAndSettle();
    expect(_questionScale(tester), closeTo(1.3, 0.001));
    expect(await _storage.read(key: 'text_size'), 'large');

    await tester.tap(find.byType(TextScaleButton));
    await tester.pumpAndSettle();
    expect(_questionScale(tester), 1.0);
    expect(await _storage.read(key: 'text_size'), 'normal');
  });

  testWidgets('화면 읽기 프로그램에 크게 보기 켜짐·꺼짐을 알려준다', (tester) async {
    final semantics = tester.ensureSemantics();
    await _launchHome(tester);
    final button = find.bySemanticsLabel('글자 크게 보기');
    expect(
      tester.getSemantics(button),
      isSemantics(
        label: '글자 크게 보기',
        isButton: true,
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byType(TextScaleButton));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(button), isSemantics(isToggled: true));
    semantics.dispose();
  });

  testWidgets('앱을 켤 때 저장된 크게로 첫 화면부터 그린다', (tester) async {
    await _launchHome(tester, initial: TextSize.large);

    expect(_questionScale(tester), closeTo(1.3, 0.001));
  });
}
