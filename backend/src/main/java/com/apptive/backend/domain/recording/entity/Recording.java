package com.apptive.backend.domain.recording.entity;

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
import jakarta.persistence.UniqueConstraint;

import com.apptive.backend.domain.assignment.entity.Assignment;

import lombok.Getter;

@Getter
@Entity
@Table(name = "recordings", uniqueConstraints = @UniqueConstraint(name = "uk_recordings_assignment", columnNames = "assignment_id"))
public class Recording {

	@Id
	@Column(length = 40, nullable = false, updatable = false)
	private String id;

	@OneToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "assignment_id", nullable = false, updatable = false)
	private Assignment assignment;

	@Column(name = "object_key", length = 1000, nullable = false)
	private String objectKey;

	@Column(name = "original_filename", length = 255, nullable = false)
	private String originalFilename;

	@Column(name = "content_type", length = 100, nullable = false)
	private String contentType;

	@Column(name = "size_bytes", nullable = false)
	private long sizeBytes;

	@Column(name = "idempotency_key", length = 100)
	private String idempotencyKey;

	@Column(name = "processing_version", length = 36, nullable = false)
	private String processingVersion;

	@Enumerated(EnumType.STRING)
	@Column(name = "processing_status", length = 30, nullable = false)
	private ProcessingStatus processingStatus;

	@Column(name = "stt_text", columnDefinition = "text")
	private String sttText;

	@Column(name = "summary_text", columnDefinition = "text")
	private String summaryText;

	@Column(name = "failed_stage", length = 30)
	private String failedStage;

	@Column(name = "failure_code", length = 100)
	private String failureCode;

	@Column(name = "processing_notice", length = 500)
	private String processingNotice;

	@Column(name = "submitted_at", nullable = false)
	private OffsetDateTime submittedAt;

	@Column(name = "updated_at", nullable = false)
	private OffsetDateTime updatedAt;

	protected Recording() {
	}

	public Recording(String id, Assignment assignment, String objectKey, String originalFilename, String contentType,
	    long sizeBytes, String idempotencyKey, String processingVersion, OffsetDateTime now) {
		this.id = id;
		this.assignment = assignment;
		replaceFile(objectKey, originalFilename, contentType, sizeBytes, idempotencyKey, processingVersion, now);
	}

	public void replaceFile(String objectKey, String originalFilename, String contentType, long sizeBytes,
	    String idempotencyKey, String processingVersion, OffsetDateTime now) {
		this.objectKey = objectKey;
		this.originalFilename = originalFilename;
		this.contentType = contentType;
		this.sizeBytes = sizeBytes;
		this.idempotencyKey = idempotencyKey;
		this.processingVersion = processingVersion;
		this.processingStatus = ProcessingStatus.UPLOADED;
		this.sttText = null;
		this.summaryText = null;
		this.failedStage = null;
		this.failureCode = null;
		this.processingNotice = null;
		this.submittedAt = now;
		this.updatedAt = now;
	}

	public void markSttProcessing(OffsetDateTime now) {
		this.processingStatus = ProcessingStatus.STT_PROCESSING;
		this.updatedAt = now;
	}

	public void markSttDone(String sttText, OffsetDateTime now) {
		this.sttText = sttText;
		this.processingStatus = ProcessingStatus.STT_DONE;
		this.updatedAt = now;
	}

	public void markLlmProcessing(OffsetDateTime now) {
		this.processingStatus = ProcessingStatus.LLM_PROCESSING;
		this.updatedAt = now;
	}

	public void markReady(String summaryText, OffsetDateTime now) {
		this.summaryText = summaryText;
		this.processingStatus = ProcessingStatus.READY;
		this.updatedAt = now;
	}

	public void markFailed(String failedStage, String failureCode, String notice, OffsetDateTime now) {
		this.failedStage = failedStage;
		this.failureCode = failureCode;
		this.processingNotice = notice;
		this.processingStatus = ProcessingStatus.FAILED;
		this.updatedAt = now;
	}

	public void restartProcessing(String processingVersion, OffsetDateTime now) {
		this.processingVersion = processingVersion;
		this.processingStatus = ProcessingStatus.UPLOADED;
		this.sttText = null;
		this.summaryText = null;
		this.failedStage = null;
		this.failureCode = null;
		this.processingNotice = null;
		this.updatedAt = now;
	}

}
