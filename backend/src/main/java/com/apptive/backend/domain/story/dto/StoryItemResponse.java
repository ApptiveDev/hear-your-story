package com.apptive.backend.domain.story.dto;

import java.time.LocalDate;
import java.time.OffsetDateTime;

public record StoryItemResponse(String storyId, String assignmentId, LocalDate assignedDate,
    StoryQuestionResponse question, StoryParentAnswerResponse parentAnswer, StoryChildAnswerResponse childAnswer,
    OffsetDateTime revealedAt) {
}
