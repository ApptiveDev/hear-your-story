package com.apptive.backend.domain.auth.controller;

import jakarta.validation.Valid;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.apptive.backend.domain.auth.dto.KakaoLoginRequest;
import com.apptive.backend.domain.auth.dto.KakaoLoginResponse;
import com.apptive.backend.domain.auth.dto.RefreshTokenRequest;
import com.apptive.backend.domain.auth.dto.TokenRefreshResponse;
import com.apptive.backend.domain.auth.service.AuthService;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

	private final AuthService authService;

	@PostMapping("/kakao")
	public ResponseEntity<KakaoLoginResponse> loginWithKakao(@Valid @RequestBody KakaoLoginRequest request) {
		return ResponseEntity.ok(authService.loginWithKakao(request.idToken()));
	}

	@PostMapping("/refresh")
	public ResponseEntity<TokenRefreshResponse> refresh(@Valid @RequestBody RefreshTokenRequest request) {
		return ResponseEntity.ok(authService.refresh(request.refreshToken()));
	}

	@PostMapping("/logout")
	public ResponseEntity<Void> logout(@Valid @RequestBody RefreshTokenRequest request) {
		authService.logout(request.refreshToken());
		return ResponseEntity.noContent().build();
	}
}
