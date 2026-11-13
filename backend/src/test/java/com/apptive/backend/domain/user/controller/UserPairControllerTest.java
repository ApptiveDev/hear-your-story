package com.apptive.backend.domain.user.controller;

import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.matchesPattern;
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
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.domain.assignment.repository.AssignmentRepository;
import com.apptive.backend.domain.auth.repository.RefreshTokenRepository;
import com.apptive.backend.domain.pair.entity.PairInvitation;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.pair.repository.PairInvitationRepository;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class UserPairControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private ObjectMapper objectMapper;

	@Autowired
	private AssignmentRepository assignmentRepository;

	@Autowired
	private PairInvitationRepository invitationRepository;

	@Autowired
	private FamilyPairRepository familyPairRepository;

	@Autowired
	private UserRepository userRepository;

	@Autowired
	private RefreshTokenRepository refreshTokenRepository;

	@Autowired
	private JwtTokenProvider jwtTokenProvider;

	@Autowired
	private Clock clock;

	@BeforeEach
	void cleanDatabase() {
		assignmentRepository.deleteAll();
		invitationRepository.deleteAll();
		familyPairRepository.deleteAll();
		refreshTokenRepository.deleteAll();
		userRepository.deleteAll();
	}

	@Test
	void registrationCreatesUserAndReusedTokenIsRejected() throws Exception {
		String registrationToken = registrationToken("parent-subject-1");
		registerWithToken("김영희", "PARENT", registrationToken, 201);

		registerWithToken("다른 이름", "PARENT", registrationToken, 409);

		org.assertj.core.api.Assertions.assertThat(userRepository.count()).isEqualTo(1);
	}

	@Test
	void invalidRegistrationReturnsFieldErrorsInCommonFormat() throws Exception {
		mockMvc.perform(post("/api/v1/users").contentType(MediaType.APPLICATION_JSON).content("""
		    {"name":" ","role":"PARENT","registrationToken":""}
		    """)).andExpect(status().isBadRequest()).andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
		    .andExpect(jsonPath("$.fieldErrors[?(@.field == 'name')]").exists())
		    .andExpect(jsonPath("$.fieldErrors[?(@.field == 'registrationToken')]").exists());
	}

	@Test
	void malformedRegistrationTokenIsRejected() throws Exception {
		registerWithToken("김영희", "PARENT", "malformed-token", 401);
	}

	@Test
	void childCreatesInvitationAndParentJoins() throws Exception {
		String childToken = token(register("김민지", "CHILD", "child-device-1", 201));
		String parentToken = token(register("김영희", "PARENT", "parent-device-1", 201));

		MvcResult invitationResult = mockMvc
		    .perform(post("/api/v1/pairs/invitations").header("Authorization", bearer(childToken)))
		    .andExpect(status().isCreated()).andExpect(jsonPath("$.invitationId").isNotEmpty())
		    .andExpect(jsonPath("$.inviteCode").value(matchesPattern("^\\d{6}$")))
		    .andExpect(jsonPath("$.expiresAt").isNotEmpty()).andReturn();
		String inviteCode = body(invitationResult).get("inviteCode").asText();

		mockMvc
		    .perform(post("/api/v1/pairs/join").header("Authorization", bearer(parentToken))
		        .contentType(MediaType.APPLICATION_JSON)
		        .content(objectMapper.writeValueAsString(new InviteCodeBody(inviteCode))))
		    .andExpect(status().isCreated()).andExpect(jsonPath("$.pair.id").isNotEmpty())
		    .andExpect(jsonPath("$.pair.parent.name").value("김영희"))
		    .andExpect(jsonPath("$.pair.child.name").value("김민지")).andExpect(jsonPath("$.pair.pairedAt").isNotEmpty());

		org.assertj.core.api.Assertions.assertThat(familyPairRepository.count()).isEqualTo(1);
		org.assertj.core.api.Assertions.assertThat(invitationRepository.findAll().get(0).getUsedAt()).isNotNull();
	}

	@Test
	void protectedPairApiRequiresTokenAndCorrectRole() throws Exception {
		mockMvc.perform(post("/api/v1/pairs/invitations")).andExpect(status().isUnauthorized())
		    .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED")).andExpect(jsonPath("$.fieldErrors", empty()));

		String parentToken = token(register("김영희", "PARENT", "parent-device-1", 201));
		mockMvc.perform(post("/api/v1/pairs/invitations").header("Authorization", bearer(parentToken)))
		    .andExpect(status().isForbidden()).andExpect(jsonPath("$.errorCode").value("ROLE_NOT_ALLOWED"));
	}

	@Test
	void usedInvitationCannotBeJoinedAgain() throws Exception {
		String childToken = token(register("자녀", "CHILD", "child-device-1", 201));
		String firstParentToken = token(register("부모1", "PARENT", "parent-device-1", 201));
		String secondParentToken = token(register("부모2", "PARENT", "parent-device-2", 201));
		String inviteCode = createInvitation(childToken);

		join(firstParentToken, inviteCode).andExpect(status().isCreated());
		join(secondParentToken, inviteCode).andExpect(status().isConflict())
		    .andExpect(jsonPath("$.errorCode").value("INVITE_CODE_USED"));
	}

	@Test
	void expiredInvitationCannotBeJoined() throws Exception {
		register("자녀", "CHILD", "child-device-1", 201);
		String parentToken = token(register("부모", "PARENT", "parent-device-1", 201));
		User child = userRepository.findByAuthProviderAndAuthSubject(AuthProvider.KAKAO, "child-device-1")
		    .orElseThrow();
		OffsetDateTime now = OffsetDateTime.now(clock);
		invitationRepository
		    .save(new PairInvitation("inv_expired_test", child, "123456", now.minusMinutes(1), now.minusDays(1)));

		join(parentToken, "123456").andExpect(status().isConflict())
		    .andExpect(jsonPath("$.errorCode").value("INVITE_CODE_EXPIRED"));
	}

	@Test
	void malformedTokenReturnsUnauthorized() throws Exception {
		mockMvc.perform(post("/api/v1/pairs/invitations").header("Authorization", "Bearer malformed-token"))
		    .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));
	}

	@Test
	void publicRegistrationIgnoresStaleAuthorizationHeader() throws Exception {
		String registrationToken = registrationToken("parent-subject-1");
		mockMvc
		    .perform(post("/api/v1/users").header("Authorization", "Bearer stale-token")
		        .contentType(MediaType.APPLICATION_JSON)
		        .content(objectMapper.writeValueAsString(new RegisterBody("김영희", "PARENT", registrationToken))))
		    .andExpect(status().isCreated()).andExpect(jsonPath("$.user.role").value("PARENT"));
	}

	private MvcResult register(String name, String role, String authSubject, int expectedStatus) throws Exception {
		return registerWithToken(name, role, registrationToken(authSubject), expectedStatus);
	}

	private MvcResult registerWithToken(String name, String role, String registrationToken, int expectedStatus)
	    throws Exception {
		org.springframework.test.web.servlet.ResultActions result = mockMvc
		    .perform(post("/api/v1/users").contentType(MediaType.APPLICATION_JSON)
		        .content(objectMapper.writeValueAsString(new RegisterBody(name, role, registrationToken))))
		    .andExpect(status().is(expectedStatus));
		if (expectedStatus == 201) {
			result.andExpect(jsonPath("$.authStatus").value("AUTHENTICATED"))
			    .andExpect(jsonPath("$.user.pairingStatus").value("UNPAIRED"))
			    .andExpect(jsonPath("$.tokenType").value("Bearer")).andExpect(jsonPath("$.accessToken").isNotEmpty())
			    .andExpect(jsonPath("$.refreshToken").isNotEmpty());
		} else if (expectedStatus == 401) {
			result.andExpect(jsonPath("$.errorCode").value("REGISTRATION_TOKEN_INVALID"));
		} else if (expectedStatus == 409) {
			result.andExpect(jsonPath("$.errorCode").value("KAKAO_ACCOUNT_ALREADY_REGISTERED"));
		}
		return result.andReturn();
	}

	private String registrationToken(String authSubject) {
		return jwtTokenProvider.issueRegistration(authSubject).value();
	}

	private String createInvitation(String childToken) throws Exception {
		MvcResult result = mockMvc
		    .perform(post("/api/v1/pairs/invitations").header("Authorization", bearer(childToken)))
		    .andExpect(status().isCreated()).andReturn();
		return body(result).get("inviteCode").asText();
	}

	private org.springframework.test.web.servlet.ResultActions join(String parentToken, String inviteCode)
	    throws Exception {
		return mockMvc.perform(post("/api/v1/pairs/join").header("Authorization", bearer(parentToken))
		    .contentType(MediaType.APPLICATION_JSON)
		    .content(objectMapper.writeValueAsString(new InviteCodeBody(inviteCode))));
	}

	private JsonNode body(MvcResult result) throws Exception {
		return objectMapper.readTree(result.getResponse().getContentAsByteArray());
	}

	private String token(MvcResult result) throws Exception {
		return body(result).get("accessToken").asText();
	}

	private String bearer(String token) {
		return "Bearer " + token;
	}

	private record RegisterBody(String name, String role, String registrationToken) {
	}

	private record InviteCodeBody(String inviteCode) {
	}
}
