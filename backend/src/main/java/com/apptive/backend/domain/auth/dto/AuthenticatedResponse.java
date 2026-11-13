package com.apptive.backend.domain.auth.dto;

import java.time.OffsetDateTime;

import com.apptive.backend.common.auth.IssuedToken;
import com.apptive.backend.domain.auth.service.IssuedRefreshToken;
import com.apptive.backend.domain.user.dto.UserResponse;

public record AuthenticatedResponse(AuthStatus authStatus, UserResponse user, String accessToken, String refreshToken,
    String tokenType, OffsetDateTime expiresAt) {

	public static AuthenticatedResponse of(UserResponse user, IssuedToken accessToken,
	    IssuedRefreshToken refreshToken) {
		return new AuthenticatedResponse(AuthStatus.AUTHENTICATED, user, accessToken.value(), refreshToken.value(),
		    "Bearer", accessToken.expiresAt());
	}
}
