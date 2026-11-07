package com.apptive.backend.domain.pair.controller;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.domain.pair.dto.InvitationResponse;
import com.apptive.backend.domain.pair.dto.JoinPairRequest;
import com.apptive.backend.domain.pair.dto.JoinPairResponse;
import com.apptive.backend.domain.pair.service.PairService;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/pairs")
public class PairController {

	private final PairService pairService;

	@PostMapping("/invitations")
	public ResponseEntity<InvitationResponse> createInvitation(
	    @AuthenticationPrincipal AuthenticatedUser authenticatedUser) {
		return ResponseEntity.status(HttpStatus.CREATED).body(pairService.createInvitation(authenticatedUser));
	}

	@PostMapping("/join")
	public ResponseEntity<JoinPairResponse> join(@AuthenticationPrincipal AuthenticatedUser authenticatedUser,
	    @Valid @RequestBody JoinPairRequest request) {
		return ResponseEntity.status(HttpStatus.CREATED)
		    .body(pairService.join(authenticatedUser, request.inviteCode()));
	}
}
