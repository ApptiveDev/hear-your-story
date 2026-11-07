package com.apptive.backend.domain.recording.service;

public record RecordingUploadedEvent(String recordingId, String processingVersion) {
}
