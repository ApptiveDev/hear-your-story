import 'dart:convert';
import 'dart:io';

import '../frontend/lib/features/account/domain/legal_documents.dart';

// 저장소 루트에서 `dart run support-site/build.dart`.
// 앱의 문서를 직접 가져와 웹 원문과 앱 원문이 달라지는 것을 방지한다.
String escape(String value) => const HtmlEscape().convert(value);

String page(String title, String body) =>
    '''<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex, nofollow">
  <meta name="description" content="들려줘요 운영팀의 개인정보 및 계정 삭제 안내">
  <title>${escape(title)} · 들려줘요</title>
  <link rel="stylesheet" href="styles.css">
</head>
<body>
  <a class="skip" href="#main">본문 바로가기</a>
  <header><a class="brand" href="index.html">들려줘요<span>운영팀</span></a>
    <nav aria-label="지원 메뉴"><a href="privacy.html">개인정보 처리방침</a><a href="deletion.html">계정 삭제</a></nav>
  </header>
  <aside class="draft" role="note">검토용 초안 · 현재 스토어 제출용 최종 페이지가 아닙니다.</aside>
  <main id="main">$body</main>
  <footer><strong>들려줘요 운영팀</strong><p>운영 대표 및 개인정보 보호책임자: 제수지</p>
    <a href="mailto:jesuji030502@naver.com">jesuji030502@naver.com</a></footer>
</body>
</html>
''';

void main(List<String> arguments) {
  String? deletionUrl;
  if (arguments.isNotEmpty) {
    if (arguments.length != 1 ||
        !arguments.single.startsWith('--deletion-url=')) {
      throw ArgumentError(
        '사용법: dart run support-site/build.dart [--deletion-url=https://도메인/account-deletion]',
      );
    }
    final value = arguments.single.substring('--deletion-url='.length);
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != '/account-deletion') {
      throw ArgumentError('삭제 주소는 고정된 HTTPS /account-deletion 주소여야 합니다.');
    }
    deletionUrl = escape(uri.toString());
  }
  // 작업 디렉터리와 무관하게 스크립트 옆에 생성한다.
  final root = File.fromUri(Platform.script).parent;
  final output = Directory('${root.path}/dist')..createSync(recursive: true);
  void write(String name, String content) =>
      File('${output.path}/$name').writeAsStringSync(content);

  write(
    'index.html',
    page('이야기를 잇는 공간, 이용자를 위한 안내', '''
    <p class="eyebrow">들려줘요 이용 안내</p>
    <h1>이야기도, 개인정보도<br>소중하게 다룹니다.</h1>
    <p class="lead">개인정보가 어떻게 쓰이는지 확인하고,<br>계정과 기록의 삭제 방법을 알아보세요.</p>
    <div class="cards">
      <a class="card" href="privacy.html"><h2>개인정보 처리방침</h2><p>수집하는 정보와 사용 목적,<br>보관·삭제 기준을 안내해요.</p><span>내용 확인하기</span></a>
      <a class="card" href="deletion.html"><h2>계정 삭제 요청</h2><p>앱을 사용할 수 없을 때에도<br>삭제 요청 방법을 확인할 수 있어요.</p><span>삭제 방법 확인하기</span></a>
    </div>
    <section><h2>도움이 필요하신가요?</h2><p>개인정보와 계정에 관한 문의를 이메일로 보내주세요.</p>
      <a href="mailto:jesuji030502@naver.com">jesuji030502@naver.com</a></section>
  '''),
  );

  final contents = StringBuffer('<p class="eyebrow">개인정보 보호</p>')
    ..write('<h1>${escape(privacyPolicy.title)}</h1>')
    ..write('<p class="lead">${escape(privacyPolicy.summary)}</p>')
    ..write('<nav class="toc" aria-label="문서 목차">');
  for (var i = 0; i < privacyPolicy.sections.length; i++) {
    contents.write(
      '<a href="#section-${i + 1}">${escape(privacyPolicy.sections[i].heading)}</a>',
    );
  }
  contents.write('</nav>');
  for (var i = 0; i < privacyPolicy.sections.length; i++) {
    final section = privacyPolicy.sections[i];
    contents.write(
      '<section id="section-${i + 1}"><h2>${escape(section.heading)}</h2>',
    );
    for (final paragraph in section.paragraphs) {
      contents.write('<p>${escape(paragraph)}</p>');
    }
    contents.write('</section>');
  }
  contents.write(
    '<section><h2>앱 밖에서 계정 삭제 요청하기</h2><p><a href="deletion.html">계정 삭제 요청 안내</a>에서 삭제 범위와 문의 방법을 확인할 수 있어요.</p></section>',
  );
  write('privacy.html', page(privacyPolicy.title, contents.toString()));

  final subject = Uri.encodeComponent('[들려줘요] 계정 삭제 요청');
  final body = Uri.encodeComponent(
    '안녕하세요. 들려줘요 계정 삭제를 요청합니다.\n본인 확인 절차를 안내해 주세요.\n\n※ 카카오 비밀번호, 인증번호, 토큰, 주민등록번호는 보내지 않습니다.',
  );
  final webRequest = deletionUrl == null
      ? '<p class="notice">웹 카카오 본인 확인 경로가 아직 연결되지 않았어요. 검토용 페이지이며 현재 스토어 제출용 삭제 경로가 아닙니다.</p>'
      : '''<p>가입했던 카카오 계정으로 본인 확인 후 삭제할 계정과 범위를 확인하고, 직접 탈퇴를 확정할 수 있어요. 앱 설치는 필요하지 않아요.</p>
      <a class="button" href="$deletionUrl">카카오 계정 확인 후 삭제 요청하기</a>
      <p>카카오 로그인만으로 삭제되지 않아요. 본인 확인은 10분간 유효하며 확정 전에 취소할 수 있어요.</p>
      <p>삭제 요청 수락 시 계정 접근과 가족 연결을 해제하고 본인 답변 내용을 비워요. 음성 파일과 카카오 연결 해제는 별도 작업으로 처리하며 실패 시 재시도해요.</p>''';
  write(
    'deletion.html',
    page('계정 삭제 요청', '''
    <p class="eyebrow">계정과 기록 관리</p><h1>계정 삭제를<br>요청하고 싶어요.</h1>
    <p class="lead">들려줘요 계정과 본인이 작성한 기록을 삭제하는 방법을 안내해요.</p>
    <section><h2>앱을 사용할 수 있다면</h2><p>앱의 <strong>마이 → 탈퇴하기</strong>에서 요청할 수 있어요. 요청이 수락되면 계정 접근과 가족 연결을 해제하고 삭제 작업을 시작해요.</p></section>
    <section id="request"><h2>앱을 사용할 수 없다면</h2>
      $webRequest
      <p>본인 확인에 어려움이 있다면 이메일로 문의해 주세요. 메일만으로 본인 확인이 되거나 계정이 삭제되는 것은 아니에요.</p>
      <a class="button" href="mailto:jesuji030502@naver.com?subject=$subject&amp;body=$body">운영팀에 문의하기</a>
      <p>메일 앱이 열리지 않으면 <a href="mailto:jesuji030502@naver.com">jesuji030502@naver.com</a>으로 제목에 ‘들려줘요 계정 삭제 요청’을 적어 보내주세요.</p>
    </section>
    <section><h2>어떤 정보가 삭제되나요?</h2>
      <ul><li>이름·카카오 계정 연결정보는 삭제하거나 익명화하고, 로그인과 가족 연결을 해제해요.</li>
      <li>부모가 탈퇴하면 본인이 올린 원본 녹음·변환된 글·정리된 글을 삭제해요.</li>
      <li>자녀가 탈퇴하면 본인이 쓴 글과 그 글로 만든 음성을 삭제해요.</li>
      <li>상대방이 작성한 답변과 질문은 상대방의 지난 기록으로 남아요. 탈퇴한 사람의 답변은 삭제 안내로 바뀌어요.</li></ul>
    </section>
    <section><h2>삭제 전에 알아두세요</h2><p>탈퇴로 삭제한 본인 기록은 되돌릴 수 없어요. 서비스 DB의 내용 삭제, 파일 삭제, 카카오 연결 해제는 완료 시점이 다를 수 있어요.</p>
      <p>외부 업체의 보관 정보와 예외는 <a href="privacy.html#section-5">개인정보 처리방침의 보관 안내</a>를 확인해 주세요.</p>
      <p>요청 이메일 주소만으로 계정 소유자를 확인할 수는 없어요. 다른 사람의 계정이 잘못 삭제되지 않도록 본인 확인이 필요해요.</p>
      <p><strong>카카오 비밀번호·인증번호·로그인 토큰·주민등록번호·신분증을 이메일로 보내지 마세요.</strong></p>
    </section>
  '''),
  );
  File('${root.path}/styles.css').copySync('${output.path}/styles.css');
  write('.nojekyll', '');
  stdout.writeln('검토용 사이트 생성 완료: ${output.path}');
}
