package com.apptive.backend.common.auth;

import java.io.IOException;
import java.util.List;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import com.apptive.backend.common.exception.ApiErrorFactory;
import com.apptive.backend.common.exception.ErrorCode;
import com.fasterxml.jackson.databind.ObjectMapper;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Component
public class RestAuthenticationEntryPoint implements AuthenticationEntryPoint {

	private final ApiErrorFactory apiErrorFactory;
	private final ObjectMapper objectMapper;

	@Override
	public void commence(HttpServletRequest request, HttpServletResponse response,
	    AuthenticationException authException) throws IOException {
		ErrorCode errorCode = request.getAttribute(
		    JwtAuthenticationFilter.AUTH_ERROR_ATTRIBUTE) instanceof ErrorCode code ? code : ErrorCode.UNAUTHORIZED;
		response.setStatus(errorCode.status().value());
		response.setContentType(MediaType.APPLICATION_JSON_VALUE);
		response.setCharacterEncoding("UTF-8");
		objectMapper.writeValue(response.getOutputStream(),
		    apiErrorFactory.create(request, errorCode, errorCode.message(), List.of()));
	}
}
