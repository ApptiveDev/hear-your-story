package com.apptive.backend.domain.recording.dto;

import java.time.OffsetDateTime;

import com.apptive.backend.domain.assignment.entity.SubmissionStatus;
import com.apptive.backend.domain.recording.entity.ProcessingStatus;

public record RecordingUploadResponse(String recordingId, String assignmentId, SubmissionStatus submissionStatus,
    ProcessingStatus processingStatus, OffsetDateTime submittedAt, String pollingUrl) {
}
