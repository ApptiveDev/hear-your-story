package com.apptive.backend.domain.auth.service;

import org.springframework.stereotype.Service;

import com.apptive.backend.common.auth.IssuedToken;
import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.domain.auth.dto.AuthenticatedResponse;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.user.dto.UserResponse;
import com.apptive.backend.domain.user.entity.User;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Service
public class SessionService {

	private final FamilyPairRepository familyPairRepository;
	private final JwtTokenProvider jwtTokenProvider;
	private final RefreshTokenService refreshTokenService;

	public AuthenticatedResponse issue(User user) {
		IssuedToken accessToken = jwtTokenProvider.issue(user.getId(), user.getRole());
		IssuedRefreshToken refreshToken = refreshTokenService.issue(user);
		String pairingStatus = familyPairRepository.existsByMemberId(user.getId()) ? "PAIRED" : "UNPAIRED";
		UserResponse userResponse = new UserResponse(user.getId(), user.getName(), user.getRole(), pairingStatus);
		return AuthenticatedResponse.of(userResponse, accessToken, refreshToken);
	}
}
