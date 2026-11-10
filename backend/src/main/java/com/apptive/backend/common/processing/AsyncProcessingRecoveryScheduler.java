package com.apptive.backend.common.processing;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Component
@ConditionalOnProperty(name = "app.processing-recovery.enabled", havingValue = "true", matchIfMissing = true)
public class AsyncProcessingRecoveryScheduler {

	private static final Logger log = LoggerFactory.getLogger(AsyncProcessingRecoveryScheduler.class);

	private final AsyncProcessingRecoveryService recoveryService;

	@Scheduled(initialDelayString = "${app.processing-recovery.initial-delay:10s}", fixedDelayString = "${app.processing-recovery.fixed-delay:1m}")
	public void recover() {
		ProcessingRecoveryResult result = recoveryService.recoverStale();
		if (result.recordingCount() > 0 || result.answerCount() > 0) {
			log.info("Recovered stale async tasks: recordings={}, ttsAnswers={}", result.recordingCount(),
			    result.answerCount());
		}
	}
}
