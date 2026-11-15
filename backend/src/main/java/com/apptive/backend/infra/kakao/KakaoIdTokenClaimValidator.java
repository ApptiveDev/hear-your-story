package com.apptive.backend.infra.kakao;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;

import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.util.StringUtils;

final class KakaoIdTokenClaimValidator implements OAuth2TokenValidator<Jwt> {

	private static final Duration ALLOWED_CLOCK_SKEW = Duration.ofSeconds(60);
	private static final OAuth2Error INVALID_TOKEN = new OAuth2Error("invalid_token", "카카오 ID token claim이 올바르지 않습니다.",
	    null);

	private final String audience;
	private final Clock clock;

	KakaoIdTokenClaimValidator(String audience, Clock clock) {
		this.audience = audience;
		this.clock = clock;
	}

	@Override
	public OAuth2TokenValidatorResult validate(Jwt token) {
		if (!StringUtils.hasText(token.getSubject()) || !token.getAudience().contains(audience)) {
			return OAuth2TokenValidatorResult.failure(INVALID_TOKEN);
		}

		Instant issuedAt = token.getIssuedAt();
		if (issuedAt == null || issuedAt.isAfter(clock.instant().plus(ALLOWED_CLOCK_SKEW))) {
			return OAuth2TokenValidatorResult.failure(INVALID_TOKEN);
		}
		return OAuth2TokenValidatorResult.success();
	}
}
