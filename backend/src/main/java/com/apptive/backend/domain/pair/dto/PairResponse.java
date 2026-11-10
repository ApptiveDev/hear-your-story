package com.apptive.backend.domain.pair.dto;

import java.time.OffsetDateTime;

public record PairResponse(String id, PairMemberResponse parent, PairMemberResponse child, OffsetDateTime pairedAt) {
}
