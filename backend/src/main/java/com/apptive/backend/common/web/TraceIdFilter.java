package com.apptive.backend.common.web;

import java.io.IOException;
import java.util.UUID;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.web.filter.OncePerRequestFilter;

public class TraceIdFilter extends OncePerRequestFilter {

	public static final String TRACE_ID_ATTRIBUTE = TraceIdFilter.class.getName() + ".traceId";
	public static final String TRACE_ID_HEADER = "X-Trace-Id";

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
	    throws ServletException, IOException {
		String traceId = UUID.randomUUID().toString();
		request.setAttribute(TRACE_ID_ATTRIBUTE, traceId);
		response.setHeader(TRACE_ID_HEADER, traceId);
		filterChain.doFilter(request, response);
	}

	public static String getTraceId(HttpServletRequest request) {
		Object traceId = request.getAttribute(TRACE_ID_ATTRIBUTE);
		return traceId == null ? UUID.randomUUID().toString() : traceId.toString();
	}
}
