package com.apptive.backend.domain.user.web;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.web.csrf.CsrfToken;
import org.springframework.web.util.HtmlUtils;

public final class WebDeletionPages {

	private WebDeletionPages() {
	}

	public static String escape(String value) {
		return HtmlUtils.htmlEscape(value);
	}

	public static String csrf(CsrfToken token) {
		return "<input type=\"hidden\" name=\"" + escape(token.getParameterName()) + "\" value=\""
		    + escape(token.getToken()) + "\">";
	}

	public static ResponseEntity<String> page(int status, String title, String body) {
		return ResponseEntity.status(status)
		    .contentType(new MediaType("text", "html", java.nio.charset.StandardCharsets.UTF_8))
		    .header("Cache-Control", "no-store").body("""
		        <!doctype html><html lang="ko"><head><meta charset="utf-8">
		        <meta name="viewport" content="width=device-width,initial-scale=1">
		        <title>%s · 들려줘요</title><style>
		        body{font:18px/1.8 system-ui,sans-serif;color:#3b2a1f;background:#fffdf8;margin:0}
		        main{max-width:640px;margin:auto;padding:32px 20px}h1{font-size:30px;line-height:1.4}
		        a{color:#935b2d}button,.button{display:inline-block;padding:14px 20px;background:#935b2d;
		        color:white;border:0;border-radius:10px;font:inherit;text-decoration:none;margin:12px 0}
		        input{width:22px;height:22px;vertical-align:middle}label{display:block;margin:24px 0}
		        .notice{padding:16px;background:#fcf2dc}footer{border-top:1px solid #ede4cb;margin-top:32px}
		        :focus-visible{outline:3px solid #935b2d;outline-offset:4px}p,li{overflow-wrap:anywhere}
		        </style></head><body><main><p>들려줘요 운영팀</p><h1>%s</h1>%s
		        <footer><p>문의: <a href="mailto:jesuji030502@naver.com">jesuji030502@naver.com</a></p>
		        <a href="/account-deletion">삭제 안내로 돌아가기</a></footer></main></body></html>
		        """.formatted(escape(title), escape(title), body));
	}
}
