package com.apptive.backend.domain.user.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.OffsetDateTime;

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
import com.apptive.backend.domain.auth.service.KakaoIdentity;
import com.apptive.backend.domain.pair.entity.FamilyPair;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.pair.repository.PairInvitationRepository;
import com.apptive.backend.domain.question.entity.Question;
import com.apptive.backend.domain.question.repository.QuestionRepository;
import com.apptive.backend.domain.recording.entity.Recording;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.user.entity.AccountDeletionStatus;
import com.apptive.backend.domain.user.entity.AccountDeletionTaskStatus;
import com.apptive.backend.domain.user.entity.AccountStatus;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.AccountDeletionRequestRepository;
import com.apptive.backend.domain.user.repository.AccountDeletionTaskRepository;
import com.apptive.backend.domain.user.repository.UserRepository;
import com.apptive.backend.domain.user.service.AccountDeletionProcessor;
import com.apptive.backend.domain.user.service.KakaoAccountUnlinker;
import com.apptive.backend.infra.storage.RecordingStorage;

@ActiveProfiles("test")
@SpringBootTest
@AutoConfigureMockMvc
class AccountDeletionControllerTest {

	private static final OffsetDateTime NOW = OffsetDateTime.parse("2026-11-14T12:00:00+09:00");

	@Autowired
	private MockMvc mockMvc;
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
	void parentDeletionRemovesOnlyParentContributionAndPreservesChildAnswer() throws Exception {
		mockMvc.perform(delete("/api/v1/users/me").header("Authorization", bearer(parent)))
		    .andExpect(status().isAccepted()).andExpect(jsonPath("$.deletionRequestId").isNotEmpty())
		    .andExpect(jsonPath("$.status").value("PROCESSING")).andExpect(jsonPath("$.requestedAt").isNotEmpty());

		User deletedParent = userRepository.findById(parent.getId()).orElseThrow();
		assertThat(deletedParent.getAccountStatus()).isEqualTo(AccountStatus.DELETION_PENDING);
		assertThat(deletedParent.getName()).isEqualTo("탈퇴한 사용자");
		assertThat(deletedParent.getAuthProvider()).isNull();
		assertThat(deletedParent.getAuthSubject()).isNull();
		assertThat(familyPairRepository.findById(pair.getId()).orElseThrow().isActive()).isFalse();

		Recording deletedRecording = recordingRepository.findById(recording.getId()).orElseThrow();
		assertThat(deletedRecording.isDeleted()).isTrue();
		assertThat(deletedRecording.getObjectKey()).isNull();
		assertThat(deletedRecording.getSttText()).isNull();
		assertThat(childAnswerRepository.findById(childAnswer.getId()).orElseThrow().getText()).isNotNull();
		assertThat(deletionTaskRepository.count()).isEqualTo(2);

		mockMvc.perform(get("/api/v1/stories").header("Authorization", bearer(child))).andExpect(status().isOk())
		    .andExpect(jsonPath("$.items[0].parentAnswer.availability").value("DELETED"))
		    .andExpect(jsonPath("$.items[0].parentAnswer.recordingId").doesNotExist())
		    .andExpect(jsonPath("$.items[0].parentAnswer.processingNotice").value("부모님이 탈퇴하여 음성 기록이 삭제되었어요."))
		    .andExpect(jsonPath("$.items[0].childAnswer.availability").value("AVAILABLE"))
		    .andExpect(jsonPath("$.items[0].childAnswer.text").value("함께 여행한 날이 기억나요."));

		mockMvc.perform(get("/api/v1/users/me").header("Authorization", bearer(parent)))
		    .andExpect(status().isUnauthorized());
	}

	@Test
	void childDeletionRemovesOnlyChildContributionAndPreservesParentRecording() throws Exception {
		mockMvc.perform(delete("/api/v1/users/me").header("Authorization", bearer(child)))
		    .andExpect(status().isAccepted());

		ChildAnswer deletedAnswer = childAnswerRepository.findById(childAnswer.getId()).orElseThrow();
		assertThat(deletedAnswer.isDeleted()).isTrue();
		assertThat(deletedAnswer.getText()).isNull();
		assertThat(deletedAnswer.getTtsObjectKey()).isNull();
		assertThat(recordingRepository.findById(recording.getId()).orElseThrow().getObjectKey()).isNotNull();
		assertThat(deletionTaskRepository.count()).isEqualTo(2);

		mockMvc.perform(get("/api/v1/stories").header("Authorization", bearer(parent))).andExpect(status().isOk())
		    .andExpect(jsonPath("$.items[0].parentAnswer.availability").value("AVAILABLE"))
		    .andExpect(jsonPath("$.items[0].parentAnswer.recordingId").value("rec_delete"))
		    .andExpect(jsonPath("$.items[0].childAnswer.availability").value("DELETED"))
		    .andExpect(jsonPath("$.items[0].childAnswer.answerId").doesNotExist())
		    .andExpect(jsonPath("$.items[0].childAnswer.text").doesNotExist());
	}

	@Test
	void externalDeletionTasksRemoveFilesAndUnlinkKakaoBeforeCompletion() throws Exception {
		mockMvc.perform(delete("/api/v1/users/me").header("Authorization", bearer(parent)))
		    .andExpect(status().isAccepted());

		deletionProcessor.processPendingTasks();

		assertThat(deletionTaskRepository.count()).isZero();
		assertThat(deletionRequestRepository.findByUser_Id(parent.getId())).get().satisfies(request -> {
			assertThat(request.getStatus()).isEqualTo(AccountDeletionStatus.COMPLETED);
			assertThat(request.getAuthProvider()).isNull();
			assertThat(request.getAuthSubjectHash()).isNull();
		});
		assertThat(userRepository.findById(parent.getId()).orElseThrow().getAccountStatus())
		    .isEqualTo(AccountStatus.DELETED);
		verify(recordingStorage).delete("recordings/parent.m4a");
		verify(kakaoAccountUnlinker).unlink("kakao-parent");
	}

	@Test
	void kakaoLoginIsBlockedUntilDeletionTasksComplete() throws Exception {
		mockMvc.perform(delete("/api/v1/users/me").header("Authorization", bearer(parent)))
		    .andExpect(status().isAccepted());
		when(kakaoIdTokenVerifier.verify("deleting-id-token")).thenReturn(new KakaoIdentity("kakao-parent"));

		mockMvc.perform(post("/api/v1/auth/kakao").contentType(MediaType.APPLICATION_JSON).content("""
		    {"idToken":"deleting-id-token"}
		    """)).andExpect(status().isConflict())
		    .andExpect(jsonPath("$.errorCode").value("ACCOUNT_DELETION_IN_PROGRESS"));
	}

	@Test
	void failedFileDeletionIsRetriedWithoutRestoringAccountAccess() throws Exception {
		doThrow(new IllegalStateException("temporary storage failure")).when(recordingStorage)
		    .delete("recordings/parent.m4a");
		mockMvc.perform(delete("/api/v1/users/me").header("Authorization", bearer(parent)))
		    .andExpect(status().isAccepted());

		deletionProcessor.processPendingTasks();

		assertThat(deletionTaskRepository.findAll()).singleElement()
		    .satisfies(task -> assertThat(task.getStatus()).isEqualTo(AccountDeletionTaskStatus.RETRY));
		assertThat(deletionRequestRepository.findByUser_Id(parent.getId())).get()
		    .satisfies(request -> assertThat(request.getStatus()).isEqualTo(AccountDeletionStatus.PROCESSING));
		assertThat(userRepository.findById(parent.getId()).orElseThrow().isActive()).isFalse();
	}

	private String bearer(User user) {
		return "Bearer " + tokenProvider.issue(user.getId(), user.getRole()).value();
	}
}
