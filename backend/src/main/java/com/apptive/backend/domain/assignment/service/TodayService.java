package com.apptive.backend.domain.assignment.service;

import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.common.id.IdGenerator;
import com.apptive.backend.domain.answer.entity.ChildAnswer;
import com.apptive.backend.domain.answer.repository.ChildAnswerRepository;
import com.apptive.backend.domain.assignment.dto.TextTodayAnswerResponse;
import com.apptive.backend.domain.assignment.dto.TodayAnswerResponse;
import com.apptive.backend.domain.assignment.dto.TodayAssignmentResponse;
import com.apptive.backend.domain.assignment.dto.TodayQuestionResponse;
import com.apptive.backend.domain.assignment.dto.TodayResponse;
import com.apptive.backend.domain.assignment.dto.VoiceTodayAnswerResponse;
import com.apptive.backend.domain.assignment.entity.Assignment;
import com.apptive.backend.domain.assignment.entity.RevealStatus;
import com.apptive.backend.domain.assignment.entity.SubmissionStatus;
import com.apptive.backend.domain.assignment.repository.AssignmentRepository;
import com.apptive.backend.domain.pair.entity.FamilyPair;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.question.entity.Question;
import com.apptive.backend.domain.question.repository.QuestionRepository;
import com.apptive.backend.domain.recording.entity.Recording;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.infra.storage.RecordingStorage;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Service
public class TodayService {

	private final FamilyPairRepository familyPairRepository;
	private final AssignmentRepository assignmentRepository;
	private final QuestionRepository questionRepository;
	private final ChildAnswerRepository childAnswerRepository;
	private final RecordingRepository recordingRepository;
	private final RecordingStorage recordingStorage;
	private final RevealPolicy revealPolicy;
	private final IdGenerator idGenerator;
	private final Clock clock;

	@Transactional
	public TodayResponse getToday(AuthenticatedUser authenticatedUser) {
		FamilyPair familyPair = familyPairRepository.findActiveByMemberIdForUpdate(authenticatedUser.userId())
		    .orElseThrow(() -> new ApiException(ErrorCode.PAIR_NOT_FOUND));
		LocalDate today = LocalDate.now(clock);
		Assignment assignment = assignmentRepository.findByFamilyPair_IdAndAssignedDate(familyPair.getId(), today)
		    .orElseGet(() -> createAssignment(familyPair, today));

		return toResponse(assignment, authenticatedUser);
	}

	private Assignment createAssignment(FamilyPair familyPair, LocalDate today) {
		Question question = questionRepository.findByScheduledDateAndActiveTrue(today)
		    .orElseThrow(() -> new ApiException(ErrorCode.TODAY_ASSIGNMENT_NOT_FOUND));
		return assignmentRepository
		    .save(new Assignment(idGenerator.generate("asg"), familyPair, question, today, OffsetDateTime.now(clock)));
	}

	private TodayResponse toResponse(Assignment assignment, AuthenticatedUser authenticatedUser) {
		Question question = assignment.getQuestion();
		ChildAnswer childAnswer = childAnswerRepository.findByAssignment_Id(assignment.getId()).orElse(null);
		Recording recording = recordingRepository.findByAssignment_Id(assignment.getId()).orElse(null);
		SubmissionStatus parentStatus = recording == null ? SubmissionStatus.NOT_SUBMITTED : SubmissionStatus.SUBMITTED;
		SubmissionStatus childStatus = childAnswer == null
		    ? SubmissionStatus.NOT_SUBMITTED
		    : SubmissionStatus.SUBMITTED;
		RevealStatus revealStatus = revealPolicy.resolve(parentStatus, childStatus);
		boolean revealed = revealStatus == RevealStatus.REVEALED;
		TodayAnswerResponse myAnswer = authenticatedUser.role() == Role.PARENT
		    ? voiceAnswer(recording)
		    : textAnswer(childAnswer);
		TodayAnswerResponse partnerAnswer = null;
		if (revealed) {
			partnerAnswer = authenticatedUser.role() == Role.PARENT ? textAnswer(childAnswer) : voiceAnswer(recording);
		}

		return new TodayResponse(
		    new TodayAssignmentResponse(assignment.getId(), assignment.getAssignedDate(),
		        new TodayQuestionResponse(question.getId(), question.getText(), question.getCategory(),
		            question.getAudioUrl())),
		    authenticatedUser.role(), parentStatus, childStatus, revealStatus, revealed, myAnswer, partnerAnswer);
	}

	private TodayAnswerResponse voiceAnswer(Recording recording) {
		if (recording == null) {
			return null;
		}
		return VoiceTodayAnswerResponse.from(recording,
		    recordingStorage.createSignedReadUrl(recording.getObjectKey()).orElse(null));
	}

	private TodayAnswerResponse textAnswer(ChildAnswer childAnswer) {
		return childAnswer == null ? null : TextTodayAnswerResponse.from(childAnswer);
	}
}
