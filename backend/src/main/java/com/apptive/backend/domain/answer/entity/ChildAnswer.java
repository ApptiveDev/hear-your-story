package com.apptive.backend.domain.answer.entity;

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

@Entity
@Table(name = "child_answers", uniqueConstraints = @UniqueConstraint(name = "uk_child_answers_assignment", columnNames = "assignment_id"))
public class ChildAnswer {

	@Id
	@Column(length = 40, nullable = false, updatable = false)
	private String id;

	@OneToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "assignment_id", nullable = false, updatable = false)
	private Assignment assignment;

	@Column(length = 1000, nullable = false)
	private String text;

	@Enumerated(EnumType.STRING)
	@Column(name = "tts_status", length = 20, nullable = false)
	private TtsStatus ttsStatus;

	@Column(name = "tts_object_key", length = 1000)
	private String ttsObjectKey;

	@Column(name = "tts_version", length = 36)
	private String ttsVersion;

	@Column(name = "tts_processing_notice", length = 500)
	private String ttsProcessingNotice;

	@Column(name = "submitted_at", nullable = false, updatable = false)
	private OffsetDateTime submittedAt;

	@Column(name = "updated_at", nullable = false)
	private OffsetDateTime updatedAt;

	protected ChildAnswer() {
	}

	public ChildAnswer(String id, Assignment assignment, String text, TtsStatus ttsStatus, String ttsVersion,
	    OffsetDateTime submittedAt, OffsetDateTime updatedAt) {
		this.id = id;
		this.assignment = assignment;
		this.text = text;
		this.ttsStatus = ttsStatus;
		this.ttsVersion = ttsVersion;
		this.submittedAt = submittedAt;
		this.updatedAt = updatedAt;
	}

	public void update(String text, String ttsVersion, OffsetDateTime updatedAt) {
		this.text = text;
		this.ttsStatus = TtsStatus.PROCESSING;
		this.ttsVersion = ttsVersion;
		this.ttsProcessingNotice = null;
		this.updatedAt = updatedAt;
	}

	public boolean hasTtsVersion(String version) {
		return ttsVersion != null && ttsVersion.equals(version);
	}

	public String markTtsReady(String objectKey, OffsetDateTime updatedAt) {
		String previousObjectKey = this.ttsObjectKey;
		this.ttsObjectKey = objectKey;
		this.ttsStatus = TtsStatus.READY;
		this.ttsProcessingNotice = null;
		this.updatedAt = updatedAt;
		return previousObjectKey;
	}

	public void markTtsFailed(String notice, OffsetDateTime updatedAt) {
		this.ttsStatus = TtsStatus.FAILED;
		this.ttsProcessingNotice = notice;
		this.updatedAt = updatedAt;
	}

	public String getId() {
		return id;
	}

	public Assignment getAssignment() {
		return assignment;
	}

	public String getText() {
		return text;
	}

	public TtsStatus getTtsStatus() {
		return ttsStatus;
	}

	public String getTtsObjectKey() {
		return ttsObjectKey;
	}

	public String getTtsVersion() {
		return ttsVersion;
	}

	public String getTtsProcessingNotice() {
		return ttsProcessingNotice;
	}

	public OffsetDateTime getSubmittedAt() {
		return submittedAt;
	}

	public OffsetDateTime getUpdatedAt() {
		return updatedAt;
	}
}
