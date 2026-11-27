package com.apptive.backend.domain.user.web;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.csrf.CsrfToken;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;

import lombok.RequiredArgsConstructor;

@RestController
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.web-deletion.enabled", havingValue = "true")
@RequestMapping("/account-deletion")
public class WebDeletionController {

	private static final String TARGET = WebDeletionController.class.getName() + ".target";
	private final WebDeletionService service;

	@GetMapping
	public ResponseEntity<String> landing() {
		return WebDeletionPages.page(200, "계정 삭제 요청", """
		    <p>앱을 설치하지 않아도 가입했던 카카오 계정으로 본인 확인 후 계정 삭제를 요청할 수 있어요.</p>
		    <p>로그인은 본인 확인용이며 새 들려줘요 계정을 만들지 않아요. 카카오 로그인만으로 탈퇴되지 않아요.</p>
		    <a class="button" href="/oauth2/authorization/kakao-deletion">카카오 계정으로 본인 확인</a>
		    <h2>삭제되는 정보</h2><ul><li>이름·카카오 계정 연결정보와 로그인 권한·가족 연결</li>
		    <li>부모: 본인 원본 음성·변환된 글·정리된 글</li><li>자녀: 본인 답변 글·생성 음성</li></ul>
		    <h2>남는 정보</h2><p>상대방이 작성한 답변·질문은 상대방의 지난 기록으로 남아요.
		    탈퇴한 사람의 답변은 삭제 안내로 표시돼요. 필요한 비식별 연결·처리 이력은 남을 수 있어요.</p>
		    <h2>삭제 처리</h2><p>확정하면 즉시 계정 접근을 차단하고 DB의 본인 답변 내용을 비워요.
		    음성 파일과 카카오 연결은 별도 작업으로 지체 없이 삭제를 시도하며 실패 시 재시도해요.
		    외부 업체의 보안 로그·복구 사본에는 업체별 보관 조건이 적용돼요.</p>
		    <p>OpenAI의 STT는 기본 조건상 악용 방지 로그·처리 상태를 보관하지 않는 것으로 안내돼요.
		    글 정리·TTS의 악용 방지 로그는 기본 최대 30일이며 법적 요구·보안상 예외가 있을 수 있어요.</p>
		    <p>카카오 비밀번호·인증번호·토큰은 운영팀에 보내지 마세요. 문의는 아래 이메일로 보내주세요.</p>
		    """);
	}

	@GetMapping("/confirm")
	public ResponseEntity<String> preview(@AuthenticationPrincipal WebDeletionIdentity identity,
	    HttpServletRequest request, CsrfToken csrf) {
		WebDeletionService.Preview user = service.preview(identity);
		request.getSession().setAttribute(TARGET, user.userId());
		String role = user.role() == com.apptive.backend.domain.user.entity.Role.PARENT ? "부모" : "자녀";
		return WebDeletionPages.page(200, "이 계정을 삭제할까요?", "<p>확인한 계정: <strong>" + WebDeletionPages.escape(user.name())
		    + " (" + role + ")</strong></p>" + "<p>본인이 작성한 음성·글을 삭제하고 가족 연결을 해제해요. 상대방이 작성한 답변은 남아요.</p>"
		    + "<p class=\"notice\">삭제한 본인 기록은 복구할 수 없어요. 다른 계정이라면 취소하고 다시 확인해 주세요.</p>"
		    + "<form method=\"post\" action=\"/account-deletion/confirm\">" + WebDeletionPages.csrf(csrf)
		    + "<label><input type=\"checkbox\" name=\"confirm\" value=\"yes\" required> 삭제 범위를 확인했고 탈퇴에 동의해요.</label>"
		    + "<button type=\"submit\">계정 삭제 확정</button></form>"
		    + "<form method=\"post\" action=\"/account-deletion/cancel\">" + WebDeletionPages.csrf(csrf)
		    + "<button type=\"submit\">취소하고 계정 확인 종료</button></form>");
	}

	@PostMapping(value = "/confirm", consumes = MediaType.APPLICATION_FORM_URLENCODED_VALUE)
	public ResponseEntity<String> confirm(@AuthenticationPrincipal WebDeletionIdentity identity,
	    @RequestParam(defaultValue = "") String confirm, HttpServletRequest request) {
		if (!"yes".equals(confirm)) {
			throw new ApiException(ErrorCode.VALIDATION_ERROR);
		}
		HttpSession session = request.getSession(false);
		if (session == null) {
			throw new ApiException(ErrorCode.UNAUTHORIZED);
		}
		String target;
		synchronized (session) {
			target = (String) session.getAttribute(TARGET);
			session.removeAttribute(TARGET);
		}
		if (target == null) {
			throw new ApiException(ErrorCode.UNAUTHORIZED);
		}
		// 한 번의 확인은 한 번만 사용. 실패하면 다시 로그인해 확인한다.
		session.invalidate();
		SecurityContextHolder.clearContext();
		service.confirm(identity, target);
		return WebDeletionPages.page(202, "삭제 요청을 접수했어요", """
		    <p>계정 접근과 가족 연결을 해제하고 본인 데이터 삭제를 시작했어요.</p>
		    <p>음성 파일·카카오 연결 해제는 별도 처리되며 실패 시 자동 재시도해요.
		    이 화면은 모든 외부 삭제가 완료됐다는 의미는 아니에요.</p>
		    <p>같은 카카오 계정으로 다시 가입해도 삭제된 본인 기록은 복원되지 않아요.</p>
		    """);
	}

	@PostMapping("/cancel")
	public ResponseEntity<String> cancel(HttpServletRequest request) {
		if (request.getSession(false) != null) {
			request.getSession(false).invalidate();
		}
		SecurityContextHolder.clearContext();
		return WebDeletionPages.page(200, "계정 확인을 종료했어요", "<p>계정을 삭제하지 않았어요.</p>");
	}

	@GetMapping("/error")
	public ResponseEntity<String> loginError() {
		return WebDeletionPages.page(401, "계정을 확인하지 못했어요", "<p>로그인을 취소했거나 확인 시간이 지났어요. 다시 시도해 주세요.</p>");
	}
}
