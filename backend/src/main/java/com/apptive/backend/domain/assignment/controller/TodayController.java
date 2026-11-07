package com.apptive.backend.domain.assignment.controller;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.domain.assignment.dto.TodayResponse;
import com.apptive.backend.domain.assignment.service.TodayService;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/today")
public class TodayController {

	private final TodayService todayService;

	@GetMapping
	public TodayResponse getToday(@AuthenticationPrincipal AuthenticatedUser authenticatedUser) {
		return todayService.getToday(authenticatedUser);
	}
}
