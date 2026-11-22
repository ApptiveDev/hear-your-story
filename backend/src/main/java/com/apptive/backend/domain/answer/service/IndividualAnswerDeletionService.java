package com.apptive.backend.domain.answer.service;

import java.time.Clock;
import java.time.OffsetDateTime;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.domain.answer.entity.ChildAnswer;
import com.apptive.backend.domain.answer.repository.ChildAnswerRepository;
import com.apptive.backend.domain.assignment.entity.Assignment;
import com.apptive.backend.domain.assignment.repository.AssignmentRepository;
import com.apptive.backend.domain.recording.entity.Recording;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.user.repository.UserRepository;
import com.apptive.backend.infra.storage.StorageDeletionQueue;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class IndividualAnswerDeletionService {
	private final UserRepository userRepository;
	private final AssignmentRepository assignmentRepository;
	private final RecordingRepository recordingRepository;
	private final ChildAnswerRepository answerRepository;
	private final StorageDeletionQueue deletionQueue;
	private final Clock clock;

	@Transactional
	public void deleteRecording(String id, AuthenticatedUser user) {
		requireActive(user);
		String assignmentId = recordingRepository.findAssignmentId(id)
		    .orElseThrow(() -> new ApiException(ErrorCode.RECORDING_NOT_FOUND));
		Assignment assignment = assignmentRepository.findByIdForUpdate(assignmentId).orElseThrow();
		if (!assignment.isParentAuthor(user.userId(), user.role())) {
			throw new ApiException(ErrorCode.RESOURCE_ACCESS_DENIED);
		}
		Recording recording = recordingRepository.findByIdForUpdate(id).orElseThrow();
		if (recording.isDeleted())
			throw new ApiException(ErrorCode.RECORDING_NOT_FOUND);
		deletionQueue.enqueue(recording.deletePersonalData(OffsetDateTime.now(clock)));
	}

	@Transactional
	public void deleteAnswer(String id, AuthenticatedUser user) {
		requireActive(user);
		String assignmentId = answerRepository.findAssignmentId(id)
		    .orElseThrow(() -> new ApiException(ErrorCode.ANSWER_NOT_FOUND));
		Assignment assignment = assignmentRepository.findByIdForUpdate(assignmentId).orElseThrow();
		if (!assignment.isChildAuthor(user.userId(), user.role())) {
			throw new ApiException(ErrorCode.RESOURCE_ACCESS_DENIED);
		}
		ChildAnswer answer = answerRepository.findByIdForUpdate(id).orElseThrow();
		if (answer.isDeleted())
			throw new ApiException(ErrorCode.ANSWER_NOT_FOUND);
		deletionQueue.enqueue(answer.deletePersonalData(OffsetDateTime.now(clock)));
	}

	private void requireActive(AuthenticatedUser user) {
		if (!userRepository.findByIdForUpdate(user.userId()).orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED))
		    .isActive()) {
			throw new ApiException(ErrorCode.UNAUTHORIZED);
		}
	}
}
