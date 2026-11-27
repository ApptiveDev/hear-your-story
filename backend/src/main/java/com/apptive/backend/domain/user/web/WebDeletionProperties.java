package com.apptive.backend.domain.user.web;

import java.net.URI;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("app.web-deletion")
public record WebDeletionProperties(boolean enabled, String restApiKey, String clientSecret, String redirectUri) {

	@Override
	public String toString() {
		return "WebDeletionProperties[redacted]";
	}

	public void validateEnabled() {
		if (restApiKey == null || restApiKey.isBlank() || clientSecret == null || clientSecret.isBlank()) {
			throw new IllegalStateException("웹 탈퇴에 카카오 REST API 키와 클라이언트 시크릿이 필요합니다.");
		}
		URI uri = URI.create(redirectUri == null ? "" : redirectUri);
		if (!"https".equals(uri.getScheme()) || uri.getHost() == null || uri.getUserInfo() != null
		    || uri.getQuery() != null || uri.getFragment() != null
		    || !"/login/oauth2/code/kakao-deletion".equals(uri.getPath())) {
			throw new IllegalStateException("웹 탈퇴 redirect URI는 고정된 HTTPS 콜백 주소여야 합니다.");
		}
	}
}
