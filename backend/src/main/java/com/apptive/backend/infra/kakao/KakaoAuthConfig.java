package com.apptive.backend.infra.kakao;

import java.time.Clock;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

@Configuration
@EnableConfigurationProperties(KakaoAuthProperties.class)
public class KakaoAuthConfig {

	@Bean
	@Qualifier("kakaoJwtDecoder")
	public JwtDecoder kakaoJwtDecoder(KakaoAuthProperties properties, Clock clock) {
		NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri(properties.jwkSetUri())
		    .jwsAlgorithm(SignatureAlgorithm.RS256).build();
		OAuth2TokenValidator<Jwt> issuerAndTimestamp = JwtValidators.createDefaultWithIssuer(properties.issuer());
		OAuth2TokenValidator<Jwt> claims = new KakaoIdTokenClaimValidator(properties.nativeAppKey(), clock);
		decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(issuerAndTimestamp, claims));
		return decoder;
	}
}
