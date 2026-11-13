package com.apptive.backend.domain.user.service;

import java.time.Clock;
import java.time.OffsetDateTime;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.common.id.IdGenerator;
import com.apptive.backend.domain.auth.dto.AuthenticatedResponse;
import com.apptive.backend.domain.auth.service.SessionService;
import com.apptive.backend.domain.user.dto.CreateUserRequest;
import com.apptive.backend.domain.user.dto.UserResponse;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;

import io.jsonwebtoken.JwtException;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Service
public class UserService {

	private final UserRepository userRepository;
	private final JwtTokenProvider tokenProvider;
	private final SessionService sessionService;
	private final IdGenerator idGenerator;
	private final Clock clock;

	@Transactional
	public AuthenticatedResponse register(CreateUserRequest request) {
		String authSubject = parseRegistrationToken(request.registrationToken());
		if (userRepository.findByAuthProviderAndAuthSubject(AuthProvider.KAKAO, authSubject).isPresent()) {
			throw new ApiException(ErrorCode.KAKAO_ACCOUNT_ALREADY_REGISTERED);
		}

		User user = new User(idGenerator.generate("usr"), request.name().trim(), request.role(), AuthProvider.KAKAO,
		    authSubject, OffsetDateTime.now(clock));
		try {
			userRepository.saveAndFlush(user);
		} catch (DataIntegrityViolationException exception) {
			throw new ApiException(ErrorCode.KAKAO_ACCOUNT_ALREADY_REGISTERED);
		}
		return sessionService.issue(user);
	}

	@Transactional(readOnly = true)
	public UserResponse getMe(AuthenticatedUser authenticatedUser) {
		User user = userRepository.findById(authenticatedUser.userId())
		    .orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));
		return sessionService.toUserResponse(user);
	}

	private String parseRegistrationToken(String registrationToken) {
		try {
			return tokenProvider.parseRegistration(registrationToken);
		} catch (JwtException | IllegalArgumentException exception) {
			throw new ApiException(ErrorCode.REGISTRATION_TOKEN_INVALID);
		}
	}
}
