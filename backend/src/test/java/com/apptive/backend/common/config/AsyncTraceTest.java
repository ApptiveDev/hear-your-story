package com.apptive.backend.common.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import com.apptive.backend.common.web.TraceIdFilter;

class AsyncTraceTest {
	@Test
	void propagatesHttpTraceAndClearsContextAfterRequestAndTask() throws Exception {
		var executor = (ThreadPoolTaskExecutor) new AsyncConfig().recordingTaskExecutor();
		// 하나의 스레드를 재사용해서 작업 사이 MDC 누출을 확인한다.
		executor.setCorePoolSize(1);
		executor.setMaxPoolSize(1);
		var response = new MockHttpServletResponse();
		try {
			new TraceIdFilter().doFilter(new MockHttpServletRequest(), response, (request, reply) -> {
				try {
					assertThat(executor.submit(() -> MDC.get("traceId")).get(5, TimeUnit.SECONDS))
					    .isEqualTo(response.getHeader("X-Trace-Id"));
				} catch (Exception exception) {
					throw new AssertionError(exception);
				}
			});
			assertThat(MDC.get("traceId")).isNull();
			assertThat(executor.submit(() -> MDC.get("traceId")).get(5, TimeUnit.SECONDS)).isNull();
		} finally {
			executor.shutdown();
		}
	}
}
