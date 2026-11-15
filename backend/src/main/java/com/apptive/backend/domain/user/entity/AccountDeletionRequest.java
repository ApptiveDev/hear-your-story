package com.apptive.backend.domain.user.entity;

import java.time.OffsetDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;

import lombok.Getter;

@Getter
@Entity
@Table(name = "account_deletion_requests")
public class AccountDeletionRequest {

	@Id
	@Column(length = 40, nullable = false, updatable = false)
	private String id;

	@OneToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "user_id", nullable = false, updatable = false)
	private User user;

	@Enumerated(EnumType.STRING)
	@Column(name = "auth_provider", length = 20)
	private AuthProvider authProvider;

	@Column(name = "auth_subject_hash", length = 64)
	private String authSubjectHash;

	@Enumerated(EnumType.STRING)
	@Column(length = 30, nullable = false)
	private AccountDeletionStatus status;

	@Column(name = "requested_at", nullable = false, updatable = false)
	private OffsetDateTime requestedAt;

	@Column(name = "completed_at")
	private OffsetDateTime completedAt;

	@Column(name = "updated_at", nullable = false)
	private OffsetDateTime updatedAt;

	protected AccountDeletionRequest() {
	}

	public AccountDeletionRequest(String id, User user, AuthProvider authProvider, String authSubjectHash,
	    OffsetDateTime requestedAt) {
		this.id = id;
		this.user = user;
		this.authProvider = authProvider;
		this.authSubjectHash = authSubjectHash;
		this.status = AccountDeletionStatus.PROCESSING;
		this.requestedAt = requestedAt;
		this.updatedAt = requestedAt;
	}

	public void complete(OffsetDateTime now) {
		status = AccountDeletionStatus.COMPLETED;
		authProvider = null;
		authSubjectHash = null;
		completedAt = now;
		updatedAt = now;
		user.completeDeletion();
	}
}
