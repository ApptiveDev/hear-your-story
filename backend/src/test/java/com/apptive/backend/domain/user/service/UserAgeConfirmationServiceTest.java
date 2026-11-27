package com.apptive.backend.domain.user.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

import java.time.Clock;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullSource;
import org.junit.jupiter.params.provider.ValueSource;

import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.common.id.IdGenerator;
import com.apptive.backend.domain.auth.service.SessionService;
import com.apptive.backend.domain.user.dto.CreateUserRequest;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.repository.UserRepository;

class UserAgeConfirmationServiceTest {

	@ParameterizedTest
	@NullSource
	@ValueSource(booleans = false)
	void directServiceCallCannotBypassAgeConfirmation(Boolean confirmation) {
		UserRepository users = mock(UserRepository.class);
		AccountDeletionGuard guard = mock(AccountDeletionGuard.class);
		JwtTokenProvider tokens = mock(JwtTokenProvider.class);
		SessionService sessions = mock(SessionService.class);
		IdGenerator ids = mock(IdGenerator.class);
		UserService service = new UserService(users, guard, tokens, sessions, ids, Clock.systemUTC());
		CreateUserRequest request = new CreateUserRequest("이름", Role.CHILD, "test-registration-token", confirmation);
		assertThatThrownBy(() -> service.register(request)).isInstanceOfSatisfying(ApiException.class,
		    exception -> assertThat(exception.getErrorCode()).isEqualTo(ErrorCode.VALIDATION_ERROR));
		verifyNoInteractions(users, guard, tokens, sessions, ids);
	}
}
