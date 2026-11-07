package com.apptive.backend.domain.pair.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record JoinPairRequest(@NotBlank @Pattern(regexp = "\\d{6}") String inviteCode) {
}
