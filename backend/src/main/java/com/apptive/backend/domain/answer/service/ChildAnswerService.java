package com.apptive.backend.domain.answer.service;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.UUID;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.common.id.IdGenerator;
import com.apptive.backend.domain.answer.dto.ChildAnswerResponse;
import com.apptive.backend.domain.answer.entity.ChildAnswer;
import com.apptive.backend.domain.answer.entity.TtsStatus;
import com.apptive.backend.domain.answer.repository.ChildAnswerRepository;
import com.apptive.backend.domain.assignment.entity.Assignment;
import com.apptive.backend.domain.assignment.entity.SubmissionStatus;
import com.apptive.backend.domain.assignment.repository.AssignmentRepository;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.user.entity.Role;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Service
public class ChildAnswerService {

	private static final int MAX_TEXT_LENGTH = 1000;

	private final AssignmentRepository assignmentRepository;
	private final ChildAnswerRepository childAnswerRepository;
	private final RecordingRepository recordingRepository;
	private final IdGenerator idGenerator;
	private final Clock clock;
	private final ApplicationEventPublisher eventPublisher;

	@Transactional
	public ChildAnswerResponse put(String assignmentId, String rawText, AuthenticatedUser authenticatedUser) {
		if (authenticatedUser.role() != Role.CHILD) {
			throw new ApiException(ErrorCode.ROLE_NOT_ALLOWED);
		}

		Assignment assignment = assignmentRepository.findByIdForUpdate(assignmentId)
		    .orElseThrow(() -> new ApiException(ErrorCode.ASSIGNMENT_NOT_FOUND));
		if (!assignment.getFamilyPair().getChild().getId().equals(authenticatedUser.userId())) {
			throw new ApiException(ErrorCode.PAIR_ACCESS_DENIED);
		}

		String text = rawText.trim();
		if (text.isEmpty() || text.length() > MAX_TEXT_LENGTH) {
			throw new ApiException(ErrorCode.VALIDATION_ERROR);
		}

		ChildAnswer existing = childAnswerRepository.findByAssignment_Id(assignmentId).orElse(null);
		if (existing != null && recordingRepository.findByAssignment_Id(assignmentId).isPresent()) {
			throw new ApiException(ErrorCode.ANSWER_LOCKED);
		}

		OffsetDateTime now = OffsetDateTime.now(clock);
		String ttsVersion = UUID.randomUUID().toString();
		ChildAnswer answer;
		if (existing == null) {
			answer = new ChildAnswer(idGenerator.generate("ans"), assignment, text, TtsStatus.PROCESSING, ttsVersion,
			    now, now);
		} else {
			existing.update(text, ttsVersion, now);
			answer = existing;
		}

		ChildAnswer saved = childAnswerRepository.save(answer);
		eventPublisher.publishEvent(new ChildAnswerSavedEvent(saved.getId(), ttsVersion));
		return toResponse(saved);
	}

	private ChildAnswerResponse toResponse(ChildAnswer answer) {
		return new ChildAnswerResponse(answer.getId(), answer.getAssignment().getId(), answer.getText(),
		    SubmissionStatus.SUBMITTED, answer.getTtsStatus(), answer.getSubmittedAt(), answer.getUpdatedAt());
	}
}
