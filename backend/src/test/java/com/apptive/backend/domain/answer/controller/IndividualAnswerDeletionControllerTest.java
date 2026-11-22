package com.apptive.backend.domain.answer.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.OffsetDateTime;
import java.util.List;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.domain.answer.entity.ChildAnswer;
import com.apptive.backend.domain.answer.entity.TtsStatus;
import com.apptive.backend.domain.answer.repository.ChildAnswerRepository;
import com.apptive.backend.domain.assignment.entity.Assignment;
import com.apptive.backend.domain.assignment.repository.AssignmentRepository;
import com.apptive.backend.domain.auth.repository.RefreshTokenRepository;
import com.apptive.backend.domain.auth.service.KakaoIdTokenVerifier;
import com.apptive.backend.domain.pair.entity.FamilyPair;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.pair.repository.PairInvitationRepository;
import com.apptive.backend.domain.question.entity.Question;
import com.apptive.backend.domain.question.repository.QuestionRepository;
import com.apptive.backend.domain.recording.entity.Recording;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.AccountDeletionRequestRepository;
import com.apptive.backend.domain.user.repository.AccountDeletionTaskRepository;
import com.apptive.backend.domain.user.repository.UserRepository;
import com.apptive.backend.domain.user.service.AccountDeletionProcessor;
import com.apptive.backend.domain.user.service.AccountDeletionTaskService;
import com.apptive.backend.domain.user.service.KakaoAccountUnlinker;
import com.apptive.backend.infra.storage.RecordingStorage;

@ActiveProfiles("test")
@SpringBootTest
@AutoConfigureMockMvc
class IndividualAnswerDeletionControllerTest {

	private static final OffsetDateTime NOW = OffsetDateTime
	    .now(java.time.Clock.system(java.time.ZoneId.of("Asia/Seoul")));

	@Autowired
	private MockMvc mockMvc;
	@Autowired
	private com.apptive.backend.infra.storage.StorageDeletionTaskRepository storageTasks;
	@Autowired
	private com.apptive.backend.infra.storage.StorageDeletionProcessor storageProcessor;
	@Autowired
	private com.apptive.backend.domain.answer.service.AnswerTtsStatusService ttsStatusService;
	@Autowired
	private com.apptive.backend.domain.recording.service.RecordingStatusService recordingStatusService;
	@Autowired
	private org.springframework.transaction.PlatformTransactionManager transactionManager;
	@Autowired
	private com.apptive.backend.domain.answer.service.IndividualAnswerDeletionService individualDeletionService;
	@Autowired
	private JwtTokenProvider tokenProvider;
	@Autowired
	private UserRepository userRepository;
	@Autowired
	private FamilyPairRepository familyPairRepository;
	@Autowired
	private PairInvitationRepository pairInvitationRepository;
	@Autowired
	private QuestionRepository questionRepository;
	@Autowired
	private AssignmentRepository assignmentRepository;
	@Autowired
	private RecordingRepository recordingRepository;
	@Autowired
	private ChildAnswerRepository childAnswerRepository;
	@Autowired
	private RefreshTokenRepository refreshTokenRepository;
	@Autowired
	private AccountDeletionRequestRepository deletionRequestRepository;
	@Autowired
	private AccountDeletionTaskRepository deletionTaskRepository;
	@Autowired
	private AccountDeletionProcessor deletionProcessor;
	@Autowired
	private AccountDeletionTaskService deletionTaskService;

	@MockitoBean
	private RecordingStorage recordingStorage;
	@MockitoBean
	private KakaoAccountUnlinker kakaoAccountUnlinker;
	@MockitoBean
	private KakaoIdTokenVerifier kakaoIdTokenVerifier;

	private User parent;
	private User child;
	private FamilyPair pair;
	private Recording recording;
	private ChildAnswer childAnswer;

	@BeforeEach
	void setUp() {
		parent = userRepository
		    .save(new User("usr_delete_parent", "부모", Role.PARENT, AuthProvider.KAKAO, "kakao-parent", NOW));
		child = userRepository
		    .save(new User("usr_delete_child", "자녀", Role.CHILD, AuthProvider.KAKAO, "kakao-child", NOW));
		pair = familyPairRepository.save(new FamilyPair("pair_delete", parent, child, NOW));
		Question question = questionRepository
		    .save(new Question("qst_delete", NOW.toLocalDate(), "가족과 함께한 기억은?", "FAMILY", null, true));
		Assignment assignment = assignmentRepository
		    .save(new Assignment("asg_delete", pair, question, NOW.toLocalDate(), NOW));
		recording = recordingRepository.save(new Recording("rec_delete", assignment, "recordings/parent.m4a",
		    "answer.m4a", "audio/mp4", 128, "idempotency-delete", "recording-version", NOW));
		childAnswer = new ChildAnswer("ans_delete", assignment, "함께 여행한 날이 기억나요.", TtsStatus.PROCESSING, "tts-version",
		    NOW, NOW);
		childAnswer.markTtsReady("tts/child.mp3", NOW);
		childAnswer = childAnswerRepository.save(childAnswer);
	}

	@AfterEach
	void tearDown() {
		storageTasks.deleteAll();
		deletionTaskRepository.deleteAll();
		deletionRequestRepository.deleteAll();
		refreshTokenRepository.deleteAll();
		childAnswerRepository.deleteAll();
		recordingRepository.deleteAll();
		assignmentRepository.deleteAll();
		pairInvitationRepository.deleteAll();
		familyPairRepository.deleteAll();
		userRepository.deleteAll();
		questionRepository.deleteById("qst_delete");
	}

	@Test
	void parentDeletesOnlyOwnRecordingAndKeepsStoryInBothLists() throws Exception {
		mockMvc.perform(delete("/api/v1/recordings/rec_delete").header("Authorization", bearer(parent)))
		    .andExpect(status().isNoContent());
		assertThat(recordingRepository.findById("rec_delete").orElseThrow().getObjectKey()).isNull();
		assertThat(childAnswerRepository.findById("ans_delete").orElseThrow().getText()).isNotNull();
		assertThat(userRepository.findById(parent.getId()).orElseThrow().isActive()).isTrue();
		assertThat(storageTasks.count()).isEqualTo(1);
		for (String path : List.of("/api/v1/stories", "/api/v1/stories?month=" + java.time.YearMonth.from(NOW))) {
			mockMvc.perform(get(path).header("Authorization", bearer(child))).andExpect(status().isOk())
			    .andExpect(jsonPath("$.items[0].parentAnswer.availability").value("DELETED"))
			    .andExpect(jsonPath("$.items[0].parentAnswer.recordingId").doesNotExist())
			    .andExpect(jsonPath("$.items[0].parentAnswer.processingNotice").value("부모님이 이 음성 기록을 삭제했어요."))
			    .andExpect(jsonPath("$.items[0].childAnswer.availability").value("AVAILABLE"));
		}
		mockMvc.perform(get("/api/v1/today").header("Authorization", bearer(parent))).andExpect(status().isOk())
		    .andExpect(jsonPath("$.myAnswer.type").value("DELETED"))
		    .andExpect(jsonPath("$.parentSubmissionStatus").value("SUBMITTED"));
		mockMvc.perform(delete("/api/v1/recordings/rec_delete").header("Authorization", bearer(parent)))
		    .andExpect(status().isNotFound()).andExpect(jsonPath("$.errorCode").value("RECORDING_NOT_FOUND"));
		storageProcessor.processPendingTasks();
		verify(recordingStorage).delete("recordings/parent.m4a");
		assertThat(storageTasks.count()).isZero();
	}

	@Test
	void childDeletesTextAndTtsAndCannotResubmit() throws Exception {
		mockMvc.perform(delete("/api/v1/answers/ans_delete").header("Authorization", bearer(child)))
		    .andExpect(status().isNoContent());
		ChildAnswer deleted = childAnswerRepository.findById("ans_delete").orElseThrow();
		assertThat(deleted.getText()).isNull();
		assertThat(deleted.getTtsObjectKey()).isNull();
		assertThat(deleted.getTtsVersion()).isNull();
		assertThat(recordingRepository.findById("rec_delete").orElseThrow().getObjectKey()).isNotNull();
		mockMvc.perform(get("/api/v1/stories").header("Authorization", bearer(parent))).andExpect(status().isOk())
		    .andExpect(jsonPath("$.items[0].childAnswer.availability").value("DELETED"));
		mockMvc.perform(get("/api/v1/today").header("Authorization", bearer(parent))).andExpect(status().isOk())
		    .andExpect(jsonPath("$.partnerAnswer.type").value("DELETED"));
		mockMvc
		    .perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
		        .put("/api/v1/assignments/asg_delete/child-answer").header("Authorization", bearer(child))
		        .contentType(MediaType.APPLICATION_JSON).content("{\"text\":\"다시 작성\"}"))
		    .andExpect(status().isConflict()).andExpect(jsonPath("$.errorCode").value("ANSWER_LOCKED"));
		mockMvc.perform(get("/api/v1/answers/ans_delete/audio").header("Authorization", bearer(parent)))
		    .andExpect(status().isNotFound()).andExpect(jsonPath("$.errorCode").value("ANSWER_NOT_FOUND"));
		mockMvc.perform(delete("/api/v1/answers/ans_delete").header("Authorization", bearer(child)))
		    .andExpect(status().isNotFound()).andExpect(jsonPath("$.errorCode").value("ANSWER_NOT_FOUND"));
		storageProcessor.processPendingTasks();
		verify(recordingStorage).delete("tts/child.mp3");
	}

	@Test
	void deniesPartnerAndUnrelatedUsersAndRequiresAuthentication() throws Exception {
		User stranger = userRepository.save(new User("usr_stranger", "다른 부모", Role.PARENT, "stranger-device", NOW));
		mockMvc.perform(delete("/api/v1/recordings/rec_delete")).andExpect(status().isUnauthorized());
		mockMvc.perform(delete("/api/v1/recordings/rec_delete").header("Authorization", bearer(child)))
		    .andExpect(status().isForbidden()).andExpect(jsonPath("$.errorCode").value("RESOURCE_ACCESS_DENIED"));
		mockMvc.perform(delete("/api/v1/recordings/rec_delete").header("Authorization", bearer(stranger)))
		    .andExpect(status().isForbidden());
		mockMvc.perform(delete("/api/v1/answers/ans_delete").header("Authorization", bearer(parent)))
		    .andExpect(status().isForbidden()).andExpect(jsonPath("$.errorCode").value("RESOURCE_ACCESS_DENIED"));
		mockMvc.perform(delete("/api/v1/answers/missing").header("Authorization", bearer(child)))
		    .andExpect(status().isNotFound()).andExpect(jsonPath("$.errorCode").value("ANSWER_NOT_FOUND"));
		assertThat(storageTasks.count()).isZero();
	}

	@Test
	void fileFailureKeepsDurableTaskAndDeletedAnswerHidden() throws Exception {
		doThrow(new IllegalStateException("temporary")).when(recordingStorage).delete("recordings/parent.m4a");
		mockMvc.perform(delete("/api/v1/recordings/rec_delete").header("Authorization", bearer(parent)))
		    .andExpect(status().isNoContent());
		storageProcessor.processPendingTasks();
		assertThat(storageTasks.findAll()).singleElement()
		    .satisfies(task -> assertThat(task.getAttempts()).isEqualTo(1));
		assertThat(recordingRepository.findById("rec_delete").orElseThrow().isDeleted()).isTrue();
		org.mockito.Mockito.reset(recordingStorage);
		var task = storageTasks.findAll().get(0);
		task.claim(OffsetDateTime.now().minusMinutes(6));
		storageTasks.saveAndFlush(task);
		storageProcessor.processPendingTasks();
		assertThat(storageTasks.count()).isZero();
		verify(recordingStorage).delete("recordings/parent.m4a");
	}

	@Test
	void staleProcessingCannotRestoreDeletedPersonalData() throws Exception {
		mockMvc.perform(delete("/api/v1/recordings/rec_delete").header("Authorization", bearer(parent)))
		    .andExpect(status().isNoContent());
		mockMvc.perform(delete("/api/v1/answers/ans_delete").header("Authorization", bearer(child)))
		    .andExpect(status().isNoContent());
		assertThat(recordingStatusService.markReady("rec_delete", "recording-version", "뒤늦은 요약")).isFalse();
		assertThat(ttsStatusService.markReady("ans_delete", "tts-version", "late.mp3").accepted()).isFalse();
		assertThat(recordingRepository.findById("rec_delete").orElseThrow().getSummaryText()).isNull();
		assertThat(childAnswerRepository.findById("ans_delete").orElseThrow().getTtsObjectKey()).isNull();
		mockMvc.perform(get("/api/v1/recordings/rec_delete").header("Authorization", bearer(parent)))
		    .andExpect(status().isNotFound());
		mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
		    .multipart("/api/v1/assignments/asg_delete/parent-recording")
		    .file(new org.springframework.mock.web.MockMultipartFile("audioFile", "answer.m4a", "audio/mp4",
		        new byte[]{1}))
		    .with(request -> {
			    request.setMethod("PUT");
			    return request;
		    }).header("Authorization", bearer(parent))).andExpect(status().isConflict())
		    .andExpect(jsonPath("$.errorCode").value("ANSWER_LOCKED"));
	}

	@Test
	void rollbackRestoresAnswerAndDoesNotEnqueueFileDeletion() {
		new org.springframework.transaction.support.TransactionTemplate(transactionManager)
		    .executeWithoutResult(status -> {
			    individualDeletionService.deleteRecording("rec_delete",
			        new com.apptive.backend.common.auth.AuthenticatedUser(parent.getId(), Role.PARENT));
			    status.setRollbackOnly();
		    });
		assertThat(recordingRepository.findById("rec_delete").orElseThrow().isDeleted()).isFalse();
		assertThat(storageTasks.count()).isZero();
		org.mockito.Mockito.verifyNoInteractions(recordingStorage);
	}

	@Test
	void deletionOfHistoricalPairAnswerIsAllowedAfterPairDeactivation() throws Exception {
		pair.deactivate(NOW);
		familyPairRepository.saveAndFlush(pair);
		mockMvc.perform(delete("/api/v1/recordings/rec_delete").header("Authorization", bearer(parent)))
		    .andExpect(status().isNoContent());
		mockMvc.perform(delete("/api/v1/answers/ans_delete").header("Authorization", bearer(child)))
		    .andExpect(status().isNoContent());
	}

	private String bearer(User user) {
		return "Bearer " + tokenProvider.issue(user.getId(), user.getRole()).value();
	}
}
