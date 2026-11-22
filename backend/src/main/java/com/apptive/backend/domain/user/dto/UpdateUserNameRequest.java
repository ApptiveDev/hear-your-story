package com.apptive.backend.domain.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

import com.apptive.backend.domain.user.entity.User;

public record UpdateUserNameRequest(@NotBlank @Pattern(regexp = User.NAME_PATTERN) String name) {

	public UpdateUserNameRequest {
		name = name == null ? null : name.trim();
	}
}
