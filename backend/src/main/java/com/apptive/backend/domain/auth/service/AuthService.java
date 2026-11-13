package com.apptive.backend.domain.auth.service;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.IssuedRegistrationToken;
import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.domain.auth.dto.KakaoLoginResponse;
import com.apptive.backend.domain.auth.dto.TokenRefreshResponse;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Service
public class AuthService {

	private final KakaoIdTokenVerifier kakaoIdTokenVerifier;
	private final UserRepository userRepository;
	private final JwtTokenProvider jwtTokenProvider;
	private final SessionService sessionService;

	@Transactional
	public KakaoLoginResponse loginWithKakao(String idToken) {
		KakaoIdentity identity = kakaoIdTokenVerifier.verify(idToken);
		User user = userRepository.findByAuthProviderAndAuthSubject(AuthProvider.KAKAO, identity.subject())
		    .orElse(null);
		if (user == null) {
			IssuedRegistrationToken registrationToken = jwtTokenProvider.issueRegistration(identity.subject());
			return KakaoLoginResponse.registrationRequired(registrationToken);
		}

		return KakaoLoginResponse.authenticated(sessionService.issue(user));
	}

	public TokenRefreshResponse refresh(String refreshToken) {
		return sessionService.refresh(refreshToken);
	}

	public void logout(String refreshToken) {
		sessionService.logout(refreshToken);
	}
}
