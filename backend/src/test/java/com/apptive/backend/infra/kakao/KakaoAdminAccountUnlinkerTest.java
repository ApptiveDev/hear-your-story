package com.apptive.backend.infra.kakao;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.content;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withBadRequest;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

class KakaoAdminAccountUnlinkerTest {

	@Test
	void unlinksKakaoAccountWithAdminKeyAndSubject() {
		RestClient.Builder builder = RestClient.builder().baseUrl("https://kapi.kakao.com")
		    .defaultHeader(HttpHeaders.AUTHORIZATION, "KakaoAK test-admin-key");
		MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
		KakaoAuthProperties properties = new KakaoAuthProperties("native-key", "test-admin-key",
		    "https://kauth.kakao.com", "https://kauth.kakao.com/.well-known/jwks.json");
		KakaoAdminAccountUnlinker unlinker = new KakaoAdminAccountUnlinker(builder.build(), properties);

		server.expect(requestTo("https://kapi.kakao.com/v1/user/unlink")).andExpect(method(HttpMethod.POST))
		    .andExpect(header(HttpHeaders.AUTHORIZATION, "KakaoAK test-admin-key"))
		    .andExpect(content().contentType(MediaType.APPLICATION_FORM_URLENCODED))
		    .andExpect(content().string("target_id_type=user_id&target_id=123456789")).andRespond(withSuccess());

		unlinker.unlink("123456789");

		server.verify();
	}

	@Test
	void rejectsUnlinkWhenAdminKeyIsMissing() {
		KakaoAuthProperties properties = new KakaoAuthProperties("native-key", "", "https://kauth.kakao.com",
		    "https://kauth.kakao.com/.well-known/jwks.json");
		KakaoAdminAccountUnlinker unlinker = new KakaoAdminAccountUnlinker(RestClient.create(), properties);

		assertThatThrownBy(() -> unlinker.unlink("123456789")).isInstanceOf(IllegalStateException.class)
		    .hasMessageContaining("KAKAO_ADMIN_KEY");
	}

	@Test
	void treatsAlreadyUnlinkedKakaoAccountAsSuccess() {
		RestClient.Builder builder = RestClient.builder().baseUrl("https://kapi.kakao.com")
		    .defaultHeader(HttpHeaders.AUTHORIZATION, "KakaoAK test-admin-key");
		MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
		KakaoAuthProperties properties = new KakaoAuthProperties("native-key", "test-admin-key",
		    "https://kauth.kakao.com", "https://kauth.kakao.com/.well-known/jwks.json");
		KakaoAdminAccountUnlinker unlinker = new KakaoAdminAccountUnlinker(builder.build(), properties);
		server.expect(requestTo("https://kapi.kakao.com/v1/user/unlink")).andRespond(withBadRequest()
		    .contentType(MediaType.APPLICATION_JSON).body("{\"code\":-101,\"msg\":\"NotRegisteredUserException\"}"));

		unlinker.unlink("123456789");

		server.verify();
	}
}
