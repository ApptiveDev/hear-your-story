package com.apptive.backend.domain.answer.dto;

import java.time.OffsetDateTime;

import com.apptive.backend.domain.answer.entity.TtsStatus;
import com.apptive.backend.domain.assignment.entity.SubmissionStatus;

public record ChildAnswerResponse(String answerId, String assignmentId, String text, SubmissionStatus submissionStatus,
    TtsStatus ttsStatus, OffsetDateTime submittedAt, OffsetDateTime updatedAt) {
}
