package com.apptive.backend.domain.user.web;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class WebDeletionPropertiesTest {

	@Test
	void acceptsOnlyFixedHttpsCallbackWithServerCredentials() {
		assertThatCode(() -> new WebDeletionProperties(true, "test-key", "test-secret",
		    "https://service.example/login/oauth2/code/kakao-deletion").validateEnabled()).doesNotThrowAnyException();
		for (String uri : new String[]{"http://service.example/login/oauth2/code/kakao-deletion",
		        "https://service.example/elsewhere", "https://user@service.example/login/oauth2/code/kakao-deletion",
		        "https://service.example/login/oauth2/code/kakao-deletion?next=evil", ""}) {
			assertThatThrownBy(() -> new WebDeletionProperties(true, "test-key", "test-secret", uri).validateEnabled())
			    .isInstanceOf(IllegalStateException.class);
		}
		assertThatThrownBy(() -> new WebDeletionProperties(true, "", "", "").validateEnabled())
		    .isInstanceOf(IllegalStateException.class);
	}
}
