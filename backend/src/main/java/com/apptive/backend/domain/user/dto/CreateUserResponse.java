package com.apptive.backend.domain.user.dto;

import java.time.OffsetDateTime;

public record CreateUserResponse(UserResponse user, String accessToken, String tokenType, OffsetDateTime expiresAt) {
}
