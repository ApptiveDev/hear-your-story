package com.apptive.backend.common.auth;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.Date;

import javax.crypto.SecretKey;

import org.springframework.stereotype.Component;

import com.apptive.backend.domain.user.entity.Role;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

@Component
public class JwtTokenProvider {

	private static final int MINIMUM_SECRET_BYTES = 32;
	private static final String TOKEN_TYPE_CLAIM = "tokenType";
	private static final String ACCESS_TOKEN_TYPE = "ACCESS";
	private static final String REGISTRATION_TOKEN_TYPE = "REGISTRATION";

	private final SecretKey signingKey;
	private final long accessTokenExpirationMinutes;
	private final long registrationTokenExpirationMinutes;
	private final Clock clock;

	public JwtTokenProvider(JwtProperties properties, Clock clock) {
		byte[] secretBytes = properties.jwtSecret().getBytes(StandardCharsets.UTF_8);
		if (secretBytes.length < MINIMUM_SECRET_BYTES) {
			throw new IllegalStateException("APP_JWT_SECRET must be at least 32 bytes");
		}
		this.signingKey = Keys.hmacShaKeyFor(secretBytes);
		this.accessTokenExpirationMinutes = properties.accessTokenExpirationMinutes();
		this.registrationTokenExpirationMinutes = properties.registrationTokenExpirationMinutes();
		this.clock = clock;
	}

	public IssuedToken issue(String userId, Role role) {
		OffsetDateTime issuedAt = OffsetDateTime.now(clock).withNano(0);
		OffsetDateTime expiresAt = issuedAt.plusMinutes(accessTokenExpirationMinutes);
		String token = Jwts.builder().subject(userId).claim("role", role.name())
		    .claim(TOKEN_TYPE_CLAIM, ACCESS_TOKEN_TYPE).issuedAt(Date.from(issuedAt.toInstant()))
		    .expiration(Date.from(expiresAt.toInstant())).signWith(signingKey).compact();
		return new IssuedToken(token, expiresAt);
	}

	public IssuedRegistrationToken issueRegistration(String authSubject) {
		OffsetDateTime issuedAt = OffsetDateTime.now(clock).withNano(0);
		OffsetDateTime expiresAt = issuedAt.plusMinutes(registrationTokenExpirationMinutes);
		String token = Jwts.builder().subject(authSubject).claim(TOKEN_TYPE_CLAIM, REGISTRATION_TOKEN_TYPE)
		    .issuedAt(Date.from(issuedAt.toInstant())).expiration(Date.from(expiresAt.toInstant())).signWith(signingKey)
		    .compact();
		return new IssuedRegistrationToken(token, expiresAt);
	}

	public AuthenticatedUser parse(String token) {
		Claims claims = parseClaims(token);
		if (!ACCESS_TOKEN_TYPE.equals(claims.get(TOKEN_TYPE_CLAIM, String.class))) {
			throw new IllegalArgumentException("access token이 아닙니다");
		}
		return new AuthenticatedUser(claims.getSubject(), Role.valueOf(claims.get("role", String.class)));
	}

	public String parseRegistration(String token) {
		Claims claims = parseClaims(token);
		if (!REGISTRATION_TOKEN_TYPE.equals(claims.get(TOKEN_TYPE_CLAIM, String.class))) {
			throw new IllegalArgumentException("registration token이 아닙니다");
		}
		return claims.getSubject();
	}

	private Claims parseClaims(String token) {
		return Jwts.parser().verifyWith(signingKey).clock(() -> Date.from(clock.instant())).build()
		    .parseSignedClaims(token).getPayload();
	}
}
