package com.apptive.backend.domain.auth.dto;

import java.time.OffsetDateTime;

import com.apptive.backend.common.auth.IssuedToken;
import com.apptive.backend.domain.auth.service.IssuedRefreshToken;

public record TokenRefreshResponse(String accessToken, String refreshToken, String tokenType,
    OffsetDateTime expiresAt) {

	public static TokenRefreshResponse of(IssuedToken accessToken, IssuedRefreshToken refreshToken) {
		return new TokenRefreshResponse(accessToken.value(), refreshToken.value(), "Bearer", accessToken.expiresAt());
	}
}
