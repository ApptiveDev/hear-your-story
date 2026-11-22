package com.apptive.backend.domain.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import com.apptive.backend.domain.user.entity.User;

public record UpdateUserNameRequest(@NotBlank @Size(max = User.MAX_NAME_LENGTH) String name) {

	public UpdateUserNameRequest {
		name = name == null ? null : name.trim();
	}
}
