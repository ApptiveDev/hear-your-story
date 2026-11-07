package com.apptive.backend.domain.recording.service;

import java.time.Clock;
import java.time.OffsetDateTime;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.domain.recording.dto.RecordingStatusResponse;
import com.apptive.backend.domain.recording.entity.Recording;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.user.entity.Role;

@Service
public class RecordingStatusService {

	private final RecordingRepository recordingRepository;
	private final Clock clock;

	public RecordingStatusService(RecordingRepository recordingRepository, Clock clock) {
		this.recordingRepository = recordingRepository;
		this.clock = clock;
	}

	@Transactional(readOnly = true)
	public RecordingStatusResponse get(String recordingId, AuthenticatedUser authenticatedUser) {
		if (authenticatedUser.role() != Role.PARENT) {
			throw new ApiException(ErrorCode.ROLE_NOT_ALLOWED);
		}
		Recording recording = find(recordingId);
		if (!recording.getAssignment().getFamilyPair().getParent().getId().equals(authenticatedUser.userId())) {
			throw new ApiException(ErrorCode.PAIR_ACCESS_DENIED);
		}
		return toResponse(recording);
	}

	@Transactional
	public boolean markSttProcessing(String recordingId, String version) {
		Recording recording = find(recordingId);
		if (!isCurrent(recording, version)) {
			return false;
		}
		recording.markSttProcessing(now());
		return true;
	}

	@Transactional(readOnly = true)
	public RecordingProcessingSource findProcessingSource(String recordingId, String version) {
		Recording recording = find(recordingId);
		if (!isCurrent(recording, version)) {
			return null;
		}
		return new RecordingProcessingSource(recording.getObjectKey(), recording.getOriginalFilename(),
		    recording.getContentType());
	}

	@Transactional
	public boolean markSttDone(String recordingId, String version, String sttText) {
		Recording recording = find(recordingId);
		if (!isCurrent(recording, version)) {
			return false;
		}
		recording.markSttDone(sttText, now());
		return true;
	}

	@Transactional
	public boolean markLlmProcessing(String recordingId, String version) {
		Recording recording = find(recordingId);
		if (!isCurrent(recording, version)) {
			return false;
		}
		recording.markLlmProcessing(now());
		return true;
	}

	@Transactional
	public boolean markReady(String recordingId, String version, String summaryText) {
		Recording recording = find(recordingId);
		if (!isCurrent(recording, version)) {
			return false;
		}
		recording.markReady(summaryText, now());
		return true;
	}

	@Transactional
	public void markFailed(String recordingId, String version, String failedStage, String failureCode) {
		Recording recording = find(recordingId);
		if (!isCurrent(recording, version)) {
			return;
		}
		recording.markFailed(failedStage, failureCode, "음성 정리는 실패했지만 원본 녹음은 안전하게 저장되었습니다.", now());
	}

	private Recording find(String recordingId) {
		return recordingRepository.findById(recordingId)
		    .orElseThrow(() -> new ApiException(ErrorCode.RECORDING_NOT_FOUND));
	}

	private boolean isCurrent(Recording recording, String version) {
		return recording.getProcessingVersion().equals(version);
	}

	private OffsetDateTime now() {
		return OffsetDateTime.now(clock);
	}

	private RecordingStatusResponse toResponse(Recording recording) {
		return new RecordingStatusResponse(recording.getId(), recording.getAssignment().getId(),
		    recording.getProcessingStatus(), recording.getSttText(), recording.getSummaryText(),
		    recording.getFailedStage(), recording.getFailureCode(), recording.getProcessingNotice(),
		    recording.getUpdatedAt());
	}
}
