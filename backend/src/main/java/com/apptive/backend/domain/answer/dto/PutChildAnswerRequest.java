package com.apptive.backend.domain.answer.dto;

import jakarta.validation.constraints.NotBlank;

public record PutChildAnswerRequest(@NotBlank String text) {
}
