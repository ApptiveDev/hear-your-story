package com.apptive.backend.domain.user.controller;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.apptive.backend.domain.user.dto.CreateUserRequest;
import com.apptive.backend.domain.user.dto.CreateUserResponse;
import com.apptive.backend.domain.user.service.UserRegistrationResult;
import com.apptive.backend.domain.user.service.UserService;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/users")
public class UserController {

	private final UserService userService;

	@PostMapping
	public ResponseEntity<CreateUserResponse> register(@Valid @RequestBody CreateUserRequest request) {
		UserRegistrationResult result = userService.register(request);
		HttpStatus status = result.created() ? HttpStatus.CREATED : HttpStatus.OK;
		return ResponseEntity.status(status).body(result.response());
	}
}
