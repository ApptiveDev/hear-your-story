package com.apptive.backend.common.auth;

import java.io.IOException;
import java.util.List;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.security.authentication.CredentialsExpiredException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import com.apptive.backend.common.exception.ErrorCode;

import io.jsonwebtoken.ExpiredJwtException;

public class JwtAuthenticationFilter extends OncePerRequestFilter {

	public static final String AUTH_ERROR_ATTRIBUTE = JwtAuthenticationFilter.class.getName() + ".errorCode";
	private static final String BEARER_PREFIX = "Bearer ";

	private final JwtTokenProvider tokenProvider;
	private final RestAuthenticationEntryPoint authenticationEntryPoint;

	public JwtAuthenticationFilter(JwtTokenProvider tokenProvider,
	    RestAuthenticationEntryPoint authenticationEntryPoint) {
		this.tokenProvider = tokenProvider;
		this.authenticationEntryPoint = authenticationEntryPoint;
	}

	@Override
	protected boolean shouldNotFilter(HttpServletRequest request) {
		return ("GET".equals(request.getMethod()) && "/api/v1/health".equals(request.getRequestURI())) || ("POST"
		    .equals(request.getMethod())
		    && ("/api/v1/users".equals(request.getRequestURI()) || "/api/v1/auth/kakao".equals(request.getRequestURI())
		        || "/api/v1/auth/refresh".equals(request.getRequestURI())
		        || "/api/v1/auth/logout".equals(request.getRequestURI())));
	}

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
	    throws ServletException, IOException {
		String authorization = request.getHeader("Authorization");
		if (authorization == null) {
			filterChain.doFilter(request, response);
			return;
		}
		if (!authorization.startsWith(BEARER_PREFIX) || authorization.length() == BEARER_PREFIX.length()) {
			failAuthentication(request, response, ErrorCode.UNAUTHORIZED);
			return;
		}

		AuthenticatedUser user;
		try {
			user = tokenProvider.parse(authorization.substring(BEARER_PREFIX.length()));
		} catch (ExpiredJwtException exception) {
			failAuthentication(request, response, ErrorCode.TOKEN_EXPIRED);
			return;
		} catch (RuntimeException exception) {
			failAuthentication(request, response, ErrorCode.UNAUTHORIZED);
			return;
		}

		UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(user, null,
		    List.of(new SimpleGrantedAuthority("ROLE_" + user.role().name())));
		SecurityContextHolder.getContext().setAuthentication(authentication);
		filterChain.doFilter(request, response);
	}

	private void failAuthentication(HttpServletRequest request, HttpServletResponse response, ErrorCode errorCode)
	    throws IOException {
		request.setAttribute(AUTH_ERROR_ATTRIBUTE, errorCode);
		authenticationEntryPoint.commence(request, response, new CredentialsExpiredException(errorCode.name()));
	}
}
