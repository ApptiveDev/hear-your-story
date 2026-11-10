package com.apptive.backend.domain.recording.controller;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
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
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.domain.answer.repository.ChildAnswerRepository;
import com.apptive.backend.domain.assignment.entity.Assignment;
import com.apptive.backend.domain.assignment.repository.AssignmentRepository;
import com.apptive.backend.domain.pair.entity.FamilyPair;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.question.entity.Question;
import com.apptive.backend.domain.question.repository.QuestionRepository;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class RecordingControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private ObjectMapper objectMapper;

	@Autowired
	private JwtTokenProvider tokenProvider;

	@Autowired
	private RecordingRepository recordingRepository;

	@Autowired
	private ChildAnswerRepository childAnswerRepository;

	@Autowired
	private AssignmentRepository assignmentRepository;

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
	private Assignment assignment;

	@BeforeEach
	void setUp() {
		recordingRepository.deleteAll();
		childAnswerRepository.deleteAll();
		assignmentRepository.deleteAll();
		familyPairRepository.deleteAll();
		userRepository.deleteAll();

		OffsetDateTime now = OffsetDateTime.now(clock);
		parent = userRepository.save(new User("usr_recording_parent", "부모", Role.PARENT, "recording-parent", now));
		child = userRepository.save(new User("usr_recording_child", "자녀", Role.CHILD, "recording-child", now));
		FamilyPair pair = familyPairRepository.save(new FamilyPair("pair_recording", parent, child, now));
		LocalDate today = LocalDate.now(clock);
		Question question = questionRepository.findByScheduledDateAndActiveTrue(today)
		    .orElseGet(() -> new Question("qst_recording", today, "오늘 기억하고 싶은 일은 무엇인가요?", "DAILY", null, true));
		question.updateFromSeed(today, "오늘 기억하고 싶은 일은 무엇인가요?", "DAILY", null, true);
		questionRepository.save(question);
		assignment = assignmentRepository.save(new Assignment("asg_recording", pair, question, today, now));
	}

	@Test
	void parentUploadsRecordingAndSameIdempotencyKeyReturnsSameResult() throws Exception {
		MvcResult first = upload(parent, assignment.getId(), validAudio("first.m4a"), "upload-1")
		    .andExpect(status().isAccepted()).andExpect(jsonPath("$.recordingId").isNotEmpty())
		    .andExpect(jsonPath("$.assignmentId").value(assignment.getId()))
		    .andExpect(jsonPath("$.submissionStatus").value("SUBMITTED"))
		    .andExpect(jsonPath("$.processingStatus").value("UPLOADED"))
		    .andExpect(jsonPath("$.submittedAt").isNotEmpty()).andExpect(jsonPath("$.pollingUrl").isNotEmpty())
		    .andReturn();
		JsonNode firstBody = objectMapper.readTree(first.getResponse().getContentAsByteArray());

		upload(parent, assignment.getId(), validAudio("retry.m4a"), "upload-1").andExpect(status().isAccepted())
		    .andExpect(jsonPath("$.recordingId").value(firstBody.get("recordingId").asText()))
		    .andExpect(jsonPath("$.submittedAt").value(firstBody.get("submittedAt").asText()));

		org.assertj.core.api.Assertions.assertThat(recordingRepository.count()).isEqualTo(1);
	}

	@Test
	void parentCanPollUploadedRecording() throws Exception {
		MvcResult uploaded = upload(parent, assignment.getId(), validAudio("answer.m4a"), "poll-upload")
		    .andExpect(status().isAccepted()).andReturn();
		String recordingId = objectMapper.readTree(uploaded.getResponse().getContentAsByteArray()).get("recordingId")
		    .asText();

		mockMvc.perform(get("/api/v1/recordings/{recordingId}", recordingId).header("Authorization", bearer(parent)))
		    .andExpect(status().isOk()).andExpect(jsonPath("$.recordingId").value(recordingId))
		    .andExpect(jsonPath("$.assignmentId").value(assignment.getId()))
		    .andExpect(jsonPath("$.processingStatus").value("UPLOADED")).andExpect(jsonPath("$.sttText").isEmpty())
		    .andExpect(jsonPath("$.summaryText").isEmpty());
	}

	@Test
	void childAndAnotherParentCannotPollRecording() throws Exception {
		MvcResult uploaded = upload(parent, assignment.getId(), validAudio("answer.m4a"), "poll-auth")
		    .andExpect(status().isAccepted()).andReturn();
		String recordingId = objectMapper.readTree(uploaded.getResponse().getContentAsByteArray()).get("recordingId")
		    .asText();

		mockMvc.perform(get("/api/v1/recordings/{recordingId}", recordingId).header("Authorization", bearer(child)))
		    .andExpect(status().isForbidden()).andExpect(jsonPath("$.errorCode").value("ROLE_NOT_ALLOWED"));

		User anotherParent = userRepository.save(new User("usr_recording_poll_other", "다른 부모", Role.PARENT,
		    "recording-poll-other", OffsetDateTime.now(clock)));
		mockMvc
		    .perform(
		        get("/api/v1/recordings/{recordingId}", recordingId).header("Authorization", bearer(anotherParent)))
		    .andExpect(status().isForbidden()).andExpect(jsonPath("$.errorCode").value("PAIR_ACCESS_DENIED"));
	}

	@Test
	void missingRecordingReturnsNotFound() throws Exception {
		mockMvc.perform(get("/api/v1/recordings/rec_missing").header("Authorization", bearer(parent)))
		    .andExpect(status().isNotFound()).andExpect(jsonPath("$.errorCode").value("RECORDING_NOT_FOUND"));
	}

	@Test
	void rerecordingReplacesFileButKeepsOneActiveRecording() throws Exception {
		MvcResult first = upload(parent, assignment.getId(), validAudio("first.m4a"), "upload-1")
		    .andExpect(status().isAccepted()).andReturn();
		String recordingId = objectMapper.readTree(first.getResponse().getContentAsByteArray()).get("recordingId")
		    .asText();

		upload(parent, assignment.getId(), validAudio("second.m4a"), "upload-2").andExpect(status().isAccepted())
		    .andExpect(jsonPath("$.recordingId").value(recordingId));

		org.assertj.core.api.Assertions.assertThat(recordingRepository.count()).isEqualTo(1);
		org.assertj.core.api.Assertions
		    .assertThat(recordingRepository.findById(recordingId).orElseThrow().getOriginalFilename())
		    .isEqualTo("second.m4a");
	}

	@Test
	void childAndAnotherParentCannotUploadRecording() throws Exception {
		upload(child, assignment.getId(), validAudio("child.m4a"), "child-upload").andExpect(status().isForbidden())
		    .andExpect(jsonPath("$.errorCode").value("ROLE_NOT_ALLOWED"));

		User anotherParent = userRepository.save(new User("usr_recording_other_parent", "다른 부모", Role.PARENT,
		    "recording-other-parent", OffsetDateTime.now(clock)));
		upload(anotherParent, assignment.getId(), validAudio("other.m4a"), "other-upload")
		    .andExpect(status().isForbidden()).andExpect(jsonPath("$.errorCode").value("PAIR_ACCESS_DENIED"));
	}

	@Test
	void invalidAudioIsRejected() throws Exception {
		MockMultipartFile invalid = new MockMultipartFile("audioFile", "answer.wav", "audio/wav",
		    "not-an-m4a".getBytes());

		upload(parent, assignment.getId(), invalid, "invalid-upload").andExpect(status().isBadRequest())
		    .andExpect(jsonPath("$.errorCode").value("INVALID_AUDIO_FORMAT"));
	}

	@Test
	void missingAssignmentReturnsNotFound() throws Exception {
		upload(parent, "asg_missing", validAudio("answer.m4a"), "missing-assignment").andExpect(status().isNotFound())
		    .andExpect(jsonPath("$.errorCode").value("ASSIGNMENT_NOT_FOUND"));
	}

	private org.springframework.test.web.servlet.ResultActions upload(User user, String assignmentId,
	    MockMultipartFile audioFile, String idempotencyKey) throws Exception {
		return mockMvc.perform(multipart("/api/v1/assignments/{assignmentId}/parent-recording", assignmentId)
		    .file(audioFile).with(request -> {
			    request.setMethod("PUT");
			    return request;
		    }).header("Authorization", bearer(user)).header("Idempotency-Key", idempotencyKey));
	}

	private MockMultipartFile validAudio(String filename) {
		return new MockMultipartFile("audioFile", filename, "audio/mp4",
		    new byte[]{0, 0, 0, 16, 'f', 't', 'y', 'p', 'M', '4', 'A', ' '});
	}

	private String bearer(User user) {
		return "Bearer " + tokenProvider.issue(user.getId(), user.getRole()).value();
	}
}
