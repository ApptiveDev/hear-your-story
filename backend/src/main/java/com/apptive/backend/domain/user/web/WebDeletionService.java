package com.apptive.backend.domain.user.web;

import java.time.Clock;
import java.time.Duration;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.domain.user.dto.AccountDeletionResponse;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;
import com.apptive.backend.domain.user.service.AccountDeletionGuard;
import com.apptive.backend.domain.user.service.AccountDeletionService;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class WebDeletionService {

	private final UserRepository users;
	private final AccountDeletionService deletion;
	private final AccountDeletionGuard guard;
	private final Clock clock;

	@Transactional(readOnly = true)
	public Preview preview(WebDeletionIdentity identity) {
		User user = requireUser(identity);
		return new Preview(user.getId(), user.getName(), user.getRole());
	}

	@Transactional
	public AccountDeletionResponse confirm(WebDeletionIdentity identity, String displayedUserId) {
		User user = requireUser(identity);
		if (!user.getId().equals(displayedUserId)) {
			throw new ApiException(ErrorCode.UNAUTHORIZED);
		}
		return deletion.requestDeletion(new AuthenticatedUser(user.getId(), user.getRole()));
	}

	private User requireUser(WebDeletionIdentity identity) {
		if (identity == null || identity.subject() == null || identity.subject().isBlank()
		    || identity.verifiedAt() == null || identity.verifiedAt().isAfter(clock.instant())
		    || !clock.instant().isBefore(identity.verifiedAt().plus(Duration.ofMinutes(10)))) {
			throw new ApiException(ErrorCode.UNAUTHORIZED);
		}
		guard.requireNotProcessing(AuthProvider.KAKAO, identity.subject());
		return users.findByAuthProviderAndAuthSubject(AuthProvider.KAKAO, identity.subject()).filter(User::isActive)
		    .orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));
	}

	public record Preview(String userId, String name, Role role) {
	}
}
