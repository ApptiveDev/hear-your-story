package com.apptive.backend.common.exception;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Clock;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import com.apptive.backend.common.web.TraceIdFilter;
import com.apptive.backend.infra.diagnostics.DependencyFailures;

import software.amazon.awssdk.awscore.exception.AwsErrorDetails;
import software.amazon.awssdk.services.s3.model.S3Exception;

@ExtendWith(OutputCaptureExtension.class)
class FailureHandlingTest {
	@Test
	void preservesContractAndMatchesResponseTraceToSafeLog(CapturedOutput output) throws Exception {
		var mvc = MockMvcBuilders.standaloneSetup(new FailingController())
		    .setControllerAdvice(new GlobalExceptionHandler(new ApiErrorFactory(Clock.systemUTC())))
		    .addFilters(new TraceIdFilter()).build();
		var result = mvc.perform(get("/test-storage")).andExpect(status().isBadGateway())
		    .andExpect(jsonPath("$.errorCode").value("STORAGE_ERROR"))
		    .andExpect(jsonPath("$.message").value(ErrorCode.STORAGE_ERROR.message())).andReturn();
		String trace = result.getResponse().getHeader("X-Trace-Id");
		assertThat(result.getResponse().getContentAsString()).contains(trace).doesNotContain("private-key");
		assertThat(output.getOut()).contains("traceId=" + trace, "provider=R2", "reason=AUTHENTICATION_FAILED")
		    .doesNotContain("private-key", "private-signed-url");
	}

	@RestController
	static class FailingController {
		@GetMapping("/test-storage")
		void fail() {
			var cause = S3Exception.builder().statusCode(401).message("private-key private-signed-url")
			    .awsErrorDetails(AwsErrorDetails.builder().errorCode("Unauthorized").build()).build();
			throw new StorageException(DependencyFailures.wrap("R2", "UPLOAD_RECORDING", cause));
		}
	}
}
