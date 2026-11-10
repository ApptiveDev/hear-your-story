package com.apptive.backend.domain.recording.controller;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.domain.recording.dto.RecordingStatusResponse;
import com.apptive.backend.domain.recording.service.RecordingStatusService;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/recordings")
public class RecordingStatusController {

	private final RecordingStatusService recordingStatusService;

	@GetMapping("/{recordingId}")
	public RecordingStatusResponse get(@PathVariable String recordingId,
	    @AuthenticationPrincipal AuthenticatedUser authenticatedUser) {
		return recordingStatusService.get(recordingId, authenticatedUser);
	}
}
