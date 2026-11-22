package com.apptive.backend.domain.user.controller;

import static org.hamcrest.Matchers.empty;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Clock;
import java.time.OffsetDateTime;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class UserNameControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private UserRepository userRepository;

	@Autowired
	private JwtTokenProvider jwtTokenProvider;

	@Autowired
	private Clock clock;

	@Test
	void authenticatedUserUpdatesOwnName() throws Exception {
		User user = saveUser("usr_name_update", "기존 이름", Role.PARENT);

		mockMvc
		    .perform(patch("/api/v1/users/me").header("Authorization", bearer(user))
		        .contentType(MediaType.APPLICATION_JSON).content("""
		            {"name":"  새 이름  "}
		            """))
		    .andExpect(status().isOk()).andExpect(jsonPath("$.id").value(user.getId()))
		    .andExpect(jsonPath("$.name").value("새 이름")).andExpect(jsonPath("$.role").value("PARENT"))
		    .andExpect(jsonPath("$.pairingStatus").value("UNPAIRED"));

		org.assertj.core.api.Assertions.assertThat(userRepository.findById(user.getId()).orElseThrow().getName())
		    .isEqualTo("새 이름");
	}

	@Test
	void sameNameUpdateIsIdempotent() throws Exception {
		User user = saveUser("usr_same_name", "같은 이름", Role.CHILD);

		mockMvc.perform(patch("/api/v1/users/me").header("Authorization", bearer(user))
		    .contentType(MediaType.APPLICATION_JSON).content("""
		        {"name":"같은 이름"}
		        """)).andExpect(status().isOk()).andExpect(jsonPath("$.name").value("같은 이름"));
	}

	@Test
	void invalidNameReturnsValidationErrorWithoutChangingUser() throws Exception {
		User user = saveUser("usr_invalid_name", "기존 이름", Role.PARENT);

		mockMvc
		    .perform(patch("/api/v1/users/me").header("Authorization", bearer(user))
		        .contentType(MediaType.APPLICATION_JSON).content("""
		            {"name":"열한글자이름입니다요오"}
		            """))
		    .andExpect(status().isBadRequest()).andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
		    .andExpect(jsonPath("$.fieldErrors[?(@.field == 'name')]").exists());

		org.assertj.core.api.Assertions.assertThat(userRepository.findById(user.getId()).orElseThrow().getName())
		    .isEqualTo("기존 이름");
	}

	@Test
	void blankNameReturnsValidationError() throws Exception {
		User user = saveUser("usr_blank_name", "기존 이름", Role.PARENT);

		mockMvc
		    .perform(patch("/api/v1/users/me").header("Authorization", bearer(user))
		        .contentType(MediaType.APPLICATION_JSON).content("""
		            {"name":"   "}
		            """))
		    .andExpect(status().isBadRequest()).andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
		    .andExpect(jsonPath("$.fieldErrors[?(@.field == 'name')]").exists());
	}

	@Test
	void nameUpdateRequiresAuthentication() throws Exception {
		mockMvc.perform(patch("/api/v1/users/me").contentType(MediaType.APPLICATION_JSON).content("""
		    {"name":"새 이름"}
		    """)).andExpect(status().isUnauthorized()).andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"))
		    .andExpect(jsonPath("$.fieldErrors", empty()));
	}

	private User saveUser(String id, String name, Role role) {
		return userRepository
		    .save(new User(id, name, role, AuthProvider.KAKAO, id + "-subject", OffsetDateTime.now(clock)));
	}

	private String bearer(User user) {
		return "Bearer " + jwtTokenProvider.issue(user.getId(), user.getRole()).value();
	}
}
