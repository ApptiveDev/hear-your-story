package com.apptive.backend.common.config;

import java.util.Map;
import java.util.concurrent.Executor;

import org.slf4j.MDC;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

@Configuration
@EnableAsync
@EnableScheduling
public class AsyncConfig {

	@Bean(name = "recordingTaskExecutor")
	public Executor recordingTaskExecutor() {
		ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
		executor.setCorePoolSize(2);
		executor.setMaxPoolSize(4);
		executor.setQueueCapacity(100);
		executor.setThreadNamePrefix("recording-");
		executor.setTaskDecorator(task -> {
			Map<String, String> context = MDC.getCopyOfContextMap();
			return () -> {
				Map<String, String> previous = MDC.getCopyOfContextMap();
				try {
					if (context == null)
						MDC.clear();
					else
						MDC.setContextMap(context);
					task.run();
				} finally {
					if (previous == null)
						MDC.clear();
					else
						MDC.setContextMap(previous);
				}
			};
		});
		executor.initialize();
		return executor;
	}
}
