package com.apptive.backend.domain.auth.service;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.IssuedRegistrationToken;
import com.apptive.backend.common.auth.IssuedToken;
import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.domain.auth.dto.KakaoLoginResponse;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.user.dto.UserResponse;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Service
public class AuthService {

	private final KakaoIdTokenVerifier kakaoIdTokenVerifier;
	private final UserRepository userRepository;
	private final FamilyPairRepository familyPairRepository;
	private final JwtTokenProvider jwtTokenProvider;
	private final RefreshTokenService refreshTokenService;

	@Transactional
	public KakaoLoginResponse loginWithKakao(String idToken) {
		KakaoIdentity identity = kakaoIdTokenVerifier.verify(idToken);
		User user = userRepository.findByAuthProviderAndAuthSubject(AuthProvider.KAKAO, identity.subject())
		    .orElse(null);
		if (user == null) {
			IssuedRegistrationToken registrationToken = jwtTokenProvider.issueRegistration(identity.subject());
			return KakaoLoginResponse.registrationRequired(registrationToken);
		}

		IssuedToken accessToken = jwtTokenProvider.issue(user.getId(), user.getRole());
		IssuedRefreshToken refreshToken = refreshTokenService.issue(user);
		String pairingStatus = familyPairRepository.existsByMemberId(user.getId()) ? "PAIRED" : "UNPAIRED";
		UserResponse userResponse = new UserResponse(user.getId(), user.getName(), user.getRole(), pairingStatus);
		return KakaoLoginResponse.authenticated(userResponse, accessToken, refreshToken);
	}
}
