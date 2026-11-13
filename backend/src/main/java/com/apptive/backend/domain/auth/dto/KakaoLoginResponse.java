package com.apptive.backend.domain.auth.dto;

import java.time.OffsetDateTime;

import com.apptive.backend.common.auth.IssuedRegistrationToken;
import com.apptive.backend.common.auth.IssuedToken;
import com.apptive.backend.domain.auth.service.IssuedRefreshToken;
import com.apptive.backend.domain.user.dto.UserResponse;
import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record KakaoLoginResponse(AuthStatus authStatus, UserResponse user, String accessToken, String refreshToken,
    String tokenType, OffsetDateTime expiresAt, String registrationToken, OffsetDateTime registrationTokenExpiresAt) {

	public static KakaoLoginResponse authenticated(UserResponse user, IssuedToken accessToken,
	    IssuedRefreshToken refreshToken) {
		return new KakaoLoginResponse(AuthStatus.AUTHENTICATED, user, accessToken.value(), refreshToken.value(),
		    "Bearer", accessToken.expiresAt(), null, null);
	}

	public static KakaoLoginResponse registrationRequired(IssuedRegistrationToken registrationToken) {
		return new KakaoLoginResponse(AuthStatus.REGISTRATION_REQUIRED, null, null, null, null, null,
		    registrationToken.value(), registrationToken.expiresAt());
	}
}
