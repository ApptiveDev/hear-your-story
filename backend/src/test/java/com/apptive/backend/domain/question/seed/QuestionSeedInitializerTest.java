package com.apptive.backend.domain.question.seed;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import com.apptive.backend.domain.question.entity.Question;
import com.apptive.backend.domain.question.repository.QuestionRepository;

@SpringBootTest
@ActiveProfiles("test")
class QuestionSeedInitializerTest {

	@Autowired
	private QuestionRepository questionRepository;

	@Test
	void mockQuestionsAreLoadedFromJson() {
		Question question = questionRepository.findByScheduledDateAndActiveTrue(LocalDate.of(2026, 9, 24))
		    .orElseThrow();

		assertThat(question.getId()).isEqualTo("qst_mock_20260924");
		assertThat(question.getText()).isEqualTo("어릴 때 가장 좋아했던 놀이는 무엇이었나요?");
		assertThat(question.getCategory()).isEqualTo("CHILDHOOD");
		assertThat(question.getAudioUrl()).isNull();
		assertThat(questionRepository.count()).isEqualTo(9);
	}
}
