package com.apptive.backend.domain.assignment.dto;

import java.time.LocalDate;

public record TodayAssignmentResponse(String id, LocalDate assignedDate, TodayQuestionResponse question) {
}
