package com.apptive.backend.infra.kakao;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Instant;

import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;

import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;

class KakaoOidcIdTokenVerifierTest {

	private final JwtDecoder jwtDecoder = mock(JwtDecoder.class);
	private final KakaoOidcIdTokenVerifier verifier = new KakaoOidcIdTokenVerifier(jwtDecoder);

	@Test
	void returnsVerifiedSubject() {
		Jwt jwt = Jwt.withTokenValue("id-token").header("alg", "RS256").subject("kakao-subject").issuedAt(Instant.now())
		    .expiresAt(Instant.now().plusSeconds(3600)).build();
		when(jwtDecoder.decode("id-token")).thenReturn(jwt);

		assertThat(verifier.verify("id-token").subject()).isEqualTo("kakao-subject");
	}

	@Test
	void mapsDecoderFailureWithoutExposingDetails() {
		when(jwtDecoder.decode("invalid-token")).thenThrow(new BadJwtException("raw decoder detail"));

		assertThatThrownBy(() -> verifier.verify("invalid-token")).isInstanceOfSatisfying(ApiException.class,
		    exception -> assertThat(exception.getErrorCode()).isEqualTo(ErrorCode.KAKAO_ID_TOKEN_INVALID));
	}
}
