package com.apptive.backend.infra.kakao;

import java.util.regex.Pattern;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;

import com.apptive.backend.domain.user.service.KakaoAccountUnlinker;

@Component
public class KakaoAdminAccountUnlinker implements KakaoAccountUnlinker {

	private static final Pattern ALREADY_UNLINKED = Pattern.compile("\\\"code\\\"\\s*:\\s*-101");

	private final RestClient restClient;
	private final KakaoAuthProperties properties;

	public KakaoAdminAccountUnlinker(@Qualifier("kakaoAdminRestClient") RestClient kakaoAdminRestClient,
	    KakaoAuthProperties properties) {
		this.restClient = kakaoAdminRestClient;
		this.properties = properties;
	}

	@Override
	public void unlink(String authSubject) {
		if (properties.adminKey() == null || properties.adminKey().isBlank()) {
			throw new IllegalStateException("KAKAO_ADMIN_KEY is required to complete account deletion");
		}
		MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
		form.add("target_id_type", "user_id");
		form.add("target_id", authSubject);
		try {
			restClient.post().uri("/v1/user/unlink").contentType(MediaType.APPLICATION_FORM_URLENCODED).body(form)
			    .retrieve().toBodilessEntity();
		} catch (HttpClientErrorException.BadRequest exception) {
			if (!ALREADY_UNLINKED.matcher(exception.getResponseBodyAsString()).find()) {
				throw exception;
			}
		}
	}
}
