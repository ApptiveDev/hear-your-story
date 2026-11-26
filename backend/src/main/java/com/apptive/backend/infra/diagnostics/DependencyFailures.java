package com.apptive.backend.infra.diagnostics;

import java.net.SocketTimeoutException;
import java.net.UnknownHostException;
import java.nio.file.AccessDeniedException;
import java.nio.file.NoSuchFileException;
import java.util.Set;

import javax.net.ssl.SSLException;

import org.springframework.web.client.RestClientResponseException;

import com.apptive.backend.common.exception.DependencyException;
import com.fasterxml.jackson.databind.ObjectMapper;

import software.amazon.awssdk.services.s3.model.S3Exception;

/** 공급자 응답은 허용된 코드만 추출한다. 메시지·본문·URL·파일명은 진단 정보에 포함하지 않는다. */
public final class DependencyFailures {
	private static final ObjectMapper JSON = new ObjectMapper();
	private static final Set<String> CODES = Set.of("Unauthorized", "InvalidAccessKeyId", "SignatureDoesNotMatch",
	    "AccessDenied", "NoSuchBucket", "NoSuchKey", "SlowDown", "RequestTimeout", "InternalError", "invalid_api_key",
	    "insufficient_quota", "rate_limit_exceeded", "model_not_found", "invalid_request_error", "permission_denied",
	    "server_error");

	private DependencyFailures() {
	}

	public static DependencyException wrap(String provider, String operation, Throwable cause) {
		int status = 0;
		String code = "unknown";
		if (cause instanceof S3Exception s3) {
			status = s3.statusCode();
			code = allowed(s3.awsErrorDetails() == null ? null : s3.awsErrorDetails().errorCode());
		} else if (cause instanceof RestClientResponseException response) {
			status = response.getStatusCode().value();
			try {
				code = allowed(
				    JSON.readTree(response.getResponseBodyAsByteArray()).path("error").path("code").asText());
			} catch (Exception ignored) {
				// 프록시 등의 비JSON 응답이 와도 진단 처리 자체는 실패시키지 않는다.
			}
		}
		return new DependencyException(provider, operation, status, code, reason(status, code, cause), cause);
	}

	private static String allowed(String code) {
		return CODES.contains(code == null ? "" : code) ? code : "unknown";
	}

	private static String reason(int status, String code, Throwable cause) {
		if ("insufficient_quota".equals(code))
			return "QUOTA_EXHAUSTED";
		if (status == 401 || Set.of("InvalidAccessKeyId", "SignatureDoesNotMatch", "invalid_api_key").contains(code))
			return "AUTHENTICATION_FAILED";
		if (status == 403)
			return "PERMISSION_DENIED";
		if (status == 404)
			return "RESOURCE_NOT_FOUND";
		if (status == 429)
			return "rate_limit_exceeded".equals(code) || "SlowDown".equals(code)
			    ? "RATE_LIMITED"
			    : "THROTTLED_OR_QUOTA";
		if (status >= 500)
			return "UPSTREAM_UNAVAILABLE";
		if (status >= 400)
			return "INVALID_REQUEST";
		Throwable current = cause;
		for (int depth = 0; current != null && depth < 16; depth++, current = current.getCause()) {
			if (current instanceof SocketTimeoutException)
				return "TIMEOUT";
			if (current instanceof UnknownHostException)
				return "DNS_FAILED";
			if (current instanceof SSLException)
				return "TLS_FAILED";
			if (current instanceof AccessDeniedException)
				return "FILE_PERMISSION_DENIED";
			if (current instanceof NoSuchFileException)
				return "FILE_NOT_FOUND";
		}
		return "IO_OR_CLIENT_FAILURE";
	}
}
