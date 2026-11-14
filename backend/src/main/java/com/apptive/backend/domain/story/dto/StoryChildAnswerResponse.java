package com.apptive.backend.domain.story.dto;

import com.apptive.backend.domain.answer.entity.TtsStatus;

public record StoryChildAnswerResponse(String availability, String answerId, String text, TtsStatus ttsStatus) {

	public static StoryChildAnswerResponse deleted() {
		return new StoryChildAnswerResponse("DELETED", null, null, null);
	}
}
