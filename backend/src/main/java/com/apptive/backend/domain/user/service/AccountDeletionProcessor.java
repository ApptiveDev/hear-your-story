package com.apptive.backend.domain.user.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.apptive.backend.domain.user.entity.AccountDeletionTaskType;
import com.apptive.backend.infra.storage.RecordingStorage;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Component
public class AccountDeletionProcessor {

	private static final Logger log = LoggerFactory.getLogger(AccountDeletionProcessor.class);
	private static final int BATCH_SIZE = 50;

	private final AccountDeletionTaskService taskService;
	private final RecordingStorage recordingStorage;
	private final KakaoAccountUnlinker kakaoAccountUnlinker;

	@Scheduled(initialDelayString = "${app.account-deletion.initial-delay:10s}", fixedDelayString = "${app.account-deletion.fixed-delay:1m}")
	public void processPendingTasks() {
		for (int processed = 0; processed < BATCH_SIZE; processed++) {
			AccountDeletionTaskClaim claim = taskService.claimNext().orElse(null);
			if (claim == null) {
				return;
			}
			process(claim);
		}
	}

	private void process(AccountDeletionTaskClaim claim) {
		try {
			if (claim.type() == AccountDeletionTaskType.STORAGE_OBJECT) {
				recordingStorage.delete(claim.targetValue());
			} else {
				kakaoAccountUnlinker.unlink(claim.targetValue());
			}
			taskService.complete(claim.taskId());
		} catch (RuntimeException exception) {
			taskService.retry(claim.taskId(), exception.getClass().getSimpleName());
			log.warn("Account deletion task will be retried: type={}", claim.type());
		}
	}
}
