package com.apptive.backend.domain.user.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Clock;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.Collections;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.client.endpoint.OAuth2AccessTokenResponseClient;
import org.springframework.security.oauth2.client.endpoint.OAuth2AuthorizationCodeGrantRequest;
import org.springframework.security.oauth2.client.registration.ClientRegistration;
import org.springframework.security.oauth2.core.OAuth2AccessToken;
import org.springframework.security.oauth2.core.endpoint.OAuth2AccessTokenResponse;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtDecoderFactory;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.util.UriComponentsBuilder;

import com.apptive.backend.domain.user.entity.AccountStatus;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.AccountDeletionTaskRepository;
import com.apptive.backend.domain.user.repository.UserRepository;

@SpringBootTest(properties = {"app.web-deletion.enabled=true", "app.web-deletion.rest-api-key=test-rest-key",
        "app.web-deletion.client-secret=test-client-secret",
        "app.web-deletion.redirect-uri=https://service.example/login/oauth2/code/kakao-deletion"})
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class WebDeletionControllerTest {

	@Autowired
	private MockMvc mvc;
	@Autowired
	private Clock clock;
	@Autowired
	private UserRepository users;
	@Autowired
	private AccountDeletionTaskRepository tasks;
	@MockitoBean(name = "webDeletionTokenClient")
	private OAuth2AccessTokenResponseClient<OAuth2AuthorizationCodeGrantRequest> tokens;
	@MockitoBean(name = "webDeletionIdTokenDecoderFactory")
	private JwtDecoderFactory<ClientRegistration> decoders;

	@Test
	void landingIsPublicButApiRemainsProtected() throws Exception {
		mvc.perform(get("/account-deletion")).andExpect(status().isOk())
		    .andExpect(content().string(containsString("본인 확인")))
		    .andExpect(header().string("Cache-Control", "no-store"))
		    .andExpect(header().string("Referrer-Policy", "no-referrer"));
		mvc.perform(get("/api/v1/users/me").session(session("subject", Duration.ZERO)))
		    .andExpect(status().isUnauthorized());
	}

	@Test
	void oauthUsesFixedCallbackStateNonceAndReauthentication() throws Exception {
		var params = authorization().parameters();
		assertThat(params.getFirst("client_id")).isEqualTo("test-rest-key");
		assertThat(params.getFirst("scope")).isEqualTo("openid");
		assertThat(params.getFirst("redirect_uri"))
		    .isEqualTo("https://service.example/login/oauth2/code/kakao-deletion");
		assertThat(params.getFirst("state")).isNotBlank();
		assertThat(params.getFirst("nonce")).isNotBlank();
		assertThat(params.getFirst("prompt")).isEqualTo("login");
	}

	@Test
	void wrongStateCannotExchangeCode() throws Exception {
		Start start = authorization();
		mvc.perform(get("/login/oauth2/code/kakao-deletion").session(start.session()).param("code", "test-code")
		    .param("state", "wrong-state")).andExpect(redirectedUrl("/account-deletion/error"));
		verify(tokens, never()).getTokenResponse(any());
	}

	@Test
	void callbackKeepsOnlyMinimalIdentityAndDoesNotRegisterOrDelete() throws Exception {
		Start start = authorization();
		stubTokens(start.parameters().getFirst("nonce"));
		MvcResult result = mvc
		    .perform(get("/login/oauth2/code/kakao-deletion").session(start.session()).param("code", "test-code")
		        .param("state", start.parameters().getFirst("state")))
		    .andExpect(redirectedUrl("/account-deletion/confirm")).andReturn();
		MockHttpSession session = (MockHttpSession) result.getRequest().getSession(false);
		var context = (org.springframework.security.core.context.SecurityContext) session
		    .getAttribute(HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY);
		assertThat(context.getAuthentication().getPrincipal()).isInstanceOf(WebDeletionIdentity.class);
		assertThat(context.getAuthentication().getCredentials()).isNull();
		assertThat(Collections.list(session.getAttributeNames())).noneMatch(name -> name.contains("AUTHORIZED_CLIENT"));
		mvc.perform(get("/account-deletion/confirm").session(session)).andExpect(status().isNotFound());
		assertThat(users.findByAuthProviderAndAuthSubject(AuthProvider.KAKAO, "verified-sub")).isEmpty();
	}

	@Test
	void badNonceFailsAndReplayedCallbackFails() throws Exception {
		Start start = authorization();
		stubTokens("wrong-nonce");
		mvc.perform(get("/login/oauth2/code/kakao-deletion").session(start.session()).param("code", "code")
		    .param("state", start.parameters().getFirst("state"))).andExpect(redirectedUrl("/account-deletion/error"));
		mvc.perform(get("/login/oauth2/code/kakao-deletion").param("code", "code").param("state",
		    start.parameters().getFirst("state"))).andExpect(redirectedUrl("/account-deletion/error"));
	}

	@Test
	void parentAndChildCanDeleteOnlyTheVerifiedAccountAfterPreview() throws Exception {
		for (Role role : Role.values()) {
			String subject = "web-" + role;
			User user = users.save(
			    new User("usr_web_" + role, "<가족>", role, AuthProvider.KAKAO, subject, OffsetDateTime.now(clock)));
			User other = users.save(new User("usr_other_" + role, "상대", role, AuthProvider.KAKAO, "other-" + role,
			    OffsetDateTime.now(clock)));
			MockHttpSession session = session(subject, Duration.ZERO);
			mvc.perform(get("/account-deletion/confirm").session(session)).andExpect(status().isOk())
			    .andExpect(content().string(containsString("&lt;가족&gt;")));
			mvc.perform(post("/account-deletion/confirm").session(session).with(csrf())
			    .contentType(MediaType.APPLICATION_FORM_URLENCODED).param("confirm", "yes")
			    .param("userId", other.getId())).andExpect(status().isAccepted())
			    .andExpect(content().string(containsString("모든 외부 삭제가 완료됐다는 의미는 아니에요")));
			assertThat(user.getAccountStatus()).isEqualTo(AccountStatus.DELETION_PENDING);
			assertThat(other.isActive()).isTrue();
			assertThat(session.isInvalid()).isTrue();
		}
		assertThat(tasks.count()).isEqualTo(2);
	}

	@Test
	void oldConfirmationCannotDeleteRejoinedAccountWithSameKakaoIdentity() throws Exception {
		User old = users.save(
		    new User("usr_before_rejoin", "이전", Role.PARENT, AuthProvider.KAKAO, "rejoin", OffsetDateTime.now(clock)));
		MockHttpSession session = session("rejoin", Duration.ZERO);
		mvc.perform(get("/account-deletion/confirm").session(session)).andExpect(status().isOk());
		old.requestDeletion(OffsetDateTime.now(clock));
		users.flush();
		User rejoined = users.save(
		    new User("usr_after_rejoin", "새계정", Role.PARENT, AuthProvider.KAKAO, "rejoin", OffsetDateTime.now(clock)));
		mvc.perform(post("/account-deletion/confirm").session(session).with(csrf())
		    .contentType(MediaType.APPLICATION_FORM_URLENCODED).param("confirm", "yes"))
		    .andExpect(status().isUnauthorized());
		assertThat(rejoined.isActive()).isTrue();
		assertThat(tasks.count()).isZero();
	}

	@Test
	void csrfConsentPreviewAndExpiryAreRequired() throws Exception {
		users
		    .save(new User("usr_guard_web", "이름", Role.PARENT, AuthProvider.KAKAO, "guard", OffsetDateTime.now(clock)));
		MockHttpSession session = session("guard", Duration.ZERO);
		mvc.perform(post("/account-deletion/confirm").session(session).param("confirm", "yes"))
		    .andExpect(status().isForbidden()).andExpect(content().string(containsString("다시 본인 확인")));
		mvc.perform(post("/account-deletion/confirm").session(session).with(csrf())
		    .contentType(MediaType.APPLICATION_FORM_URLENCODED).param("confirm", "yes"))
		    .andExpect(status().isUnauthorized());
		mvc.perform(get("/account-deletion/confirm").session(session)).andExpect(status().isOk());
		mvc.perform(post("/account-deletion/confirm").session(session).with(csrf())
		    .contentType(MediaType.APPLICATION_FORM_URLENCODED)).andExpect(status().isBadRequest());
		mvc.perform(get("/account-deletion/confirm").session(session("guard", Duration.ofMinutes(10))))
		    .andExpect(status().isUnauthorized());
		assertThat(users.findById("usr_guard_web").orElseThrow().isActive()).isTrue();
	}

	@Test
	void cancelDoesNotDeleteAndPendingUserGetsHonestStatus() throws Exception {
		User user = users.save(
		    new User("usr_cancel_web", "이름", Role.CHILD, AuthProvider.KAKAO, "cancel", OffsetDateTime.now(clock)));
		MockHttpSession session = session("cancel", Duration.ZERO);
		mvc.perform(post("/account-deletion/cancel").session(session).with(csrf())).andExpect(status().isOk());
		assertThat(user.isActive()).isTrue();
		session = session("cancel", Duration.ZERO);
		mvc.perform(get("/account-deletion/confirm").session(session));
		mvc.perform(post("/account-deletion/confirm").session(session).with(csrf())
		    .contentType(MediaType.APPLICATION_FORM_URLENCODED).param("confirm", "yes"))
		    .andExpect(status().isAccepted());
		mvc.perform(get("/account-deletion/confirm").session(session("cancel", Duration.ZERO)))
		    .andExpect(status().isConflict());
	}

	private MockHttpSession session(String subject, Duration age) {
		MockHttpSession session = new MockHttpSession();
		var context = SecurityContextHolder.createEmptyContext();
		context.setAuthentication(UsernamePasswordAuthenticationToken
		    .authenticated(new WebDeletionIdentity(subject, clock.instant().minus(age)), null, List.of()));
		session.setAttribute(HttpSessionSecurityContextRepository.SPRING_SECURITY_CONTEXT_KEY, context);
		return session;
	}

	private Start authorization() throws Exception {
		MvcResult result = mvc.perform(get("/oauth2/authorization/kakao-deletion"))
		    .andExpect(status().is3xxRedirection()).andReturn();
		var parameters = new org.springframework.util.LinkedMultiValueMap<String, String>();
		UriComponentsBuilder.fromUriString(result.getResponse().getRedirectedUrl()).build().getQueryParams()
		    .forEach((key, values) -> values.forEach(value -> parameters.add(key,
		        org.springframework.web.util.UriUtils.decode(value, java.nio.charset.StandardCharsets.UTF_8))));
		return new Start((MockHttpSession) result.getRequest().getSession(false), parameters);
	}

	private void stubTokens(String nonce) {
		when(tokens.getTokenResponse(any())).thenReturn(OAuth2AccessTokenResponse.withToken("test-access")
		    .tokenType(OAuth2AccessToken.TokenType.BEARER).expiresIn(600).scopes(java.util.Set.of("openid"))
		    .additionalParameters(Map.of("id_token", "test-id-token")).build());
		JwtDecoder decoder = mock(JwtDecoder.class);
		when(decoders.createDecoder(any())).thenReturn(decoder);
		when(decoder.decode("test-id-token")).thenReturn(Jwt.withTokenValue("test-id-token").header("alg", "RS256")
		    .issuer("https://kauth.kakao.com").subject("verified-sub").audience(List.of("test-rest-key"))
		    .issuedAt(clock.instant()).expiresAt(clock.instant().plusSeconds(600)).claim("nonce", nonce).build());
	}

	private record Start(MockHttpSession session, org.springframework.util.MultiValueMap<String, String> parameters) {
	}
}
