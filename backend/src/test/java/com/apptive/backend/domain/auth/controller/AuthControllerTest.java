package com.apptive.backend.domain.auth.controller;

import static org.hamcrest.Matchers.empty;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Clock;
import java.time.OffsetDateTime;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.domain.auth.repository.RefreshTokenRepository;
import com.apptive.backend.domain.auth.service.KakaoIdTokenVerifier;
import com.apptive.backend.domain.auth.service.KakaoIdentity;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AuthControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private ObjectMapper objectMapper;

	@Autowired
	private RefreshTokenRepository refreshTokenRepository;

	@Autowired
	private FamilyPairRepository familyPairRepository;

	@Autowired
	private UserRepository userRepository;

	@Autowired
	private JwtTokenProvider jwtTokenProvider;

	@Autowired
	private Clock clock;

	@MockitoBean
	private KakaoIdTokenVerifier kakaoIdTokenVerifier;

	@BeforeEach
	void cleanDatabase() {
		refreshTokenRepository.deleteAll();
		familyPairRepository.deleteAll();
		userRepository.deleteAll();
	}

	@Test
	void newKakaoAccountReceivesRegistrationTokenOnly() throws Exception {
		when(kakaoIdTokenVerifier.verify("new-id-token")).thenReturn(new KakaoIdentity("new-subject"));

		MvcResult result = login("new-id-token").andExpect(status().isOk())
		    .andExpect(jsonPath("$.authStatus").value("REGISTRATION_REQUIRED"))
		    .andExpect(jsonPath("$.registrationToken").isNotEmpty())
		    .andExpect(jsonPath("$.registrationTokenExpiresAt").isNotEmpty())
		    .andExpect(jsonPath("$.user").doesNotExist()).andExpect(jsonPath("$.accessToken").doesNotExist())
		    .andExpect(jsonPath("$.refreshToken").doesNotExist()).andReturn();

		String registrationToken = body(result).get("registrationToken").asText();
		org.assertj.core.api.Assertions.assertThat(jwtTokenProvider.parseRegistration(registrationToken))
		    .isEqualTo("new-subject");
		org.assertj.core.api.Assertions.assertThat(refreshTokenRepository.count()).isZero();
	}

	@Test
	void existingKakaoAccountReceivesServiceTokensAndUser() throws Exception {
		OffsetDateTime now = OffsetDateTime.now(clock);
		userRepository.save(new User("usr_existing", "김영희", Role.PARENT, AuthProvider.KAKAO, "existing-subject", now));
		when(kakaoIdTokenVerifier.verify("existing-id-token")).thenReturn(new KakaoIdentity("existing-subject"));

		MvcResult result = login("existing-id-token").andExpect(status().isOk())
		    .andExpect(jsonPath("$.authStatus").value("AUTHENTICATED"))
		    .andExpect(jsonPath("$.user.id").value("usr_existing"))
		    .andExpect(jsonPath("$.user.pairingStatus").value("UNPAIRED"))
		    .andExpect(jsonPath("$.accessToken").isNotEmpty()).andExpect(jsonPath("$.refreshToken").isNotEmpty())
		    .andExpect(jsonPath("$.tokenType").value("Bearer")).andExpect(jsonPath("$.expiresAt").isNotEmpty())
		    .andExpect(jsonPath("$.registrationToken").doesNotExist()).andReturn();

		String refreshToken = body(result).get("refreshToken").asText();
		org.assertj.core.api.Assertions.assertThat(refreshTokenRepository.findByTokenHash(refreshToken)).isEmpty();
		org.assertj.core.api.Assertions.assertThat(refreshTokenRepository.findAll()).singleElement()
		    .satisfies(stored -> org.assertj.core.api.Assertions.assertThat(stored.getTokenHash()).hasSize(64));
	}

	@Test
	void refreshRotatesBothServiceTokensAndRejectsReusingOldToken() throws Exception {
		createExistingUser("refresh-subject");
		when(kakaoIdTokenVerifier.verify("existing-id-token")).thenReturn(new KakaoIdentity("refresh-subject"));
		String firstRefreshToken = body(login("existing-id-token").andReturn()).get("refreshToken").asText();

		MvcResult refreshed = refresh(firstRefreshToken).andExpect(status().isOk())
		    .andExpect(jsonPath("$.accessToken").isNotEmpty()).andExpect(jsonPath("$.refreshToken").isNotEmpty())
		    .andExpect(jsonPath("$.tokenType").value("Bearer")).andExpect(jsonPath("$.expiresAt").isNotEmpty())
		    .andReturn();
		String rotatedRefreshToken = body(refreshed).get("refreshToken").asText();

		org.assertj.core.api.Assertions.assertThat(rotatedRefreshToken).isNotEqualTo(firstRefreshToken);
		refresh(firstRefreshToken).andExpect(status().isUnauthorized())
		    .andExpect(jsonPath("$.errorCode").value("REFRESH_TOKEN_INVALID"));
		org.assertj.core.api.Assertions.assertThat(refreshTokenRepository.findAll()).hasSize(2)
		    .anySatisfy(token -> org.assertj.core.api.Assertions.assertThat(token.getRevokedAt()).isNotNull());
	}

	@Test
	void logoutRevokesRefreshTokenAndIsIdempotent() throws Exception {
		createExistingUser("logout-subject");
		when(kakaoIdTokenVerifier.verify("existing-id-token")).thenReturn(new KakaoIdentity("logout-subject"));
		String refreshToken = body(login("existing-id-token").andReturn()).get("refreshToken").asText();

		logout(refreshToken).andExpect(status().isNoContent());
		logout(refreshToken).andExpect(status().isNoContent());
		refresh(refreshToken).andExpect(status().isUnauthorized())
		    .andExpect(jsonPath("$.errorCode").value("REFRESH_TOKEN_INVALID"));
	}

	@Test
	void unknownRefreshTokenReturnsContractError() throws Exception {
		refresh("unknown-refresh-token").andExpect(status().isUnauthorized())
		    .andExpect(jsonPath("$.errorCode").value("REFRESH_TOKEN_INVALID"));
	}

	@Test
	void blankRefreshTokenReturnsValidationError() throws Exception {
		mockMvc.perform(post("/api/v1/auth/refresh").contentType(MediaType.APPLICATION_JSON).content("""
		    {"refreshToken":" "}
		    """)).andExpect(status().isBadRequest()).andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
		    .andExpect(jsonPath("$.fieldErrors[?(@.field == 'refreshToken')]").exists());
	}

	@Test
	void invalidKakaoIdTokenReturnsContractError() throws Exception {
		when(kakaoIdTokenVerifier.verify("invalid-id-token"))
		    .thenThrow(new ApiException(ErrorCode.KAKAO_ID_TOKEN_INVALID));

		login("invalid-id-token").andExpect(status().isUnauthorized())
		    .andExpect(jsonPath("$.errorCode").value("KAKAO_ID_TOKEN_INVALID"))
		    .andExpect(jsonPath("$.fieldErrors", empty()));
	}

	@Test
	void blankIdTokenReturnsValidationError() throws Exception {
		mockMvc.perform(post("/api/v1/auth/kakao").contentType(MediaType.APPLICATION_JSON).content("""
		    {"idToken":" "}
		    """)).andExpect(status().isBadRequest()).andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
		    .andExpect(jsonPath("$.fieldErrors[?(@.field == 'idToken')]").exists());
	}

	@Test
	void publicLoginIgnoresStaleAuthorizationHeader() throws Exception {
		when(kakaoIdTokenVerifier.verify("new-id-token")).thenReturn(new KakaoIdentity("new-subject"));

		mockMvc.perform(post("/api/v1/auth/kakao").header("Authorization", "Bearer stale-token")
		    .contentType(MediaType.APPLICATION_JSON).content("""
		        {"idToken":"new-id-token"}
		        """)).andExpect(status().isOk()).andExpect(jsonPath("$.authStatus").value("REGISTRATION_REQUIRED"));
	}

	private org.springframework.test.web.servlet.ResultActions login(String idToken) throws Exception {
		return mockMvc.perform(post("/api/v1/auth/kakao").contentType(MediaType.APPLICATION_JSON)
		    .content(objectMapper.writeValueAsString(new LoginBody(idToken))));
	}

	private org.springframework.test.web.servlet.ResultActions refresh(String refreshToken) throws Exception {
		return mockMvc.perform(post("/api/v1/auth/refresh").contentType(MediaType.APPLICATION_JSON)
		    .content(objectMapper.writeValueAsString(new RefreshBody(refreshToken))));
	}

	private org.springframework.test.web.servlet.ResultActions logout(String refreshToken) throws Exception {
		return mockMvc.perform(post("/api/v1/auth/logout").contentType(MediaType.APPLICATION_JSON)
		    .content(objectMapper.writeValueAsString(new RefreshBody(refreshToken))));
	}

	private void createExistingUser(String authSubject) {
		userRepository.save(new User("usr_" + authSubject, "김영희", Role.PARENT, AuthProvider.KAKAO, authSubject,
		    OffsetDateTime.now(clock)));
	}

	private JsonNode body(MvcResult result) throws Exception {
		return objectMapper.readTree(result.getResponse().getContentAsByteArray());
	}

	private record LoginBody(String idToken) {
	}

	private record RefreshBody(String refreshToken) {
	}
}
