package com.apptive.backend.infra.storage;

import java.time.OffsetDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import lombok.Getter;

@Getter
@Entity
@Table(name = "storage_deletion_tasks")
public class StorageDeletionTask {
	@Id
	@Column(length = 40)
	private String id;
	@Column(name = "object_key", length = 1000, nullable = false, updatable = false)
	private String objectKey;
	@Column(name = "next_attempt_at", nullable = false)
	private OffsetDateTime nextAttemptAt;
	@Column(nullable = false)
	private int attempts;

	protected StorageDeletionTask() {
	}

	public StorageDeletionTask(String id, String objectKey, OffsetDateTime now) {
		this.id = id;
		this.objectKey = objectKey;
		this.nextAttemptAt = now;
	}

	public void claim(OffsetDateTime now) {
		attempts++;
		nextAttemptAt = now.plusMinutes(5);
	}
}
