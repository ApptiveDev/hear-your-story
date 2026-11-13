package com.apptive.backend.domain.auth.service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.Base64;
import java.util.HexFormat;

import org.springframework.stereotype.Service;

import com.apptive.backend.common.auth.JwtProperties;
import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.common.id.IdGenerator;
import com.apptive.backend.domain.auth.entity.RefreshToken;
import com.apptive.backend.domain.auth.repository.RefreshTokenRepository;
import com.apptive.backend.domain.user.entity.User;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Service
public class RefreshTokenService {

	private static final int TOKEN_BYTES = 32;
	private static final String HASH_ALGORITHM = "SHA-256";

	private final RefreshTokenRepository refreshTokenRepository;
	private final IdGenerator idGenerator;
	private final JwtProperties properties;
	private final Clock clock;
	private final SecureRandom secureRandom = new SecureRandom();

	public IssuedRefreshToken issue(User user) {
		OffsetDateTime createdAt = OffsetDateTime.now(clock).withNano(0);
		OffsetDateTime expiresAt = createdAt.plusDays(properties.refreshTokenExpirationDays());
		String value = generateValue();
		refreshTokenRepository
		    .save(new RefreshToken(idGenerator.generate("rft"), user, hash(value), expiresAt, createdAt));
		return new IssuedRefreshToken(value, expiresAt);
	}

	public RotatedRefreshToken rotate(String value) {
		OffsetDateTime now = OffsetDateTime.now(clock).withNano(0);
		RefreshToken current = refreshTokenRepository.findByTokenHashForUpdate(hash(value))
		    .orElseThrow(() -> new ApiException(ErrorCode.REFRESH_TOKEN_INVALID));
		if (!current.isUsableAt(now)) {
			throw new ApiException(ErrorCode.REFRESH_TOKEN_INVALID);
		}

		current.revoke(now);
		return new RotatedRefreshToken(current.getUser(), issue(current.getUser()));
	}

	public void revoke(String value) {
		OffsetDateTime now = OffsetDateTime.now(clock).withNano(0);
		refreshTokenRepository.findByTokenHashForUpdate(hash(value)).ifPresent(token -> token.revoke(now));
	}

	String hash(String value) {
		try {
			MessageDigest digest = MessageDigest.getInstance(HASH_ALGORITHM);
			return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
		} catch (NoSuchAlgorithmException exception) {
			throw new IllegalStateException("SHA-256을 사용할 수 없습니다.", exception);
		}
	}

	private String generateValue() {
		byte[] bytes = new byte[TOKEN_BYTES];
		secureRandom.nextBytes(bytes);
		return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
	}
}
