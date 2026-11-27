package com.apptive.backend.domain.user.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.client.registration.ClientRegistration;
import org.springframework.security.oauth2.core.AuthorizationGrantType;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.gen.RSAKeyGenerator;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import com.sun.net.httpserver.HttpServer;

class WebDeletionIdTokenTest {

	private static HttpServer server;
	private static RSAKey key;
	private static JwtDecoder decoder;

	@BeforeAll
	static void setup() throws Exception {
		key = new RSAKeyGenerator(2048).keyID("web-test-key").generate();
		byte[] jwks = new JWKSet(key.toPublicJWK()).toString().getBytes(StandardCharsets.UTF_8);
		server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
		server.createContext("/jwks", exchange -> {
			exchange.getResponseHeaders().set("Content-Type", "application/json");
			exchange.sendResponseHeaders(200, jwks.length);
			try (var output = exchange.getResponseBody()) {
				output.write(jwks);
			}
		});
		server.start();
		ClientRegistration client = ClientRegistration.withRegistrationId("web-test").clientId("test-rest-key")
		    .authorizationGrantType(AuthorizationGrantType.AUTHORIZATION_CODE)
		    .redirectUri("https://service.example/login/oauth2/code/kakao-deletion")
		    .authorizationUri("https://kauth.kakao.com/oauth/authorize").tokenUri("https://kauth.kakao.com/oauth/token")
		    .issuerUri("https://kauth.kakao.com")
		    .jwkSetUri("http://127.0.0.1:" + server.getAddress().getPort() + "/jwks").build();
		decoder = new WebDeletionSecurityConfig().webDeletionIdTokenDecoderFactory().createDecoder(client);
	}

	@AfterAll
	static void stop() {
		if (server != null) {
			server.stop(0);
		}
	}

	@Test
	void acceptsSignedTokenForThisWebClient() throws Exception {
		assertThat(
		    decoder.decode(token(key, "https://kauth.kakao.com", "test-rest-key", Instant.now().plusSeconds(300)))
		        .getSubject())
		    .isEqualTo("verified-test-subject");
	}

	@Test
	void rejectsDifferentAudienceIssuerExpiredTokenAndForgedSignature() throws Exception {
		assertThatThrownBy(() -> decoder
		    .decode(token(key, "https://kauth.kakao.com", "another-client", Instant.now().plusSeconds(300))))
		    .isInstanceOf(JwtException.class);
		assertThatThrownBy(() -> decoder
		    .decode(token(key, "https://attacker.example", "test-rest-key", Instant.now().plusSeconds(300))))
		    .isInstanceOf(JwtException.class);
		assertThatThrownBy(() -> decoder
		    .decode(token(key, "https://kauth.kakao.com", "test-rest-key", Instant.now().minusSeconds(300))))
		    .isInstanceOf(JwtException.class);
		RSAKey forged = new RSAKeyGenerator(2048).keyID("web-test-key").generate();
		assertThatThrownBy(() -> decoder
		    .decode(token(forged, "https://kauth.kakao.com", "test-rest-key", Instant.now().plusSeconds(300))))
		    .isInstanceOf(JwtException.class);
	}

	private static String token(RSAKey signingKey, String issuer, String audience, Instant expires) throws Exception {
		JWTClaimsSet claims = new JWTClaimsSet.Builder().issuer(issuer).subject("verified-test-subject")
		    .audience(audience).issueTime(Date.from(Instant.now().minusSeconds(600))).expirationTime(Date.from(expires))
		    .build();
		SignedJWT jwt = new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.RS256).keyID("web-test-key").build(), claims);
		jwt.sign(new RSASSASigner(signingKey));
		return jwt.serialize();
	}
}
