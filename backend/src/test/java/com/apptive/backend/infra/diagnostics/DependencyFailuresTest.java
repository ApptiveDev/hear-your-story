package com.apptive.backend.infra.diagnostics;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.SocketTimeoutException;
import java.nio.charset.StandardCharsets;
import java.nio.file.AccessDeniedException;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.slf4j.MDC;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.http.HttpStatus;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.ResourceAccessException;

import com.apptive.backend.common.exception.DependencyException;
import com.apptive.backend.common.exception.FailureLogger;
import com.apptive.backend.common.exception.StorageException;

import software.amazon.awssdk.awscore.exception.AwsErrorDetails;
import software.amazon.awssdk.services.s3.model.S3Exception;

@ExtendWith(OutputCaptureExtension.class)
class DependencyFailuresTest {
	@Test
	void distinguishesQuotaFromRateLimitAndPreservesOriginalCause() {
		for (String code : new String[]{"insufficient_quota", "rate_limit_exceeded"}) {
			var original = HttpClientErrorException.create(HttpStatus.TOO_MANY_REQUESTS, "private-url", null,
			    ("{\"error\":{\"code\":\"" + code + "\",\"message\":\"private-transcript\"}}")
			        .getBytes(StandardCharsets.UTF_8),
			    null);
			DependencyException failure = DependencyFailures.wrap("OPENAI", "STT", original);
			assertThat(failure.getCause()).isSameAs(original);
			assertThat(failure.providerCode()).isEqualTo(code);
			assertThat(failure.reason())
			    .isEqualTo(code.equals("insufficient_quota") ? "QUOTA_EXHAUSTED" : "RATE_LIMITED");
		}
	}

	@Test
	void classifiesR2AuthenticationPermissionAndMissingBucket() {
		int[] statuses = {401, 403, 404};
		String[] codes = {"Unauthorized", "AccessDenied", "NoSuchBucket"};
		String[] reasons = {"AUTHENTICATION_FAILED", "PERMISSION_DENIED", "RESOURCE_NOT_FOUND"};
		for (int i = 0; i < statuses.length; i++) {
			var original = S3Exception.builder().statusCode(statuses[i])
			    .awsErrorDetails(AwsErrorDetails.builder().errorCode(codes[i]).build()).build();
			assertThat(DependencyFailures.wrap("R2", "READ_AUDIO", original).reason()).isEqualTo(reasons[i]);
		}
	}

	@Test
	void classifiesNestedTimeoutAndLocalPermissionFailure() {
		var timeout = new ResourceAccessException("private-url", new SocketTimeoutException("private-message"));
		assertThat(DependencyFailures.wrap("OPENAI", "LLM", timeout).reason()).isEqualTo("TIMEOUT");
		assertThat(DependencyFailures.wrap("LOCAL", "READ_AUDIO", new AccessDeniedException("private-path")).reason())
		    .isEqualTo("FILE_PERMISSION_DENIED");
	}

	@Test
	void logsOnlyAllowedMetadataAndTraceId(CapturedOutput output) {
		var original = HttpClientErrorException.create(HttpStatus.UNAUTHORIZED, "private-url", null,
		    "{\"error\":{\"code\":\"private-api-key\",\"message\":\"private-transcript\"}}"
		        .getBytes(StandardCharsets.UTF_8),
		    null);
		var failure = new StorageException(DependencyFailures.wrap("R2", "UPLOAD_RECORDING", original));
		try (var ignored = MDC.putCloseable("traceId", "test-trace-id")) {
			FailureLogger.error("HTTP", "STORAGE_ERROR", failure);
		}
		assertThat(output.getOut()).contains("traceId=test-trace-id", "provider=R2", "httpStatus=401",
		    "providerCode=unknown", "reason=AUTHENTICATION_FAILED")
		    .doesNotContain("private-url", "private-api-key", "private-transcript");
	}

	@Test
	void nonJsonErrorBodyDoesNotBreakFailureHandling() {
		var original = HttpClientErrorException.create(HttpStatus.BAD_REQUEST, "private-url", null,
		    "<html>private-message</html>".getBytes(StandardCharsets.UTF_8), null);
		assertThat(DependencyFailures.wrap("OPENAI", "STT", original).providerCode()).isEqualTo("unknown");
	}
}
