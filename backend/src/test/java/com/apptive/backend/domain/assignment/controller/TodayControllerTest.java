package com.apptive.backend.domain.assignment.controller;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.domain.answer.entity.ChildAnswer;
import com.apptive.backend.domain.answer.entity.TtsStatus;
import com.apptive.backend.domain.answer.repository.ChildAnswerRepository;
import com.apptive.backend.domain.assignment.entity.Assignment;
import com.apptive.backend.domain.assignment.repository.AssignmentRepository;
import com.apptive.backend.domain.pair.entity.FamilyPair;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.pair.repository.PairInvitationRepository;
import com.apptive.backend.domain.question.entity.Question;
import com.apptive.backend.domain.question.repository.QuestionRepository;
import com.apptive.backend.domain.recording.entity.Recording;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class TodayControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JwtTokenProvider tokenProvider;

	@Autowired
	private ChildAnswerRepository childAnswerRepository;

	@Autowired
	private RecordingRepository recordingRepository;

	@Autowired
	private AssignmentRepository assignmentRepository;

	@Autowired
	private PairInvitationRepository invitationRepository;

	@Autowired
	private FamilyPairRepository familyPairRepository;

	@Autowired
	private UserRepository userRepository;

	@Autowired
	private QuestionRepository questionRepository;

	@Autowired
	private Clock clock;

	private User parent;
	private User child;

	@BeforeEach
	void setUp() {
		recordingRepository.deleteAll();
		childAnswerRepository.deleteAll();
		assignmentRepository.deleteAll();
		invitationRepository.deleteAll();
		familyPairRepository.deleteAll();
		userRepository.deleteAll();

		OffsetDateTime now = OffsetDateTime.now(clock);
		parent = userRepository.save(new User("usr_today_parent", "부모", Role.PARENT, "today-parent", now));
		child = userRepository.save(new User("usr_today_child", "자녀", Role.CHILD, "today-child", now));
		familyPairRepository.save(new FamilyPair("pair_today", parent, child, now));

		LocalDate today = LocalDate.now(clock);
		Question question = questionRepository.findByScheduledDateAndActiveTrue(today)
		    .orElseGet(() -> new Question("qst_today_test", today, "오늘의 테스트 질문은 무엇인가요?", "TEST", null, true));
		question.updateFromSeed(today, "오늘의 테스트 질문은 무엇인가요?", "TEST", null, true);
		questionRepository.save(question);
	}

	@Test
	void bothAnswersAreRevealedToParentAndChild() throws Exception {
		mockMvc.perform(get("/api/v1/today").header("Authorization", bearer(child))).andExpect(status().isOk());
		Assignment assignment = assignmentRepository.findAll().get(0);
		OffsetDateTime now = OffsetDateTime.now(clock);
		Recording recording = new Recording("rec_today_parent", assignment, "recordings/rec_today_parent/audio.m4a",
		    "audio.m4a", "audio/mp4", 12, "today-upload", "version-today", now);
		recording.markSttProcessing(now);
		recording.markSttDone("부모님의 원문입니다.", now);
		recording.markLlmProcessing(now);
		recording.markReady("부모님의 이야기입니다.", now);
		recordingRepository.save(recording);
		childAnswerRepository.save(new ChildAnswer("ans_today_revealed", assignment, "자녀의 답변입니다.", TtsStatus.PROCESSING,
		    "tts-version-revealed", now, now));

		mockMvc.perform(get("/api/v1/today").header("Authorization", bearer(child))).andExpect(status().isOk())
		    .andExpect(jsonPath("$.parentSubmissionStatus").value("SUBMITTED"))
		    .andExpect(jsonPath("$.childSubmissionStatus").value("SUBMITTED"))
		    .andExpect(jsonPath("$.revealStatus").value("REVEALED"))
		    .andExpect(jsonPath("$.canViewPartnerAnswer").value(true))
		    .andExpect(jsonPath("$.myAnswer.type").value("TEXT"))
		    .andExpect(jsonPath("$.partnerAnswer.type").value("VOICE"))
		    .andExpect(jsonPath("$.partnerAnswer.recordingId").value("rec_today_parent"))
		    .andExpect(jsonPath("$.partnerAnswer.processingStatus").value("READY"))
		    .andExpect(jsonPath("$.partnerAnswer.sttText").value("부모님의 원문입니다."))
		    .andExpect(jsonPath("$.partnerAnswer.summaryText").value("부모님의 이야기입니다."));

		mockMvc.perform(get("/api/v1/today").header("Authorization", bearer(parent))).andExpect(status().isOk())
		    .andExpect(jsonPath("$.myAnswer.type").value("VOICE"))
		    .andExpect(jsonPath("$.partnerAnswer.type").value("TEXT"))
		    .andExpect(jsonPath("$.partnerAnswer.text").value("자녀의 답변입니다."));
	}

	@Test
	void childAnswerAppearsAsMyAnswerAndWaitsForParent() throws Exception {
		mockMvc.perform(get("/api/v1/today").header("Authorization", bearer(child))).andExpect(status().isOk());
		Assignment assignment = assignmentRepository.findAll().get(0);
		OffsetDateTime now = OffsetDateTime.now(clock);
		childAnswerRepository.save(new ChildAnswer("ans_today_child", assignment, "오늘은 함께 산책하고 싶어요.",
		    TtsStatus.PROCESSING, "tts-version-child", now, now));

		mockMvc.perform(get("/api/v1/today").header("Authorization", bearer(child))).andExpect(status().isOk())
		    .andExpect(jsonPath("$.parentSubmissionStatus").value("NOT_SUBMITTED"))
		    .andExpect(jsonPath("$.childSubmissionStatus").value("SUBMITTED"))
		    .andExpect(jsonPath("$.revealStatus").value("WAITING_FOR_PARENT"))
		    .andExpect(jsonPath("$.canViewPartnerAnswer").value(false))
		    .andExpect(jsonPath("$.myAnswer.type").value("TEXT"))
		    .andExpect(jsonPath("$.myAnswer.answerId").value("ans_today_child"))
		    .andExpect(jsonPath("$.myAnswer.text").value("오늘은 함께 산책하고 싶어요."))
		    .andExpect(jsonPath("$.myAnswer.ttsStatus").value("PROCESSING"))
		    .andExpect(jsonPath("$.partnerAnswer").doesNotExist());

		mockMvc.perform(get("/api/v1/today").header("Authorization", bearer(parent))).andExpect(status().isOk())
		    .andExpect(jsonPath("$.childSubmissionStatus").value("SUBMITTED"))
		    .andExpect(jsonPath("$.revealStatus").value("WAITING_FOR_PARENT"))
		    .andExpect(jsonPath("$.myAnswer").value((Object) null))
		    .andExpect(jsonPath("$.partnerAnswer").doesNotExist());
	}

	@Test
	void pairedMembersReceiveSameTodayAssignment() throws Exception {
		MvcResult childResult = mockMvc.perform(get("/api/v1/today").header("Authorization", bearer(child)))
		    .andExpect(status().isOk()).andExpect(jsonPath("$.assignment.id").isNotEmpty())
		    .andExpect(jsonPath("$.assignment.assignedDate").value(LocalDate.now(clock).toString()))
		    .andExpect(jsonPath("$.assignment.question.text").value("오늘의 테스트 질문은 무엇인가요?"))
		    .andExpect(jsonPath("$.assignment.question.category").value("TEST"))
		    .andExpect(jsonPath("$.assignment.question.audioUrl").value((Object) null))
		    .andExpect(jsonPath("$.viewerRole").value("CHILD"))
		    .andExpect(jsonPath("$.parentSubmissionStatus").value("NOT_SUBMITTED"))
		    .andExpect(jsonPath("$.childSubmissionStatus").value("NOT_SUBMITTED"))
		    .andExpect(jsonPath("$.revealStatus").value("WAITING_FOR_BOTH"))
		    .andExpect(jsonPath("$.canViewPartnerAnswer").value(false))
		    .andExpect(jsonPath("$.myAnswer").value((Object) null))
		    .andExpect(jsonPath("$.partnerAnswer").doesNotExist()).andReturn();

		String childAssignmentId = com.jayway.jsonpath.JsonPath.read(childResult.getResponse().getContentAsString(),
		    "$.assignment.id");
		mockMvc.perform(get("/api/v1/today").header("Authorization", bearer(parent))).andExpect(status().isOk())
		    .andExpect(jsonPath("$.assignment.id").value(childAssignmentId))
		    .andExpect(jsonPath("$.viewerRole").value("PARENT"));

		org.assertj.core.api.Assertions.assertThat(assignmentRepository.count()).isEqualTo(1);
	}

	@Test
	void unpairedUserReceivesPairNotFound() throws Exception {
		User unpaired = userRepository
		    .save(new User("usr_unpaired", "미페어링", Role.CHILD, "unpaired-device", OffsetDateTime.now(clock)));

		mockMvc.perform(get("/api/v1/today").header("Authorization", bearer(unpaired))).andExpect(status().isConflict())
		    .andExpect(jsonPath("$.errorCode").value("PAIR_NOT_FOUND"));
	}

	@Test
	void missingQuestionReceivesTodayAssignmentNotFound() throws Exception {
		assignmentRepository.deleteAll();
		questionRepository.findByScheduledDateAndActiveTrue(LocalDate.now(clock)).ifPresent(questionRepository::delete);

		mockMvc.perform(get("/api/v1/today").header("Authorization", bearer(child))).andExpect(status().isNotFound())
		    .andExpect(jsonPath("$.errorCode").value("TODAY_ASSIGNMENT_NOT_FOUND"));
	}

	private String bearer(User user) {
		return "Bearer " + tokenProvider.issue(user.getId(), user.getRole()).value();
	}
}
