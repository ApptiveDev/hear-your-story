package com.apptive.backend.domain.user.dto;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;

public record CreateUserRequest(@NotBlank @Pattern(regexp = User.NAME_PATTERN) String name, @NotNull Role role,
    @NotBlank @Size(max = 2000) String registrationToken, @NotNull @AssertTrue Boolean age14OrOlderConfirmed) {

	public CreateUserRequest {
		name = name == null ? null : name.trim();
	}
}
