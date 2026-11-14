package com.apptive.backend.domain.story.dto;

import java.time.OffsetDateTime;

import com.apptive.backend.domain.recording.entity.ProcessingStatus;

public record StoryParentAnswerResponse(String availability, String recordingId, ProcessingStatus processingStatus,
    String originalAudioUrl, OffsetDateTime originalAudioExpiresAt, String sttText, String summaryText,
    String processingNotice) {

	public static StoryParentAnswerResponse deleted() {
		return new StoryParentAnswerResponse("DELETED", null, null, null, null, null, null, "부모님이 탈퇴하여 음성 기록이 삭제되었어요.");
	}
}
