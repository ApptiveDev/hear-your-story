package com.apptive.backend.common.auth;

import java.time.OffsetDateTime;

public record IssuedRegistrationToken(String value, OffsetDateTime expiresAt) {
}
