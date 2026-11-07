package com.apptive.backend.domain.pair.entity;

import java.time.OffsetDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import com.apptive.backend.domain.user.entity.User;

@Entity
@Table(name = "pair_invitations")
public class PairInvitation {

	@Id
	@Column(length = 40, nullable = false, updatable = false)
	private String id;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "child_id", nullable = false, updatable = false)
	private User child;

	@Column(name = "invite_code", length = 6, nullable = false, unique = true, updatable = false)
	private String inviteCode;

	@Column(name = "expires_at", nullable = false, updatable = false)
	private OffsetDateTime expiresAt;

	@Column(name = "created_at", nullable = false, updatable = false)
	private OffsetDateTime createdAt;

	@Column(name = "used_at")
	private OffsetDateTime usedAt;

	protected PairInvitation() {
	}

	public PairInvitation(String id, User child, String inviteCode, OffsetDateTime expiresAt,
	    OffsetDateTime createdAt) {
		this.id = id;
		this.child = child;
		this.inviteCode = inviteCode;
		this.expiresAt = expiresAt;
		this.createdAt = createdAt;
	}

	public void markUsed(OffsetDateTime usedAt) {
		this.usedAt = usedAt;
	}

	public String getId() {
		return id;
	}

	public User getChild() {
		return child;
	}

	public String getInviteCode() {
		return inviteCode;
	}

	public OffsetDateTime getExpiresAt() {
		return expiresAt;
	}

	public OffsetDateTime getCreatedAt() {
		return createdAt;
	}

	public OffsetDateTime getUsedAt() {
		return usedAt;
	}
}
