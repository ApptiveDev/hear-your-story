package com.apptive.backend.domain.assignment.dto;

import com.apptive.backend.domain.answer.entity.ChildAnswer;
import com.apptive.backend.domain.answer.entity.TtsStatus;

public record TextTodayAnswerResponse(String type, String answerId, String text,
    TtsStatus ttsStatus) implements TodayAnswerResponse {

	public static TextTodayAnswerResponse from(ChildAnswer answer) {
		return new TextTodayAnswerResponse("TEXT", answer.getId(), answer.getText(), answer.getTtsStatus());
	}
}
