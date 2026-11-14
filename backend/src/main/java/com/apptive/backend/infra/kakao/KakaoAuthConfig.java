package com.apptive.backend.infra.kakao;

import java.time.Clock;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.web.client.RestClient;

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

	@Bean
	public RestClient kakaoAdminRestClient(KakaoAuthProperties properties) {
		SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
		requestFactory.setConnectTimeout(5_000);
		requestFactory.setReadTimeout(10_000);
		return RestClient.builder().baseUrl("https://kapi.kakao.com").requestFactory(requestFactory)
		    .defaultHeader(HttpHeaders.AUTHORIZATION, "KakaoAK " + safeAdminKey(properties)).build();
	}

	private String safeAdminKey(KakaoAuthProperties properties) {
		return properties.adminKey() == null ? "" : properties.adminKey();
	}
}
