package com.apptive.backend.domain.recording.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.domain.recording.dto.RecordingUploadResponse;
import com.apptive.backend.domain.recording.service.RecordingUploadService;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/assignments")
public class RecordingController {

	private final RecordingUploadService recordingUploadService;

	@PutMapping(path = "/{assignmentId}/parent-recording", consumes = "multipart/form-data")
	public ResponseEntity<RecordingUploadResponse> put(@PathVariable String assignmentId,
	    @RequestPart("audioFile") MultipartFile audioFile,
	    @RequestHeader(name = "Idempotency-Key", required = false) String idempotencyKey,
	    @AuthenticationPrincipal AuthenticatedUser authenticatedUser) {
		return ResponseEntity.accepted()
		    .body(recordingUploadService.put(assignmentId, audioFile, idempotencyKey, authenticatedUser));
	}
}
