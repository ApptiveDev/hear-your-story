package com.apptive.backend.domain.user.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.Map;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.domain.auth.repository.RefreshTokenRepository;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class UserAgeConfirmationControllerTest {

	@Autowired
	private MockMvc mvc;
	@Autowired
	private ObjectMapper mapper;
	@Autowired
	private JwtTokenProvider tokens;
	@Autowired
	private UserRepository users;
	@Autowired
	private RefreshTokenRepository refreshTokens;

	@ParameterizedTest
	@EnumSource(Role.class)
	void parentAndChildMustExplicitlyConfirmBeforeRegistration(Role role) throws Exception {
		String subject = "age-confirmation-" + role;
		String token = tokens.issueRegistration(subject).value();
		ObjectNode body = mapper.valueToTree(Map.of("name", "가입자", "role", role.name(), "registrationToken", token));
		long previousUsers = users.count();
		long previousRefreshTokens = refreshTokens.count();

		// 누락·null·false 모두 같은 field error로 거절한다. 가입용 토큰은 소모하지 않는다.
		expectUnconfirmed(body, "not_null");
		body.putNull("age14OrOlderConfirmed");
		expectUnconfirmed(body, "not_null");
		body.put("age14OrOlderConfirmed", false);
		expectUnconfirmed(body, "assert_true");
		assertThat(users.count()).isEqualTo(previousUsers);
		assertThat(refreshTokens.count()).isEqualTo(previousRefreshTokens);
		assertThat(users.findByAuthProviderAndAuthSubject(AuthProvider.KAKAO, subject)).isEmpty();

		// 같은 가입용 토큰으로 실제 확인한 뒤 재시도하면 기존 성공 계약을 유지한다.
		body.put("age14OrOlderConfirmed", true);
		mvc.perform(
		    post("/api/v1/users").contentType(MediaType.APPLICATION_JSON).content(mapper.writeValueAsBytes(body)))
		    .andExpect(status().isCreated()).andExpect(jsonPath("$.authStatus").value("AUTHENTICATED"))
		    .andExpect(jsonPath("$.user.role").value(role.name())).andExpect(jsonPath("$.accessToken").isNotEmpty())
		    .andExpect(jsonPath("$.refreshToken").isNotEmpty())
		    .andExpect(jsonPath("$.age14OrOlderConfirmed").doesNotExist());
		assertThat(users.count()).isEqualTo(previousUsers + 1);
		assertThat(refreshTokens.count()).isEqualTo(previousRefreshTokens + 1);
	}

	@Test
	void malformedConfirmationCannotCreateAccountOrIssueTokens() throws Exception {
		long previousUsers = users.count();
		long previousRefreshTokens = refreshTokens.count();
		var body = Map.of("name", "가입자", "role", "CHILD", "registrationToken",
		    tokens.issueRegistration("age-malformed").value(), "age14OrOlderConfirmed", "not-a-boolean");
		mvc.perform(
		    post("/api/v1/users").contentType(MediaType.APPLICATION_JSON).content(mapper.writeValueAsBytes(body)))
		    .andExpect(status().isBadRequest()).andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
		    .andExpect(jsonPath("$.accessToken").doesNotExist()).andExpect(jsonPath("$.refreshToken").doesNotExist());
		assertThat(users.count()).isEqualTo(previousUsers);
		assertThat(refreshTokens.count()).isEqualTo(previousRefreshTokens);
	}

	private void expectUnconfirmed(ObjectNode body, String reason) throws Exception {
		mvc.perform(
		    post("/api/v1/users").contentType(MediaType.APPLICATION_JSON).content(mapper.writeValueAsBytes(body)))
		    .andExpect(status().isBadRequest()).andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
		    .andExpect(jsonPath("$.fieldErrors[0].field").value("age14OrOlderConfirmed"))
		    .andExpect(jsonPath("$.fieldErrors[0].reason").value(reason))
		    .andExpect(jsonPath("$.accessToken").doesNotExist()).andExpect(jsonPath("$.refreshToken").doesNotExist());
	}
}
