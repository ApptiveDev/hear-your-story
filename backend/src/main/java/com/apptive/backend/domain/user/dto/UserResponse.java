package com.apptive.backend.domain.user.dto;

import com.apptive.backend.domain.user.entity.Role;

public record UserResponse(String id, String name, Role role, String pairingStatus, String partnerName) {
}
