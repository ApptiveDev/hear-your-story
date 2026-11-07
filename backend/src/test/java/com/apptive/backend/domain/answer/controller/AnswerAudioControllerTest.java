package com.apptive.backend.domain.answer.controller;

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

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class AnswerAudioControllerTest {

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
	private FamilyPairRepository familyPairRepository;
	@Autowired
	private UserRepository userRepository;
	@Autowired
	private QuestionRepository questionRepository;
	@Autowired
	private Clock clock;

	private User parent;
	private User child;
	private ChildAnswer answer;

	@BeforeEach
	void setUp() {
		OffsetDateTime now = OffsetDateTime.now(clock);
		LocalDate assignedDate = LocalDate.of(2000, 1, 1);
		parent = userRepository.save(new User("usr_tts_parent", "부모", Role.PARENT, "tts-parent", now));
		child = userRepository.save(new User("usr_tts_child", "자녀", Role.CHILD, "tts-child", now));
		FamilyPair pair = familyPairRepository.save(new FamilyPair("pair_tts", parent, child, now));
		Question question = questionRepository
		    .save(new Question("qst_tts", assignedDate, "기억에 남는 음식은 무엇인가요?", "MEMORY", null, true));
		Assignment assignment = assignmentRepository.save(new Assignment("asg_tts", pair, question, assignedDate, now));
		answer = new ChildAnswer("ans_tts", assignment, "저는 김치수제비가 기억나요.", TtsStatus.PROCESSING, "tts-version", now,
		    now);
		answer.markTtsReady("tts/ans_tts/audio.mp3", now);
		childAnswerRepository.save(answer);
		recordingRepository.save(new Recording("rec_tts", assignment, "recordings/rec_tts/audio.m4a", "audio.m4a",
		    "audio/mp4", 100, "tts-test", "recording-version", now));
	}

	@Test
	void pairedParentCanReadTtsStatus() throws Exception {
		mockMvc.perform(get("/api/v1/answers/{answerId}/audio", answer.getId()).header("Authorization", bearer(parent)))
		    .andExpect(status().isOk()).andExpect(jsonPath("$.answerId").value(answer.getId()))
		    .andExpect(jsonPath("$.ttsStatus").value("READY")).andExpect(jsonPath("$.audioUrl").doesNotExist())
		    .andExpect(jsonPath("$.processingNotice").doesNotExist());
	}

	@Test
	void childCannotReadTtsEndpoint() throws Exception {
		mockMvc.perform(get("/api/v1/answers/{answerId}/audio", answer.getId()).header("Authorization", bearer(child)))
		    .andExpect(status().isForbidden()).andExpect(jsonPath("$.errorCode").value("ROLE_NOT_ALLOWED"));
	}

	@Test
	void anotherParentCannotReadAnswerAudio() throws Exception {
		User other = userRepository
		    .save(new User("usr_tts_other", "다른 부모", Role.PARENT, "tts-other", OffsetDateTime.now(clock)));
		mockMvc.perform(get("/api/v1/answers/{answerId}/audio", answer.getId()).header("Authorization", bearer(other)))
		    .andExpect(status().isForbidden()).andExpect(jsonPath("$.errorCode").value("PAIR_ACCESS_DENIED"));
	}

	private String bearer(User user) {
		return "Bearer " + tokenProvider.issue(user.getId(), user.getRole()).value();
	}
}
