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
@Table(name = "app_users", uniqueConstraints = @UniqueConstraint(name = "uk_app_users_device_role", columnNames = {
        "device_id", "role"}))
public class User {

	@Id
	@Column(length = 40, nullable = false, updatable = false)
	private String id;

	@Column(length = 50, nullable = false)
	private String name;

	@Enumerated(EnumType.STRING)
	@Column(length = 10, nullable = false, updatable = false)
	private Role role;

	@Column(name = "device_id", length = 255, nullable = false, updatable = false)
	private String deviceId;

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

}
