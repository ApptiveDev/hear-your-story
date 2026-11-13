package com.apptive.backend.infra.kakao;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.stereotype.Component;

import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.domain.auth.service.KakaoIdTokenVerifier;
import com.apptive.backend.domain.auth.service.KakaoIdentity;

@Component
public class KakaoOidcIdTokenVerifier implements KakaoIdTokenVerifier {

	private final JwtDecoder jwtDecoder;

	public KakaoOidcIdTokenVerifier(@Qualifier("kakaoJwtDecoder") JwtDecoder jwtDecoder) {
		this.jwtDecoder = jwtDecoder;
	}

	@Override
	public KakaoIdentity verify(String idToken) {
		try {
			Jwt jwt = jwtDecoder.decode(idToken);
			return new KakaoIdentity(jwt.getSubject());
		} catch (JwtException | IllegalArgumentException exception) {
			throw new ApiException(ErrorCode.KAKAO_ID_TOKEN_INVALID);
		}
	}
}
