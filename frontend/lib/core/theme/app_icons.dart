import 'package:flutter/widgets.dart';

/// Figma 디자인의 아이콘. 글꼴의 글자로 그린다.
///
/// `icon/*` 부품과 완료 체크는 디자인 벡터를 옮긴 [_app], 나머지는 Flaticon
/// UIcons 글꼴이다.
///
/// UIcons 이름은 Figma 레이어 이름(`fi-sr-heart` 등)을 따른다. sr은 Solid Rounded,
/// rr은 Regular Rounded. 새 아이콘은 npm `@flaticon/flaticon-uicons`의
/// `css/all/all.rounded.css`에서 코드값을 찾아 추가한다.
abstract final class AppIcons {
  static const _app = 'AppIcons';
  static const _solid = 'UIconsSolidRounded';
  static const _regular = 'UIconsRegularRounded';

  /// icon/arrow-left: 헤더 `이전`, 지난달
  static const arrowLeft = IconData(0xe905, fontFamily: _app);

  /// icon/home: 탭 홈
  static const home = IconData(0xe900, fontFamily: _app);

  /// icon/books: 탭 책장
  static const books = IconData(0xe901, fontFamily: _app);

  /// icon/calendar: 탭 달력
  static const calendar = IconData(0xe902, fontFamily: _app);

  /// icon/person: 탭 마이
  static const user = IconData(0xe903, fontFamily: _app);

  /// icon/mic: 목소리로 답하기
  static const microphone = IconData(0xe904, fontFamily: _app);

  /// fi-sr-pencil: 글로 답하기
  static const pencil = IconData(0xfa17, fontFamily: _solid);

  /// icon/arrow-right: 다음 달
  static const arrowRight = IconData(0xe906, fontFamily: _app);

  /// fi-rr-book-alt: 이용약관
  static const bookAlt = IconData(0xf274, fontFamily: _regular);

  /// fi-rr-address-book: 개인정보 처리방침
  static const addressBook = IconData(0xf11b, fontFamily: _regular);

  /// fi-rr-headset: 문의하기
  static const headset = IconData(0xf794, fontFamily: _regular);

  /// fi-rr-asterik: 앱 버전
  static const asterisk = IconData(0xf1d3, fontFamily: _regular);

  /// fi-rr-palette: 아이콘 출처
  static const palette = IconData(0xf9ed, fontFamily: _regular);

  /// fi-rr-undo: 로그아웃
  static const undo = IconData(0xfe6b, fontFamily: _regular);

  /// fi-rr-sign-out-alt: 탈퇴하기
  static const signOut = IconData(0xfc0c, fontFamily: _regular);

  /// fi-sr-heart: 부모
  static const heart = IconData(0xf794, fontFamily: _solid);

  /// fi-sr-child-head: 자녀
  static const childHead = IconData(0xf3d9, fontFamily: _solid);

  /// 완료·선택됨 체크 (`Badge`). 56 틀 안에 여백을 두고 그려져 있다
  static const check = IconData(0xe907, fontFamily: _app);

  /// fi-sr-smile-wink: 연결 완료
  static const smileWink = IconData(0xfc21, fontFamily: _solid);

  /// fi-sr-exclamation: 입력 오류
  static const exclamation = IconData(0xf5df, fontFamily: _solid);
}
