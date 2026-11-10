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

	private final SecretKey signingKey;
	private final long expirationDays;
	private final Clock clock;

	public JwtTokenProvider(JwtProperties properties, Clock clock) {
		byte[] secretBytes = properties.jwtSecret().getBytes(StandardCharsets.UTF_8);
		if (secretBytes.length < MINIMUM_SECRET_BYTES) {
			throw new IllegalStateException("APP_JWT_SECRET must be at least 32 bytes");
		}
		this.signingKey = Keys.hmacShaKeyFor(secretBytes);
		this.expirationDays = properties.accessTokenExpirationDays();
		this.clock = clock;
	}

	public IssuedToken issue(String userId, Role role) {
		OffsetDateTime issuedAt = OffsetDateTime.now(clock).withNano(0);
		OffsetDateTime expiresAt = issuedAt.plusDays(expirationDays);
		String token = Jwts.builder().subject(userId).claim("role", role.name())
		    .issuedAt(Date.from(issuedAt.toInstant())).expiration(Date.from(expiresAt.toInstant())).signWith(signingKey)
		    .compact();
		return new IssuedToken(token, expiresAt);
	}

	public AuthenticatedUser parse(String token) {
		Claims claims = Jwts.parser().verifyWith(signingKey).clock(() -> Date.from(clock.instant())).build()
		    .parseSignedClaims(token).getPayload();
		return new AuthenticatedUser(claims.getSubject(), Role.valueOf(claims.get("role", String.class)));
	}
}
