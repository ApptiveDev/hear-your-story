package com.apptive.backend.domain.user.entity;

import java.time.OffsetDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import lombok.Getter;

@Getter
@Entity
@Table(name = "account_deletion_tasks")
public class AccountDeletionTask {

	@Id
	@Column(length = 40, nullable = false, updatable = false)
	private String id;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "deletion_request_id", nullable = false, updatable = false)
	private AccountDeletionRequest deletionRequest;

	@Enumerated(EnumType.STRING)
	@Column(name = "task_type", length = 30, nullable = false, updatable = false)
	private AccountDeletionTaskType taskType;

	@Column(name = "target_value", length = 1000, nullable = false, updatable = false)
	private String targetValue;

	@Enumerated(EnumType.STRING)
	@Column(length = 20, nullable = false)
	private AccountDeletionTaskStatus status;

	@Column(nullable = false)
	private int attempts;

	@Column(name = "next_attempt_at", nullable = false)
	private OffsetDateTime nextAttemptAt;

	@Column(name = "last_failure_code", length = 100)
	private String lastFailureCode;

	@Column(name = "created_at", nullable = false, updatable = false)
	private OffsetDateTime createdAt;

	@Column(name = "updated_at", nullable = false)
	private OffsetDateTime updatedAt;

	protected AccountDeletionTask() {
	}

	public AccountDeletionTask(String id, AccountDeletionRequest deletionRequest, AccountDeletionTaskType taskType,
	    String targetValue, OffsetDateTime now) {
		this.id = id;
		this.deletionRequest = deletionRequest;
		this.taskType = taskType;
		this.targetValue = targetValue;
		this.status = AccountDeletionTaskStatus.PENDING;
		this.nextAttemptAt = now;
		this.createdAt = now;
		this.updatedAt = now;
	}

	public void claim(OffsetDateTime now) {
		status = AccountDeletionTaskStatus.PROCESSING;
		attempts++;
		updatedAt = now;
	}

	public void retryAt(OffsetDateTime nextAttempt, String failureCode, OffsetDateTime now) {
		status = AccountDeletionTaskStatus.RETRY;
		nextAttemptAt = nextAttempt;
		lastFailureCode = failureCode;
		updatedAt = now;
	}
}
