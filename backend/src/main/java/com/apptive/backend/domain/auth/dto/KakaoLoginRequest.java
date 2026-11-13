package com.apptive.backend.domain.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record KakaoLoginRequest(@NotBlank @Size(max = 5000) String idToken) {
}
