package com.apptive.backend.common.processing;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.event.ApplicationEvents;
import org.springframework.test.context.event.RecordApplicationEvents;

import com.apptive.backend.domain.answer.entity.ChildAnswer;
import com.apptive.backend.domain.answer.entity.TtsStatus;
import com.apptive.backend.domain.answer.repository.ChildAnswerRepository;
import com.apptive.backend.domain.answer.service.AnswerTtsProcessor;
import com.apptive.backend.domain.answer.service.ChildAnswerSavedEvent;
import com.apptive.backend.domain.assignment.entity.Assignment;
import com.apptive.backend.domain.assignment.repository.AssignmentRepository;
import com.apptive.backend.domain.pair.entity.FamilyPair;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.question.entity.Question;
import com.apptive.backend.domain.question.repository.QuestionRepository;
import com.apptive.backend.domain.recording.entity.ProcessingStatus;
import com.apptive.backend.domain.recording.entity.Recording;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.recording.service.RecordingProcessor;
import com.apptive.backend.domain.recording.service.RecordingUploadedEvent;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;

@SpringBootTest(properties = {"app.processing-recovery.enabled=true", "app.processing-recovery.initial-delay=1h",
        "app.processing-recovery.fixed-delay=1h"})
@ActiveProfiles("test")
@RecordApplicationEvents
class AsyncProcessingRecoveryServiceTest {

	private static final String STALE_ASSIGNMENT_ID = "asg_recovery_stale";
	private static final String FRESH_ASSIGNMENT_ID = "asg_recovery_fresh";

	@Autowired
	private AsyncProcessingRecoveryService recoveryService;

	@Autowired
	private ApplicationEvents applicationEvents;

	@Autowired
	private RecordingRepository recordingRepository;

	@Autowired
	private ChildAnswerRepository childAnswerRepository;

	@Autowired
	private AssignmentRepository assignmentRepository;

	@Autowired
	private FamilyPairRepository familyPairRepository;

	@Autowired
	private QuestionRepository questionRepository;

	@Autowired
	private UserRepository userRepository;

	@Autowired
	private Clock clock;

	@MockitoBean
	private RecordingProcessor recordingProcessor;

	@MockitoBean
	private AnswerTtsProcessor answerTtsProcessor;

	@BeforeEach
	void setUp() {
		OffsetDateTime now = OffsetDateTime.now(clock);
		User parent = userRepository.save(new User("usr_recovery_parent", "부모", Role.PARENT, "recovery-parent", now));
		User child = userRepository.save(new User("usr_recovery_child", "자녀", Role.CHILD, "recovery-child", now));
		FamilyPair pair = familyPairRepository.save(new FamilyPair("pair_recovery", parent, child, now));
		Question question = questionRepository
		    .save(new Question("qst_recovery", LocalDate.of(2099, 12, 31), "복구 테스트 질문", "TEST", null, true));
		assignmentRepository
		    .saveAll(List.of(new Assignment(STALE_ASSIGNMENT_ID, pair, question, LocalDate.of(2099, 12, 30), now),
		        new Assignment(FRESH_ASSIGNMENT_ID, pair, question, LocalDate.of(2099, 12, 31), now)));
	}

	@AfterEach
	void tearDown() {
		childAnswerRepository.deleteAll();
		recordingRepository.deleteAll();
		assignmentRepository.deleteAllById(List.of(STALE_ASSIGNMENT_ID, FRESH_ASSIGNMENT_ID));
		familyPairRepository.deleteById("pair_recovery");
		userRepository.deleteAllById(List.of("usr_recovery_parent", "usr_recovery_child"));
		questionRepository.deleteById("qst_recovery");
	}

	@Test
	void republishesOnlyStaleRecordingAndTtsWorkWithNewVersions() {
		OffsetDateTime now = OffsetDateTime.now(clock);
		OffsetDateTime staleTime = now.minusMinutes(5);
		Assignment staleAssignment = assignmentRepository.findById(STALE_ASSIGNMENT_ID).orElseThrow();
		Assignment freshAssignment = assignmentRepository.findById(FRESH_ASSIGNMENT_ID).orElseThrow();

		Recording staleRecording = recordingRepository
		    .save(recording("rec_recovery_stale", staleAssignment, "recording-stale-version", staleTime));
		Recording freshRecording = recordingRepository
		    .save(recording("rec_recovery_fresh", freshAssignment, "recording-fresh-version", now));
		ChildAnswer staleAnswer = childAnswerRepository
		    .save(answer("ans_recovery_stale", staleAssignment, "tts-stale-version", staleTime));
		ChildAnswer freshAnswer = childAnswerRepository
		    .save(answer("ans_recovery_fresh", freshAssignment, "tts-fresh-version", now));

		ProcessingRecoveryResult result = recoveryService.recoverStale();

		assertThat(result).isEqualTo(new ProcessingRecoveryResult(1, 1));
		Recording recoveredRecording = recordingRepository.findById(staleRecording.getId()).orElseThrow();
		assertThat(recoveredRecording.getProcessingStatus()).isEqualTo(ProcessingStatus.UPLOADED);
		assertThat(recoveredRecording.getProcessingVersion()).isNotEqualTo("recording-stale-version");
		ChildAnswer recoveredAnswer = childAnswerRepository.findById(staleAnswer.getId()).orElseThrow();
		assertThat(recoveredAnswer.getTtsStatus()).isEqualTo(TtsStatus.PROCESSING);
		assertThat(recoveredAnswer.getTtsVersion()).isNotEqualTo("tts-stale-version");

		assertThat(recordingRepository.findById(freshRecording.getId()).orElseThrow().getProcessingVersion())
		    .isEqualTo("recording-fresh-version");
		assertThat(childAnswerRepository.findById(freshAnswer.getId()).orElseThrow().getTtsVersion())
		    .isEqualTo("tts-fresh-version");

		assertThat(applicationEvents.stream(RecordingUploadedEvent.class)
		    .anyMatch(event -> event.recordingId().equals(staleRecording.getId())
		        && event.processingVersion().equals(recoveredRecording.getProcessingVersion())))
		    .isTrue();
		assertThat(applicationEvents.stream(ChildAnswerSavedEvent.class)
		    .anyMatch(event -> event.answerId().equals(staleAnswer.getId())
		        && event.ttsVersion().equals(recoveredAnswer.getTtsVersion())))
		    .isTrue();
	}

	private Recording recording(String id, Assignment assignment, String version, OffsetDateTime updatedAt) {
		Recording recording = new Recording(id, assignment, "recordings/" + id + "/audio.m4a", "audio.m4a", "audio/mp4",
		    128, id, version, updatedAt);
		recording.markSttProcessing(updatedAt);
		return recording;
	}

	private ChildAnswer answer(String id, Assignment assignment, String version, OffsetDateTime updatedAt) {
		return new ChildAnswer(id, assignment, "복구할 답변", TtsStatus.PROCESSING, version, updatedAt, updatedAt);
	}
}
