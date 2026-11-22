package com.apptive.backend.domain.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;

public record CreateUserRequest(@NotBlank @Size(max = User.MAX_NAME_LENGTH) String name, @NotNull Role role,
    @NotBlank @Size(max = 2000) String registrationToken) {
}
