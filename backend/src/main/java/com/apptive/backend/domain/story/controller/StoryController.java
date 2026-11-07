package com.apptive.backend.domain.story.controller;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.domain.story.dto.StoryPageResponse;
import com.apptive.backend.domain.story.service.StoryService;

@RestController
@RequestMapping("/api/v1/stories")
public class StoryController {

	private final StoryService storyService;

	public StoryController(StoryService storyService) {
		this.storyService = storyService;
	}

	@GetMapping
	public StoryPageResponse getStories(
		@RequestParam(required = false) String month,
		@RequestParam(required = false) String cursor,
		@RequestParam(required = false) Integer limit,
		@AuthenticationPrincipal AuthenticatedUser authenticatedUser
	) {
		return storyService.getStories(month, cursor, limit, authenticatedUser);
	}
}
