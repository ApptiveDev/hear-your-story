import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 앱 안에서 고르는 글자 크기. 휴대폰 글씨 설정에 곱해진다.
enum TextSize {
  normal(1.0),
  large(1.3);

  const TextSize(this.factor);
  final double factor;

  TextSize get toggled => this == normal ? large : normal;
}

/// 고른 글자 크기를 기기에 저장한다. 로그아웃해도 지우지 않는다(기기 설정).
class TextSizeStorage {
  TextSizeStorage(this._storage);
  final FlutterSecureStorage _storage;
  static const _key = 'text_size';

  /// 저장된 값이 없거나 읽지 못하면 보통 크기.
  Future<TextSize> read() async {
    try {
      final saved = await _storage.read(key: _key);
      return TextSize.values.firstWhere(
        (size) => size.name == saved,
        orElse: () => TextSize.normal,
      );
    } on Object {
      return TextSize.normal;
    }
  }

  Future<void> save(TextSize size) =>
      _storage.write(key: _key, value: size.name);
}

final textSizeStorageProvider = Provider<TextSizeStorage>(
  (ref) => TextSizeStorage(const FlutterSecureStorage()),
);

/// 앱을 켤 때 읽어 둔 글자 크기. `main`에서 저장값으로 바꿔 끼워서 첫 화면부터
/// 고른 크기로 그린다.
final initialTextSizeProvider = Provider<TextSize>((ref) => TextSize.normal);

class TextSizeController extends Notifier<TextSize> {
  @override
  TextSize build() => ref.read(initialTextSizeProvider);

  /// 보통 ↔ 크게. 화면에 바로 반영하고 저장은 뒤따라 한다.
  Future<void> toggle() async {
    state = state.toggled;
    try {
      await ref.read(textSizeStorageProvider).save(state);
    } on Object {
      // 저장에 실패해도 지금 화면의 크기는 유지한다. 다음 실행 때 보통으로 돌아간다
    }
  }
}

final textSizeProvider = NotifierProvider<TextSizeController, TextSize>(
  TextSizeController.new,
);

/// 앱 글자 크기를 휴대폰 글씨 설정에 곱한다.
///
/// 둘을 곱해도 글자 크기의 2배를 넘기지 않는다(화면이 넘치지 않게 검사하는 최대치).
/// 휴대폰 설정만으로 이미 2배를 넘으면 그 크기를 그대로 둔다.
TextScaler applyTextSize(TextScaler system, TextSize size) =>
    size == TextSize.normal ? system : _AppTextScaler(system, size.factor);

class _AppTextScaler extends TextScaler {
  const _AppTextScaler(this._system, this._factor);

  final TextScaler _system;
  final double _factor;

  static const maxScale = 2.0;

  @override
  double scale(double fontSize) {
    final system = _system.scale(fontSize);
    final scaled = system * _factor;
    final cap = fontSize * maxScale;
    if (scaled <= cap) return scaled;
    return system > cap ? system : cap;
  }

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is _AppTextScaler &&
      other._system == _system &&
      other._factor == _factor;

  @override
  int get hashCode => Object.hash(_system, _factor);
}
