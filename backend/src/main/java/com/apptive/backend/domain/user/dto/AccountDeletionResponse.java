package com.apptive.backend.domain.user.dto;

import java.time.OffsetDateTime;

public record AccountDeletionResponse(String deletionRequestId, String status, OffsetDateTime requestedAt) {
}
