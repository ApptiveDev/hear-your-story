package com.apptive.backend.domain.story.dto;

import java.time.OffsetDateTime;

import com.apptive.backend.domain.recording.entity.ProcessingStatus;

public record StoryParentAnswerResponse(String recordingId, ProcessingStatus processingStatus, String originalAudioUrl,
    OffsetDateTime originalAudioExpiresAt, String sttText, String summaryText, String processingNotice) {
}
