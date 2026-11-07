package com.apptive.backend.domain.question.seed;

import java.io.IOException;
import java.io.InputStream;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.domain.question.entity.Question;
import com.apptive.backend.domain.question.repository.QuestionRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;

@Component
public class QuestionSeedInitializer implements ApplicationRunner {

	private final QuestionRepository questionRepository;
	private final ObjectMapper objectMapper;
	private final Resource seedResource;

	public QuestionSeedInitializer(QuestionRepository questionRepository, ObjectMapper objectMapper,
	    @Value("classpath:seed/mock-questions.json") Resource seedResource) {
		this.questionRepository = questionRepository;
		this.objectMapper = objectMapper;
		this.seedResource = seedResource;
	}

	@Override
	@Transactional
	public void run(ApplicationArguments args) throws IOException {
		List<QuestionSeedDefinition> definitions;
		try (InputStream inputStream = seedResource.getInputStream()) {
			definitions = objectMapper.readValue(inputStream, new TypeReference<>() {
			});
		}
		validate(definitions);
		for (QuestionSeedDefinition definition : definitions) {
			Question question = questionRepository.findById(definition.id())
			    .orElseGet(() -> new Question(definition.id(), definition.scheduledDate(), definition.text(),
			        definition.category(), definition.audioUrl(), definition.active()));
			question.updateFromSeed(definition.scheduledDate(), definition.text().trim(), definition.category().trim(),
			    definition.audioUrl(), definition.active());
			questionRepository.save(question);
		}
	}

	private void validate(List<QuestionSeedDefinition> definitions) {
		Set<String> ids = new HashSet<>();
		Set<java.time.LocalDate> scheduledDates = new HashSet<>();
		for (QuestionSeedDefinition definition : definitions) {
			if (definition.id() == null || definition.id().isBlank() || definition.scheduledDate() == null
			    || definition.text() == null || definition.text().isBlank() || definition.category() == null
			    || definition.category().isBlank()) {
				throw new IllegalStateException("Question seed contains a missing required value");
			}
			if (!ids.add(definition.id())) {
				throw new IllegalStateException("Question seed contains a duplicate id: " + definition.id());
			}
			if (!scheduledDates.add(definition.scheduledDate())) {
				throw new IllegalStateException(
				    "Question seed contains a duplicate scheduledDate: " + definition.scheduledDate());
			}
		}
	}
}
