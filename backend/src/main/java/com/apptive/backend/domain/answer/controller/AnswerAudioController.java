package com.apptive.backend.domain.answer.controller;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.domain.answer.dto.AnswerAudioResponse;
import com.apptive.backend.domain.answer.service.AnswerAudioService;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/answers")
public class AnswerAudioController {

	private final AnswerAudioService answerAudioService;

	@GetMapping("/{answerId}/audio")
	public AnswerAudioResponse get(@PathVariable String answerId,
	    @AuthenticationPrincipal AuthenticatedUser authenticatedUser) {
		return answerAudioService.get(answerId, authenticatedUser);
	}
}
