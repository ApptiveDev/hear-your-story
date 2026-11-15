package com.apptive.backend.domain.auth.repository;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.OffsetDateTime;

import jakarta.persistence.EntityManager;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.ActiveProfiles;

import com.apptive.backend.domain.auth.entity.RefreshToken;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;

@DataJpaTest
@ActiveProfiles("test")
class AuthPersistenceTest {

	@Autowired
	private UserRepository userRepository;

	@Autowired
	private RefreshTokenRepository refreshTokenRepository;

	@Autowired
	private EntityManager entityManager;

	@Test
	void storesKakaoIdentityWithoutDeviceId() {
		OffsetDateTime now = OffsetDateTime.parse("2026-11-14T09:00:00+09:00");
		userRepository.saveAndFlush(new User("usr_kakao", "김영희", Role.PARENT, AuthProvider.KAKAO, "123456", now));
		entityManager.clear();

		User found = userRepository.findByAuthProviderAndAuthSubject(AuthProvider.KAKAO, "123456").orElseThrow();

		assertThat(found.getId()).isEqualTo("usr_kakao");
		assertThat(found.getDeviceId()).isNull();
	}

	@Test
	void rejectsDuplicateKakaoIdentity() {
		OffsetDateTime now = OffsetDateTime.parse("2026-11-14T09:00:00+09:00");
		userRepository.saveAndFlush(new User("usr_first", "첫 사용자", Role.PARENT, AuthProvider.KAKAO, "123456", now));

		User duplicate = new User("usr_second", "중복 사용자", Role.CHILD, AuthProvider.KAKAO, "123456", now);

		assertThatThrownBy(() -> userRepository.saveAndFlush(duplicate))
		    .isInstanceOf(DataIntegrityViolationException.class);
	}

	@Test
	void storesOnlyRefreshTokenHashAndTracksRevocation() {
		OffsetDateTime now = OffsetDateTime.parse("2026-11-14T09:00:00+09:00");
		User user = userRepository
		    .saveAndFlush(new User("usr_refresh", "김영희", Role.PARENT, AuthProvider.KAKAO, "789012", now));
		String tokenHash = "a".repeat(64);
		refreshTokenRepository.saveAndFlush(new RefreshToken("rft_test", user, tokenHash, now.plusDays(30), now));
		entityManager.clear();

		RefreshToken stored = refreshTokenRepository.findByTokenHash(tokenHash).orElseThrow();
		assertThat(stored.isUsableAt(now)).isTrue();

		stored.revoke(now.plusMinutes(1));
		refreshTokenRepository.saveAndFlush(stored);
		entityManager.clear();

		RefreshToken revoked = refreshTokenRepository.findByTokenHash(tokenHash).orElseThrow();
		assertThat(revoked.isUsableAt(now.plusMinutes(2))).isFalse();
		assertThat(revoked.getRevokedAt()).isEqualTo(now.plusMinutes(1));
	}
}
