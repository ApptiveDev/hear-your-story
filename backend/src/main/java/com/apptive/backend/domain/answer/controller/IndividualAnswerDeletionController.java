package com.apptive.backend.domain.answer.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.domain.answer.service.IndividualAnswerDeletionService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class IndividualAnswerDeletionController {
	private final IndividualAnswerDeletionService service;

	@DeleteMapping("/recordings/{recordingId}")
	public ResponseEntity<Void> deleteRecording(@PathVariable String recordingId,
	    @AuthenticationPrincipal AuthenticatedUser user) {
		service.deleteRecording(recordingId, user);
		return ResponseEntity.noContent().build();
	}

	@DeleteMapping("/answers/{answerId}")
	public ResponseEntity<Void> deleteAnswer(@PathVariable String answerId,
	    @AuthenticationPrincipal AuthenticatedUser user) {
		service.deleteAnswer(answerId, user);
		return ResponseEntity.noContent().build();
	}
}
