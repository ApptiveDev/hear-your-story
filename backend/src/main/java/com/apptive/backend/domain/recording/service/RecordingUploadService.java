package com.apptive.backend.domain.recording.service;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.Objects;
import java.util.UUID;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.common.id.IdGenerator;
import com.apptive.backend.domain.answer.repository.ChildAnswerRepository;
import com.apptive.backend.domain.assignment.entity.Assignment;
import com.apptive.backend.domain.assignment.entity.SubmissionStatus;
import com.apptive.backend.domain.assignment.repository.AssignmentRepository;
import com.apptive.backend.domain.recording.dto.RecordingUploadResponse;
import com.apptive.backend.domain.recording.entity.Recording;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.infra.storage.RecordingStorage;

@Service
public class RecordingUploadService {

	private final AssignmentRepository assignmentRepository;
	private final RecordingRepository recordingRepository;
	private final ChildAnswerRepository childAnswerRepository;
	private final RecordingStorage recordingStorage;
	private final AudioFileValidator audioFileValidator;
	private final IdGenerator idGenerator;
	private final Clock clock;
	private final ApplicationEventPublisher eventPublisher;

	public RecordingUploadService(AssignmentRepository assignmentRepository, RecordingRepository recordingRepository,
	    ChildAnswerRepository childAnswerRepository, RecordingStorage recordingStorage,
	    AudioFileValidator audioFileValidator, IdGenerator idGenerator, Clock clock,
	    ApplicationEventPublisher eventPublisher) {
		this.assignmentRepository = assignmentRepository;
		this.recordingRepository = recordingRepository;
		this.childAnswerRepository = childAnswerRepository;
		this.recordingStorage = recordingStorage;
		this.audioFileValidator = audioFileValidator;
		this.idGenerator = idGenerator;
		this.clock = clock;
		this.eventPublisher = eventPublisher;
	}

	@Transactional
	public RecordingUploadResponse put(String assignmentId, MultipartFile audioFile, String idempotencyKey,
	    AuthenticatedUser authenticatedUser) {
		if (authenticatedUser.role() != Role.PARENT) {
			throw new ApiException(ErrorCode.ROLE_NOT_ALLOWED);
		}

		Assignment assignment = assignmentRepository.findByIdForUpdate(assignmentId)
		    .orElseThrow(() -> new ApiException(ErrorCode.ASSIGNMENT_NOT_FOUND));
		if (!assignment.getFamilyPair().getParent().getId().equals(authenticatedUser.userId())) {
			throw new ApiException(ErrorCode.PAIR_ACCESS_DENIED);
		}

		String normalizedKey = normalizeIdempotencyKey(idempotencyKey);
		Recording existing = recordingRepository.findByAssignment_Id(assignmentId).orElse(null);
		if (existing != null && normalizedKey != null && Objects.equals(existing.getIdempotencyKey(), normalizedKey)) {
			return toResponse(existing);
		}
		if (existing != null && childAnswerRepository.findByAssignment_Id(assignmentId).isPresent()) {
			throw new ApiException(ErrorCode.ANSWER_LOCKED);
		}

		audioFileValidator.validate(audioFile);
		String recordingId = existing == null ? idGenerator.generate("rec") : existing.getId();
		String newObjectKey = recordingStorage.store(recordingId, audioFile);
		String previousObjectKey = existing == null ? null : existing.getObjectKey();
		OffsetDateTime now = OffsetDateTime.now(clock);
		String processingVersion = UUID.randomUUID().toString();

		try {
			Recording recording;
			if (existing == null) {
				recording = new Recording(recordingId, assignment, newObjectKey, audioFile.getOriginalFilename(),
				    audioFile.getContentType(), audioFile.getSize(), normalizedKey, processingVersion, now);
			} else {
				existing.replaceFile(newObjectKey, audioFile.getOriginalFilename(), audioFile.getContentType(),
				    audioFile.getSize(), normalizedKey, processingVersion, now);
				recording = existing;
			}
			Recording saved = recordingRepository.save(recording);
			if (previousObjectKey != null && !previousObjectKey.equals(newObjectKey)) {
				recordingStorage.delete(previousObjectKey);
			}
			eventPublisher.publishEvent(new RecordingUploadedEvent(saved.getId(), processingVersion));
			return toResponse(saved);
		} catch (RuntimeException exception) {
			recordingStorage.delete(newObjectKey);
			throw exception;
		}
	}

	private String normalizeIdempotencyKey(String idempotencyKey) {
		if (idempotencyKey == null || idempotencyKey.isBlank()) {
			return null;
		}
		String normalized = idempotencyKey.trim();
		if (normalized.length() > 100) {
			throw new ApiException(ErrorCode.VALIDATION_ERROR);
		}
		return normalized;
	}

	private RecordingUploadResponse toResponse(Recording recording) {
		return new RecordingUploadResponse(recording.getId(), recording.getAssignment().getId(),
		    SubmissionStatus.SUBMITTED, recording.getProcessingStatus(), recording.getSubmittedAt(),
		    "/api/v1/recordings/" + recording.getId());
	}
}
