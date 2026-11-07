package com.apptive.backend.domain.answer.controller;

import jakarta.validation.Valid;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.domain.answer.dto.ChildAnswerResponse;
import com.apptive.backend.domain.answer.dto.PutChildAnswerRequest;
import com.apptive.backend.domain.answer.service.ChildAnswerService;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/assignments")
public class ChildAnswerController {

	private final ChildAnswerService childAnswerService;

	@PutMapping("/{assignmentId}/child-answer")
	public ChildAnswerResponse put(@PathVariable String assignmentId, @Valid @RequestBody PutChildAnswerRequest request,
	    @AuthenticationPrincipal AuthenticatedUser authenticatedUser) {
		return childAnswerService.put(assignmentId, request.text(), authenticatedUser);
	}
}
