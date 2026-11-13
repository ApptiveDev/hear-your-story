package com.apptive.backend.domain.auth.service;

import java.time.OffsetDateTime;

public record IssuedRefreshToken(String value, OffsetDateTime expiresAt) {
}
