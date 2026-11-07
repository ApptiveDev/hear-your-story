package com.apptive.backend.common.exception;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.List;

import jakarta.servlet.http.HttpServletRequest;

import org.springframework.stereotype.Component;

import com.apptive.backend.common.web.TraceIdFilter;

@Component
public class ApiErrorFactory {

	private final Clock clock;

	public ApiErrorFactory(Clock clock) {
		this.clock = clock;
	}

	public ApiErrorResponse create(HttpServletRequest request, ErrorCode errorCode, String message,
	    List<FieldErrorResponse> fieldErrors) {
		return new ApiErrorResponse(OffsetDateTime.now(clock), errorCode.status().value(), errorCode.name(), message,
		    request.getRequestURI(), TraceIdFilter.getTraceId(request), List.copyOf(fieldErrors));
	}
}
