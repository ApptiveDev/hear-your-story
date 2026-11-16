import 'package:flutter/widgets.dart';

/// Figma 디자인의 아이콘. Flaticon UIcons 글꼴의 글자다.
///
/// 이름은 Figma 레이어 이름(`fi-sr-heart` 등)을 따른다. sr은 Solid Rounded,
/// rr은 Regular Rounded. 새 아이콘은 npm `@flaticon/flaticon-uicons`의
/// `css/all/all.rounded.css`에서 코드값을 찾아 추가한다.
abstract final class AppIcons {
  static const _solid = 'UIconsSolidRounded';
  static const _regular = 'UIconsRegularRounded';

  /// icon/arrow-left (fi-rr-arrow-left): 헤더 `이전`
  static const arrowLeft = IconData(0xf197, fontFamily: _regular);

  /// icon/home (fi-rr-home): 탭 홈
  static const home = IconData(0xf7b8, fontFamily: _regular);

  /// icon/books (fi-rr-books): 탭 책장
  static const books = IconData(0xf28d, fontFamily: _regular);

  /// icon/calendar (fi-rr-calendar): 탭 달력
  static const calendar = IconData(0xf339, fontFamily: _regular);

  /// icon/person (fi-rr-user): 탭 마이
  static const user = IconData(0xfea0, fontFamily: _regular);

  /// icon/mic (fi-sr-microphone): 목소리로 답하기
  static const microphone = IconData(0xf934, fontFamily: _solid);

  /// fi-sr-pencil: 글로 답하기
  static const pencil = IconData(0xfa17, fontFamily: _solid);

  /// fi-sr-heart: 부모
  static const heart = IconData(0xf794, fontFamily: _solid);

  /// fi-sr-child-head: 자녀
  static const childHead = IconData(0xf3d9, fontFamily: _solid);

  /// fi-sr-check: 선택됨 표시
  static const check = IconData(0xf3c0, fontFamily: _solid);

  /// fi-sr-smile-wink: 연결 완료
  static const smileWink = IconData(0xfc21, fontFamily: _solid);

  /// fi-sr-exclamation: 입력 오류
  static const exclamation = IconData(0xf5df, fontFamily: _solid);
}
