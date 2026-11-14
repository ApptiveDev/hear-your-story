package com.apptive.backend.domain.auth.service;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.IssuedToken;
import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.domain.auth.dto.AuthenticatedResponse;
import com.apptive.backend.domain.auth.dto.TokenRefreshResponse;
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
		return AuthenticatedResponse.of(toUserResponse(user), accessToken, refreshToken);
	}

	public UserResponse toUserResponse(User user) {
		String pairingStatus = familyPairRepository.existsActiveByMemberId(user.getId()) ? "PAIRED" : "UNPAIRED";
		return new UserResponse(user.getId(), user.getName(), user.getRole(), pairingStatus);
	}

	@Transactional
	public TokenRefreshResponse refresh(String refreshToken) {
		RotatedRefreshToken rotated = refreshTokenService.rotate(refreshToken);
		IssuedToken accessToken = jwtTokenProvider.issue(rotated.user().getId(), rotated.user().getRole());
		return TokenRefreshResponse.of(accessToken, rotated.issuedToken());
	}

	@Transactional
	public void logout(String refreshToken) {
		refreshTokenService.revoke(refreshToken);
	}
}
