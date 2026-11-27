package com.apptive.backend.domain.user.web;

import java.io.Serializable;
import java.time.Instant;

// 검증된 sub와 확인 시각만 짧게 보관한다. OAuth 토큰·프로필을 세션에 보관하지 않는다.
public record WebDeletionIdentity(String subject, Instant verifiedAt) implements Serializable {

	@Override
	public String toString() {
		return "WebDeletionIdentity[redacted]";
	}
}
