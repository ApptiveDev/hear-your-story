package com.apptive.backend.domain.assignment.dto;

import java.time.OffsetDateTime;

import com.apptive.backend.domain.recording.entity.ProcessingStatus;
import com.apptive.backend.domain.recording.entity.Recording;
import com.apptive.backend.infra.storage.SignedAudioUrl;

public record VoiceTodayAnswerResponse(String type, String recordingId, ProcessingStatus processingStatus,
    String originalAudioUrl, OffsetDateTime originalAudioExpiresAt, String sttText, String summaryText,
    String processingNotice) implements TodayAnswerResponse {

	public static VoiceTodayAnswerResponse from(Recording recording, SignedAudioUrl signedAudioUrl) {
		return new VoiceTodayAnswerResponse("VOICE", recording.getId(), recording.getProcessingStatus(),
		    signedAudioUrl == null ? null : signedAudioUrl.url(),
		    signedAudioUrl == null ? null : signedAudioUrl.expiresAt(), recording.getSttText(),
		    recording.getSummaryText(), recording.getProcessingNotice());
	}
}
