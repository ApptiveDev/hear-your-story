package com.apptive.backend.domain.story.service;

import java.time.OffsetDateTime;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.domain.answer.entity.ChildAnswer;
import com.apptive.backend.domain.answer.repository.ChildAnswerRepository;
import com.apptive.backend.domain.assignment.entity.Assignment;
import com.apptive.backend.domain.assignment.repository.AssignmentRepository;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.question.entity.Question;
import com.apptive.backend.domain.recording.entity.Recording;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.story.dto.StoryChildAnswerResponse;
import com.apptive.backend.domain.story.dto.StoryItemResponse;
import com.apptive.backend.domain.story.dto.StoryPageResponse;
import com.apptive.backend.domain.story.dto.StoryParentAnswerResponse;
import com.apptive.backend.domain.story.dto.StoryQuestionResponse;
import com.apptive.backend.infra.storage.RecordingStorage;
import com.apptive.backend.infra.storage.SignedAudioUrl;

import lombok.RequiredArgsConstructor;

@Transactional(readOnly = true)
@RequiredArgsConstructor
@Service
public class StoryService {

	private static final int DEFAULT_LIMIT = 20;
	private static final int MAX_LIMIT = 50;
	private static final DateTimeFormatter MONTH_FORMATTER = DateTimeFormatter.ofPattern("uuuu-MM");

	private final FamilyPairRepository familyPairRepository;
	private final AssignmentRepository assignmentRepository;
	private final RecordingRepository recordingRepository;
	private final ChildAnswerRepository childAnswerRepository;
	private final RecordingStorage recordingStorage;

	public StoryPageResponse getStories(String month, String encodedCursor, Integer requestedLimit,
	    AuthenticatedUser authenticatedUser) {
		if (month != null) {
			return getStoriesByMonth(month, encodedCursor, requestedLimit, authenticatedUser);
		}

		int limit = requestedLimit == null ? DEFAULT_LIMIT : requestedLimit;
		if (limit < 1 || limit > MAX_LIMIT) {
			throw new ApiException(ErrorCode.VALIDATION_ERROR);
		}
		requirePairHistory(authenticatedUser.userId());
		StoryCursor cursor = StoryCursor.decode(encodedCursor);
		PageRequest pageRequest = PageRequest.of(0, limit + 1);
		List<Assignment> fetched = cursor == null
		    ? assignmentRepository.findRevealedFirstPage(authenticatedUser.userId(), pageRequest)
		    : assignmentRepository.findRevealedAfter(authenticatedUser.userId(), cursor.assignedDate(),
		        cursor.assignmentId(), pageRequest);

		boolean hasNext = fetched.size() > limit;
		List<Assignment> page = hasNext ? fetched.subList(0, limit) : fetched;
		if (page.isEmpty()) {
			return new StoryPageResponse(List.of(), null, false);
		}

		return toResponse(page, hasNext);
	}

	private StoryPageResponse getStoriesByMonth(String month, String encodedCursor, Integer requestedLimit,
	    AuthenticatedUser authenticatedUser) {
		if (encodedCursor != null || requestedLimit != null) {
			throw new ApiException(ErrorCode.VALIDATION_ERROR);
		}

		YearMonth yearMonth;
		try {
			if (!month.matches("\\d{4}-(0[1-9]|1[0-2])")) {
				throw new DateTimeParseException("Invalid month", month, 0);
			}
			yearMonth = YearMonth.parse(month, MONTH_FORMATTER);
		} catch (DateTimeParseException exception) {
			throw new ApiException(ErrorCode.VALIDATION_ERROR);
		}

		requirePairHistory(authenticatedUser.userId());
		List<Assignment> assignments = assignmentRepository.findRevealedByMonth(authenticatedUser.userId(),
		    yearMonth.atDay(1), yearMonth.atEndOfMonth());
		return toResponse(assignments, false);
	}

	private StoryPageResponse toResponse(List<Assignment> page, boolean hasNext) {
		if (page.isEmpty()) {
			return new StoryPageResponse(List.of(), null, false);
		}

		List<String> assignmentIds = page.stream().map(Assignment::getId).toList();
		Map<String, Recording> recordings = recordingRepository.findAllByAssignment_IdIn(assignmentIds).stream()
		    .collect(Collectors.toMap(recording -> recording.getAssignment().getId(), Function.identity()));
		Map<String, ChildAnswer> childAnswers = childAnswerRepository.findAllByAssignment_IdIn(assignmentIds).stream()
		    .collect(Collectors.toMap(answer -> answer.getAssignment().getId(), Function.identity()));

		List<StoryItemResponse> items = page.stream().map(
		    assignment -> toItem(assignment, recordings.get(assignment.getId()), childAnswers.get(assignment.getId())))
		    .toList();
		String nextCursor = hasNext
		    ? new StoryCursor(page.get(page.size() - 1).getAssignedDate(), page.get(page.size() - 1).getId()).encode()
		    : null;
		return new StoryPageResponse(items, nextCursor, hasNext);
	}

	private StoryItemResponse toItem(Assignment assignment, Recording recording, ChildAnswer childAnswer) {
		Question question = assignment.getQuestion();
		OffsetDateTime revealedAt = recording.getSubmittedAt().isAfter(childAnswer.getSubmittedAt())
		    ? recording.getSubmittedAt()
		    : childAnswer.getSubmittedAt();
		return new StoryItemResponse(storyId(assignment.getId()), assignment.getId(), assignment.getAssignedDate(),
		    new StoryQuestionResponse(question.getId(), question.getText(), question.getCategory()),
		    toParentAnswer(recording), toChildAnswer(childAnswer), revealedAt);
	}

	private StoryParentAnswerResponse toParentAnswer(Recording recording) {
		if (recording.isDeleted()) {
			return StoryParentAnswerResponse.deleted();
		}
		SignedAudioUrl signedAudio = recordingStorage.createSignedReadUrl(recording.getObjectKey()).orElse(null);
		return new StoryParentAnswerResponse("AVAILABLE", recording.getId(), recording.getProcessingStatus(),
		    signedAudio == null ? null : signedAudio.url(), signedAudio == null ? null : signedAudio.expiresAt(),
		    recording.getSttText(), recording.getSummaryText(), recording.getProcessingNotice());
	}

	private StoryChildAnswerResponse toChildAnswer(ChildAnswer childAnswer) {
		return childAnswer.isDeleted()
		    ? StoryChildAnswerResponse.deleted()
		    : new StoryChildAnswerResponse("AVAILABLE", childAnswer.getId(), childAnswer.getText(),
		        childAnswer.getTtsStatus());
	}

	private void requirePairHistory(String userId) {
		if (!familyPairRepository.existsAnyByMemberId(userId)) {
			throw new ApiException(ErrorCode.PAIR_NOT_FOUND);
		}
	}

	private String storyId(String assignmentId) {
		return assignmentId.startsWith("asg_") ? "story_" + assignmentId.substring(4) : "story_" + assignmentId;
	}
}
