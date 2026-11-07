package com.apptive.backend.domain.answer.controller;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
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
import org.springframework.http.MediaType;
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
import com.apptive.backend.domain.recording.entity.Recording;
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
class ChildAnswerControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private ObjectMapper objectMapper;

	@Autowired
	private JwtTokenProvider tokenProvider;

	@Autowired
	private ChildAnswerRepository childAnswerRepository;

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
		parent = userRepository.save(new User("usr_answer_parent", "부모", Role.PARENT, "answer-parent", now));
		child = userRepository.save(new User("usr_answer_child", "자녀", Role.CHILD, "answer-child", now));
		FamilyPair pair = familyPairRepository.save(new FamilyPair("pair_answer", parent, child, now));
		LocalDate today = LocalDate.now(clock);
		Question question = questionRepository.findByScheduledDateAndActiveTrue(today)
		    .orElseGet(() -> new Question("qst_answer", today, "오늘 어떤 일이 있었나요?", "DAILY", null, true));
		question.updateFromSeed(today, "오늘 어떤 일이 있었나요?", "DAILY", null, true);
		questionRepository.save(question);
		assignment = assignmentRepository.save(new Assignment("asg_answer", pair, question, today, now));
	}

	@Test
	void revealedChildAnswerCannotBeUpdated() throws Exception {
		putAnswer(child, assignment.getId(), "최초 답변").andExpect(status().isOk());
		OffsetDateTime now = OffsetDateTime.now(clock);
		recordingRepository
		    .save(new Recording("rec_answer_locked", assignment, "recordings/rec_answer_locked/audio.m4a", "audio.m4a",
		        "audio/mp4", 12, "locked-upload", "locked-version", now));

		putAnswer(child, assignment.getId(), "공개 후 수정").andExpect(status().isConflict())
		    .andExpect(jsonPath("$.errorCode").value("ANSWER_LOCKED"));
	}

	@Test
	void childCreatesAndUpdatesOneAnswerForAssignment() throws Exception {
		MvcResult created = putAnswer(child, assignment.getId(), "  첫 번째 답변  ").andExpect(status().isOk())
		    .andExpect(jsonPath("$.answerId").isNotEmpty())
		    .andExpect(jsonPath("$.assignmentId").value(assignment.getId()))
		    .andExpect(jsonPath("$.text").value("첫 번째 답변")).andExpect(jsonPath("$.submissionStatus").value("SUBMITTED"))
		    .andExpect(jsonPath("$.ttsStatus").value("PROCESSING")).andExpect(jsonPath("$.submittedAt").isNotEmpty())
		    .andExpect(jsonPath("$.updatedAt").isNotEmpty()).andReturn();
		JsonNode createdBody = objectMapper.readTree(created.getResponse().getContentAsByteArray());

		putAnswer(child, assignment.getId(), "수정된 답변").andExpect(status().isOk())
		    .andExpect(jsonPath("$.answerId").value(createdBody.get("answerId").asText()))
		    .andExpect(jsonPath("$.text").value("수정된 답변"))
		    .andExpect(jsonPath("$.submittedAt").value(createdBody.get("submittedAt").asText()));

		org.assertj.core.api.Assertions.assertThat(childAnswerRepository.count()).isEqualTo(1);
	}

	@Test
	void parentCannotSubmitChildAnswer() throws Exception {
		putAnswer(parent, assignment.getId(), "부모가 대신 쓴 답변").andExpect(status().isForbidden())
		    .andExpect(jsonPath("$.errorCode").value("ROLE_NOT_ALLOWED"));
	}

	@Test
	void childCannotSubmitToAnotherPairAssignment() throws Exception {
		User otherChild = userRepository.save(
		    new User("usr_answer_other_child", "다른 자녀", Role.CHILD, "answer-other-child", OffsetDateTime.now(clock)));

		putAnswer(otherChild, assignment.getId(), "권한 없는 답변").andExpect(status().isForbidden())
		    .andExpect(jsonPath("$.errorCode").value("PAIR_ACCESS_DENIED"));
	}

	@Test
	void invalidTextReturnsValidationError() throws Exception {
		putAnswer(child, assignment.getId(), "   ").andExpect(status().isBadRequest())
		    .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));

		putAnswer(child, assignment.getId(), "가".repeat(1001)).andExpect(status().isBadRequest())
		    .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));
	}

	@Test
	void missingAssignmentReturnsNotFound() throws Exception {
		putAnswer(child, "asg_missing", "답변").andExpect(status().isNotFound())
		    .andExpect(jsonPath("$.errorCode").value("ASSIGNMENT_NOT_FOUND"));
	}

	private org.springframework.test.web.servlet.ResultActions putAnswer(User user, String assignmentId, String text)
	    throws Exception {
		return mockMvc.perform(put("/api/v1/assignments/{assignmentId}/child-answer", assignmentId)
		    .header("Authorization", bearer(user)).contentType(MediaType.APPLICATION_JSON)
		    .content(objectMapper.writeValueAsString(new AnswerBody(text))));
	}

	private String bearer(User user) {
		return "Bearer " + tokenProvider.issue(user.getId(), user.getRole()).value();
	}

	private record AnswerBody(String text) {
	}
}
