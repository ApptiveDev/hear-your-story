package com.apptive.backend.domain.question.seed;

import java.time.LocalDate;

public record QuestionSeedDefinition(String id, LocalDate scheduledDate, String text, String category, String audioUrl,
    boolean active) {
}
