package com.apptive.backend.common.exception;

import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.web.client.RestClientResponseException;

/** 처리 경계에서 한 번 호출한다. Throwable 자체를 로거에 넘기면 민감한 메시지가 노출될 수 있다. */
public final class FailureLogger {
	private static final Logger log = LoggerFactory.getLogger(FailureLogger.class);
	private FailureLogger() {
	}

	public static void error(String stage, String failureCode, Throwable exception) {
		Throwable root = exception;
		DependencyException dependency = null;
		int status = 0;
		for (int depth = 0; depth < 16; depth++) {
			if (root instanceof DependencyException value)
				dependency = value;
			if (root instanceof RestClientResponseException response)
				status = response.getStatusCode().value();
			if (root.getCause() == null || root.getCause() == root)
				break;
			root = root.getCause();
		}
		String traceId = MDC.get("traceId");
		if (traceId == null)
			traceId = UUID.randomUUID().toString();
		String location = "unknown";
		for (StackTraceElement frame : exception.getStackTrace()) {
			if (frame.getClassName().startsWith("com.apptive.backend.")) {
				location = frame.getClassName() + "." + frame.getMethodName() + ":" + frame.getLineNumber();
				break;
			}
		}
		log.error(
		    "Operation failed: traceId={}, stage={}, failureCode={}, provider={}, operation={}, httpStatus={}, providerCode={}, reason={}, causeType={}, location={}",
		    traceId, stage, failureCode, dependency == null ? "unknown" : dependency.provider(),
		    dependency == null ? "unknown" : dependency.operation(),
		    dependency == null ? status : dependency.upstreamStatus(),
		    dependency == null ? "unknown" : dependency.providerCode(),
		    dependency == null ? "UNCLASSIFIED" : dependency.reason(), root.getClass().getSimpleName(), location);
	}
}
