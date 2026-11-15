package com.apptive.backend.common.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import com.apptive.backend.domain.user.entity.Role;

@SpringBootTest
@ActiveProfiles("test")
class JwtTokenProviderTest {

	@Autowired
	private JwtTokenProvider tokenProvider;

	@Test
	void issuedTokenCanBeParsed() {
		IssuedToken issuedToken = tokenProvider.issue("usr_test", Role.CHILD);

		AuthenticatedUser authenticatedUser = tokenProvider.parse(issuedToken.value());

		assertThat(authenticatedUser.userId()).isEqualTo("usr_test");
		assertThat(authenticatedUser.role()).isEqualTo(Role.CHILD);
	}

	@Test
	void registrationTokenCannotAuthenticateProtectedApi() {
		IssuedRegistrationToken registrationToken = tokenProvider.issueRegistration("kakao-subject");

		assertThat(tokenProvider.parseRegistration(registrationToken.value())).isEqualTo("kakao-subject");
		assertThatThrownBy(() -> tokenProvider.parse(registrationToken.value()))
		    .isInstanceOf(IllegalArgumentException.class);
	}
}
