package com.apptive.backend.domain.user.entity;

import java.time.OffsetDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

import lombok.Getter;

@Getter
@Entity
@Table(name = "app_users", uniqueConstraints = @UniqueConstraint(name = "uk_app_users_auth_identity", columnNames = {
        "auth_provider", "auth_subject"}))
public class User {

	@Id
	@Column(length = 40, nullable = false, updatable = false)
	private String id;

	@Column(length = 50, nullable = false)
	private String name;

	@Enumerated(EnumType.STRING)
	@Column(length = 10, nullable = false, updatable = false)
	private Role role;

	@Column(name = "device_id", length = 255)
	private String deviceId;

	@Enumerated(EnumType.STRING)
	@Column(name = "auth_provider", length = 20)
	private AuthProvider authProvider;

	@Column(name = "auth_subject", length = 255)
	private String authSubject;

	@Enumerated(EnumType.STRING)
	@Column(name = "account_status", length = 30, nullable = false)
	private AccountStatus accountStatus = AccountStatus.ACTIVE;

	@Column(name = "deleted_at")
	private OffsetDateTime deletedAt;

	@Column(name = "created_at", nullable = false, updatable = false)
	private OffsetDateTime createdAt;

	protected User() {
	}

	public User(String id, String name, Role role, String deviceId, OffsetDateTime createdAt) {
		this.id = id;
		this.name = name;
		this.role = role;
		this.deviceId = deviceId;
		this.createdAt = createdAt;
	}

	public User(String id, String name, Role role, AuthProvider authProvider, String authSubject,
	    OffsetDateTime createdAt) {
		this.id = id;
		this.name = name;
		this.role = role;
		this.authProvider = authProvider;
		this.authSubject = authSubject;
		this.createdAt = createdAt;
	}

	public boolean isActive() {
		return accountStatus == AccountStatus.ACTIVE;
	}

	public void requestDeletion(OffsetDateTime now) {
		this.name = "탈퇴한 사용자";
		this.deviceId = null;
		this.authProvider = null;
		this.authSubject = null;
		this.accountStatus = AccountStatus.DELETION_PENDING;
		this.deletedAt = now;
	}

	public void completeDeletion() {
		this.accountStatus = AccountStatus.DELETED;
	}

}
