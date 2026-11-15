package com.apptive.backend.domain.auth.service;

public interface KakaoIdTokenVerifier {

	KakaoIdentity verify(String idToken);
}
