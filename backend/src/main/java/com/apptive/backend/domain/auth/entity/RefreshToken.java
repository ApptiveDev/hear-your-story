package com.apptive.backend.domain.auth.entity;

import java.time.OffsetDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import com.apptive.backend.domain.user.entity.User;

import lombok.Getter;

@Getter
@Entity
@Table(name = "refresh_tokens")
public class RefreshToken {

	@Id
	@Column(length = 40, nullable = false, updatable = false)
	private String id;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "user_id", nullable = false, updatable = false)
	private User user;

	@Column(name = "token_hash", length = 64, nullable = false, unique = true, updatable = false)
	private String tokenHash;

	@Column(name = "expires_at", nullable = false, updatable = false)
	private OffsetDateTime expiresAt;

	@Column(name = "revoked_at")
	private OffsetDateTime revokedAt;

	@Column(name = "created_at", nullable = false, updatable = false)
	private OffsetDateTime createdAt;

	protected RefreshToken() {
	}

	public RefreshToken(String id, User user, String tokenHash, OffsetDateTime expiresAt, OffsetDateTime createdAt) {
		this.id = id;
		this.user = user;
		this.tokenHash = tokenHash;
		this.expiresAt = expiresAt;
		this.createdAt = createdAt;
	}

	public void revoke(OffsetDateTime revokedAt) {
		if (this.revokedAt == null) {
			this.revokedAt = revokedAt;
		}
	}

	public boolean isUsableAt(OffsetDateTime now) {
		return revokedAt == null && expiresAt.isAfter(now);
	}
}
