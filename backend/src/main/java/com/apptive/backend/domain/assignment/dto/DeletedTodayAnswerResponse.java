package com.apptive.backend.domain.assignment.dto;

public record DeletedTodayAnswerResponse(String type, String availability,
    String message) implements TodayAnswerResponse {
	public static DeletedTodayAnswerResponse of(String message) {
		return new DeletedTodayAnswerResponse("DELETED", "DELETED", message);
	}
}
