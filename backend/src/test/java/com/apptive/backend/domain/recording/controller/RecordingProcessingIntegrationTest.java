package com.apptive.backend.domain.recording.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.domain.assignment.entity.Assignment;
import com.apptive.backend.domain.assignment.repository.AssignmentRepository;
import com.apptive.backend.domain.pair.entity.FamilyPair;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.question.entity.Question;
import com.apptive.backend.domain.question.repository.QuestionRepository;
import com.apptive.backend.domain.recording.entity.ProcessingStatus;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class RecordingProcessingIntegrationTest {

	private static final String PARENT_ID = "usr_async_parent";
	private static final String CHILD_ID = "usr_async_child";
	private static final String PAIR_ID = "pair_async";
	private static final String QUESTION_ID = "qst_async";
	private static final String ASSIGNMENT_ID = "asg_async";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private ObjectMapper objectMapper;

	@Autowired
	private JwtTokenProvider tokenProvider;

	@Autowired
	private RecordingRepository recordingRepository;

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

	@BeforeEach
	void setUp() {
		OffsetDateTime now = OffsetDateTime.now(clock);
		parent = userRepository.save(new User(PARENT_ID, "부모", Role.PARENT, "async-parent", now));
		User child = userRepository.save(new User(CHILD_ID, "자녀", Role.CHILD, "async-child", now));
		FamilyPair pair = familyPairRepository.save(new FamilyPair(PAIR_ID, parent, child, now));
		Question question = questionRepository
		    .save(new Question(QUESTION_ID, LocalDate.of(2099, 1, 1), "기억나는 일을 들려주세요.", "DAILY", null, true));
		assignmentRepository.save(new Assignment(ASSIGNMENT_ID, pair, question, LocalDate.of(2099, 1, 1), now));
	}

	@AfterEach
	void tearDown() {
		recordingRepository.deleteAll();
		assignmentRepository.deleteById(ASSIGNMENT_ID);
		familyPairRepository.deleteById(PAIR_ID);
		userRepository.deleteAllById(java.util.List.of(PARENT_ID, CHILD_ID));
		questionRepository.deleteById(QUESTION_ID);
	}

	@Test
	void uploadedRecordingIsProcessedToReadyAsynchronously() throws Exception {
		MockMultipartFile audio = new MockMultipartFile("audioFile", "answer.m4a", "audio/mp4",
		    new byte[]{0, 0, 0, 16, 'f', 't', 'y', 'p', 'M', '4', 'A', ' '});
		MvcResult upload = mockMvc
		    .perform(multipart("/api/v1/assignments/{assignmentId}/parent-recording", ASSIGNMENT_ID).file(audio)
		        .with(request -> {
			        request.setMethod("PUT");
			        return request;
		        }).header("Authorization", bearer(parent)).header("Idempotency-Key", "async-upload"))
		    .andExpect(status().isAccepted()).andReturn();
		String recordingId = objectMapper.readTree(upload.getResponse().getContentAsByteArray()).get("recordingId")
		    .asText();

		JsonNode statusBody = awaitTerminalStatus(recordingId);

		assertThat(statusBody.get("processingStatus").asText()).isEqualTo(ProcessingStatus.READY.name());
		assertThat(statusBody.get("sttText").asText()).isEqualTo("Mock STT 처리 결과입니다.");
		assertThat(statusBody.get("summaryText").asText()).isEqualTo("Mock으로 정리된 이야기입니다.");
	}

	private JsonNode awaitTerminalStatus(String recordingId) throws Exception {
		for (int attempt = 0; attempt < 50; attempt++) {
			MvcResult result = mockMvc
			    .perform(get("/api/v1/recordings/{recordingId}", recordingId).header("Authorization", bearer(parent)))
			    .andExpect(status().isOk()).andReturn();
			JsonNode body = objectMapper.readTree(result.getResponse().getContentAsByteArray());
			String processingStatus = body.get("processingStatus").asText();
			if (processingStatus.equals(ProcessingStatus.READY.name())
			    || processingStatus.equals(ProcessingStatus.FAILED.name())) {
				return body;
			}
			Thread.sleep(20);
		}
		throw new AssertionError("녹음 처리가 제한 시간 안에 종료되지 않았습니다.");
	}

	private String bearer(User user) {
		return "Bearer " + tokenProvider.issue(user.getId(), user.getRole()).value();
	}
}
