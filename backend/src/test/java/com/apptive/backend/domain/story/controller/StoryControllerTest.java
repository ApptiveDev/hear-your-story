package com.apptive.backend.domain.story.controller;

import static org.assertj.core.api.Assertions.assertThat;
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
class StoryControllerTest {

	@Autowired
	private MockMvc mockMvc;
	@Autowired
	private ObjectMapper objectMapper;
	@Autowired
	private JwtTokenProvider tokenProvider;
	@Autowired
	private UserRepository userRepository;
	@Autowired
	private FamilyPairRepository familyPairRepository;
	@Autowired
	private QuestionRepository questionRepository;
	@Autowired
	private AssignmentRepository assignmentRepository;
	@Autowired
	private RecordingRepository recordingRepository;
	@Autowired
	private ChildAnswerRepository childAnswerRepository;
	@Autowired
	private Clock clock;

	private User parent;
	private User child;
	private FamilyPair pair;

	@BeforeEach
	void setUp() {
		OffsetDateTime now = OffsetDateTime.now(clock);
		parent = userRepository.save(new User("usr_story_parent", "부모", Role.PARENT, "story-parent", now));
		child = userRepository.save(new User("usr_story_child", "자녀", Role.CHILD, "story-child", now));
		pair = familyPairRepository.save(new FamilyPair("pair_story", parent, child, now));

		createRevealed("asg_story_old", LocalDate.of(2000, 1, 1), "옛날 질문", "옛날 답");
		createRevealed("asg_story_new", LocalDate.of(2000, 1, 2), "최근 질문", "최근 답");
		createIncomplete("asg_story_incomplete", LocalDate.of(2000, 1, 3));
	}

	@Test
	void returnsOnlyRevealedStoriesNewestFirstWithCursor() throws Exception {
		MvcResult firstResult = mockMvc
		    .perform(get("/api/v1/stories").param("limit", "1").header("Authorization", bearer(parent)))
		    .andExpect(status().isOk()).andExpect(jsonPath("$.items.length()").value(1))
		    .andExpect(jsonPath("$.items[0].storyId").value("story_story_new"))
		    .andExpect(jsonPath("$.items[0].assignmentId").value("asg_story_new"))
		    .andExpect(jsonPath("$.items[0].question.text").value("최근 질문"))
		    .andExpect(jsonPath("$.items[0].parentAnswer.summaryText").value("정리된 최근 질문"))
		    .andExpect(jsonPath("$.items[0].childAnswer.text").value("최근 답"))
		    .andExpect(jsonPath("$.hasNext").value(true)).andExpect(jsonPath("$.nextCursor").isNotEmpty()).andReturn();
		JsonNode firstBody = objectMapper.readTree(firstResult.getResponse().getContentAsByteArray());

		MvcResult secondResult = mockMvc
		    .perform(get("/api/v1/stories").param("limit", "1").param("cursor", firstBody.get("nextCursor").asText())
		        .header("Authorization", bearer(child)))
		    .andExpect(status().isOk()).andExpect(jsonPath("$.items.length()").value(1))
		    .andExpect(jsonPath("$.items[0].assignmentId").value("asg_story_old"))
		    .andExpect(jsonPath("$.hasNext").value(false)).andExpect(jsonPath("$.nextCursor").doesNotExist())
		    .andReturn();

		JsonNode secondBody = objectMapper.readTree(secondResult.getResponse().getContentAsByteArray());
		assertThat(secondBody.get("items").get(0).get("revealedAt").asText()).isNotBlank();
	}

	@Test
	void invalidCursorAndLimitReturnValidationError() throws Exception {
		mockMvc
		    .perform(
		        get("/api/v1/stories").param("cursor", "not-a-valid-cursor").header("Authorization", bearer(parent)))
		    .andExpect(status().isBadRequest()).andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));

		mockMvc.perform(get("/api/v1/stories").param("limit", "51").header("Authorization", bearer(parent)))
		    .andExpect(status().isBadRequest()).andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));
	}

	@Test
	void returnsRevealedStoriesForMonthOldestFirstWithoutPagination() throws Exception {
		mockMvc.perform(get("/api/v1/stories").param("month", "2000-01").header("Authorization", bearer(parent)))
		    .andExpect(status().isOk()).andExpect(jsonPath("$.items.length()").value(2))
		    .andExpect(jsonPath("$.items[0].assignmentId").value("asg_story_old"))
		    .andExpect(jsonPath("$.items[1].assignmentId").value("asg_story_new"))
		    .andExpect(jsonPath("$.nextCursor").doesNotExist()).andExpect(jsonPath("$.hasNext").value(false));
	}

	@Test
	void emptyMonthReturnsEmptyItems() throws Exception {
		mockMvc.perform(get("/api/v1/stories").param("month", "2000-02").header("Authorization", bearer(child)))
		    .andExpect(status().isOk()).andExpect(jsonPath("$.items").isEmpty())
		    .andExpect(jsonPath("$.nextCursor").doesNotExist()).andExpect(jsonPath("$.hasNext").value(false));
	}

	@Test
	void invalidMonthOrMixedPaginationReturnsValidationError() throws Exception {
		mockMvc.perform(get("/api/v1/stories").param("month", "2000-1").header("Authorization", bearer(parent)))
		    .andExpect(status().isBadRequest()).andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));

		mockMvc
		    .perform(get("/api/v1/stories").param("month", "2000-01").param("cursor", "cursor").header("Authorization",
		        bearer(parent)))
		    .andExpect(status().isBadRequest()).andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));

		mockMvc
		    .perform(get("/api/v1/stories").param("month", "2000-01").param("limit", "20").header("Authorization",
		        bearer(parent)))
		    .andExpect(status().isBadRequest()).andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));
	}

	@Test
	void unpairedUserCannotReadStories() throws Exception {
		User unpaired = userRepository
		    .save(new User("usr_story_unpaired", "미연결 사용자", Role.CHILD, "story-unpaired", OffsetDateTime.now(clock)));
		mockMvc.perform(get("/api/v1/stories").header("Authorization", bearer(unpaired)))
		    .andExpect(status().isConflict()).andExpect(jsonPath("$.errorCode").value("PAIR_NOT_FOUND"));
	}

	private void createRevealed(String assignmentId, LocalDate date, String questionText, String childText) {
		OffsetDateTime submittedAt = OffsetDateTime.now(clock).minusDays(2);
		Assignment assignment = createAssignment(assignmentId, date, questionText);
		Recording recording = new Recording("rec_" + assignmentId, assignment,
		    "recordings/" + assignmentId + "/audio.m4a", "audio.m4a", "audio/mp4", 100, "idempotency-" + assignmentId,
		    "version-" + assignmentId, submittedAt);
		recording.markSttProcessing(submittedAt);
		recording.markSttDone("원문 " + questionText, submittedAt);
		recording.markLlmProcessing(submittedAt);
		recording.markReady("정리된 " + questionText, submittedAt);
		recordingRepository.save(recording);
		childAnswerRepository.save(new ChildAnswer("ans_" + assignmentId, assignment, childText, TtsStatus.PROCESSING,
		    "tts-" + assignmentId, submittedAt.plusMinutes(1), submittedAt.plusMinutes(1)));
	}

	private void createIncomplete(String assignmentId, LocalDate date) {
		Assignment assignment = createAssignment(assignmentId, date, "아직 답하지 않은 질문");
		childAnswerRepository.save(new ChildAnswer("ans_" + assignmentId, assignment, "자녀만 답했습니다.",
		    TtsStatus.PROCESSING, "tts-" + assignmentId, OffsetDateTime.now(clock), OffsetDateTime.now(clock)));
	}

	private Assignment createAssignment(String assignmentId, LocalDate date, String questionText) {
		Question question = questionRepository
		    .save(new Question("qst_" + assignmentId, date, questionText, "MEMORY", null, true));
		return assignmentRepository.save(new Assignment(assignmentId, pair, question, date, OffsetDateTime.now(clock)));
	}

	private String bearer(User user) {
		return "Bearer " + tokenProvider.issue(user.getId(), user.getRole()).value();
	}
}
