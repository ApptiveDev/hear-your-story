package com.apptive.backend.domain.recording.dto;

import java.time.OffsetDateTime;

import com.apptive.backend.domain.recording.entity.ProcessingStatus;

public record RecordingStatusResponse(String recordingId, String assignmentId, ProcessingStatus processingStatus,
    String sttText, String summaryText, String failedStage, String failureCode, String processingNotice,
    OffsetDateTime updatedAt) {
}
