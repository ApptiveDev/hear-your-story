package com.apptive.backend.domain.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import com.apptive.backend.domain.user.entity.Role;

public record CreateUserRequest(@NotBlank @Size(max = 50) String name, @NotNull Role role,
    @NotBlank @Size(max = 2000) String registrationToken) {
}
