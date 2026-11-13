package com.apptive.backend.infra.kakao;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;

class KakaoIdTokenClaimValidatorTest {

	private static final Instant NOW = Instant.parse("2026-11-14T00:00:00Z");
	private static final String NATIVE_APP_KEY = "native-app-key";
	private final KakaoIdTokenClaimValidator validator = new KakaoIdTokenClaimValidator(NATIVE_APP_KEY,
	    Clock.fixed(NOW, ZoneOffset.UTC));

	@Test
	void acceptsExpectedAudienceSubjectAndIssuedAt() {
		assertThat(validator.validate(jwt("kakao-subject", List.of(NATIVE_APP_KEY), NOW)).hasErrors()).isFalse();
	}

	@Test
	void rejectsDifferentAudience() {
		assertThat(validator.validate(jwt("kakao-subject", List.of("other-app-key"), NOW)).hasErrors()).isTrue();
	}

	@Test
	void rejectsTokenIssuedTooFarInFuture() {
		assertThat(validator.validate(jwt("kakao-subject", List.of(NATIVE_APP_KEY), NOW.plusSeconds(61))).hasErrors())
		    .isTrue();
	}

	private Jwt jwt(String subject, List<String> audience, Instant issuedAt) {
		return Jwt.withTokenValue("id-token").header("alg", "RS256").issuer("https://kauth.kakao.com").subject(subject)
		    .audience(audience).issuedAt(issuedAt).expiresAt(NOW.plusSeconds(3600)).build();
	}
}
