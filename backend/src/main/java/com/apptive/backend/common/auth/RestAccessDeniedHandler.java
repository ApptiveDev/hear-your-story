package com.apptive.backend.common.auth;

import java.io.IOException;
import java.util.List;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import com.apptive.backend.common.exception.ApiErrorFactory;
import com.apptive.backend.common.exception.ErrorCode;
import com.fasterxml.jackson.databind.ObjectMapper;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Component
public class RestAccessDeniedHandler implements AccessDeniedHandler {

	private final ApiErrorFactory apiErrorFactory;
	private final ObjectMapper objectMapper;

	@Override
	public void handle(HttpServletRequest request, HttpServletResponse response,
	    AccessDeniedException accessDeniedException) throws IOException {
		response.setStatus(ErrorCode.ROLE_NOT_ALLOWED.status().value());
		response.setContentType(MediaType.APPLICATION_JSON_VALUE);
		response.setCharacterEncoding("UTF-8");
		objectMapper.writeValue(response.getOutputStream(), apiErrorFactory.create(request, ErrorCode.ROLE_NOT_ALLOWED,
		    ErrorCode.ROLE_NOT_ALLOWED.message(), List.of()));
	}
}
