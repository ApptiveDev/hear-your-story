package com.apptive.backend.domain.user.web;

import org.springframework.core.annotation.Order;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.common.exception.FailureLogger;

@Order(0)
@RestControllerAdvice(assignableTypes = WebDeletionController.class)
public class WebDeletionExceptionHandler {

	@ExceptionHandler(ApiException.class)
	public ResponseEntity<String> apiError(ApiException exception) {
		ErrorCode code = exception.getErrorCode();
		String text = switch (code) {
			case USER_NOT_FOUND -> "이 카카오 계정에 연결된 가입 정보를 찾지 못했어요. 가입했던 계정인지 확인해 주세요.";
			case ACCOUNT_DELETION_IN_PROGRESS -> "이미 삭제를 처리하고 있어요. 파일과 외부 연결 삭제는 자동 재시도돼요.";
			case VALIDATION_ERROR -> "삭제 동의를 확인해 주세요. 다시 본인 확인 후 진행할 수 있어요.";
			default -> "확인 시간이 지났거나 요청을 처리하지 못했어요. 다시 본인 확인해 주세요.";
		};
		return WebDeletionPages.page(code.status().value(), "요청을 확인해 주세요", "<p>" + text + "</p>");
	}

	@ExceptionHandler(Exception.class)
	public ResponseEntity<String> unexpected(Exception exception) {
		FailureLogger.error("WEB_DELETION", "INTERNAL_ERROR", exception);
		return WebDeletionPages.page(500, "잠시 후 다시 시도해 주세요", "<p>삭제 요청 결과를 확인할 수 없어요. 다시 본인 확인하거나 운영팀에 문의해 주세요.</p>");
	}
}
