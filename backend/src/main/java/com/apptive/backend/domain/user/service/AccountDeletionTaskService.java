package com.apptive.backend.domain.user.service;

import java.time.Clock;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.EnumSet;
import java.util.Optional;

import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.domain.user.entity.AccountDeletionRequest;
import com.apptive.backend.domain.user.entity.AccountDeletionTask;
import com.apptive.backend.domain.user.entity.AccountDeletionTaskStatus;
import com.apptive.backend.domain.user.repository.AccountDeletionRequestRepository;
import com.apptive.backend.domain.user.repository.AccountDeletionTaskRepository;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Service
public class AccountDeletionTaskService {

	private static final Duration STALE_AFTER = Duration.ofMinutes(5);
	private static final Duration MAX_RETRY_DELAY = Duration.ofHours(6);

	private final AccountDeletionTaskRepository taskRepository;
	private final AccountDeletionRequestRepository requestRepository;
	private final Clock clock;

	@Transactional
	public Optional<AccountDeletionTaskClaim> claimNext() {
		OffsetDateTime now = OffsetDateTime.now(clock);
		return taskRepository
		    .findReadyForUpdate(EnumSet.of(AccountDeletionTaskStatus.PENDING, AccountDeletionTaskStatus.RETRY),
		        AccountDeletionTaskStatus.PROCESSING, now, now.minus(STALE_AFTER), PageRequest.of(0, 1))
		    .stream().findFirst().map(task -> {
			    task.claim(now);
			    return new AccountDeletionTaskClaim(task.getId(), task.getTaskType(), task.getTargetValue());
		    });
	}

	@Transactional
	public void complete(String taskId) {
		AccountDeletionTask task = taskRepository.findById(taskId).orElse(null);
		if (task == null) {
			return;
		}
		String requestId = task.getDeletionRequest().getId();
		AccountDeletionRequest request = requestRepository.findByIdForUpdate(requestId).orElseThrow();
		taskRepository.delete(task);
		taskRepository.flush();
		if (!taskRepository.existsByDeletionRequest_Id(requestId)) {
			request.complete(OffsetDateTime.now(clock));
		}
	}

	@Transactional
	public void retry(String taskId, String failureCode) {
		taskRepository.findById(taskId).ifPresent(task -> {
			OffsetDateTime now = OffsetDateTime.now(clock);
			long delayMinutes = Math.min(1L << Math.min(task.getAttempts(), 8), MAX_RETRY_DELAY.toMinutes());
			task.retryAt(now.plusMinutes(delayMinutes), failureCode, now);
		});
	}
}
