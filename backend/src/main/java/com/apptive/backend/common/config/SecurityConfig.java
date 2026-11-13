package com.apptive.backend.common.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.context.SecurityContextHolderFilter;

import com.apptive.backend.common.auth.JwtAuthenticationFilter;
import com.apptive.backend.common.auth.JwtProperties;
import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.common.auth.RestAccessDeniedHandler;
import com.apptive.backend.common.auth.RestAuthenticationEntryPoint;
import com.apptive.backend.common.web.TraceIdFilter;

@Configuration
@EnableConfigurationProperties(JwtProperties.class)
public class SecurityConfig {

	@Bean
	public SecurityFilterChain securityFilterChain(HttpSecurity http,
	    RestAuthenticationEntryPoint authenticationEntryPoint, RestAccessDeniedHandler accessDeniedHandler,
	    JwtTokenProvider jwtTokenProvider) throws Exception {
		TraceIdFilter traceIdFilter = new TraceIdFilter();
		JwtAuthenticationFilter jwtAuthenticationFilter = new JwtAuthenticationFilter(jwtTokenProvider,
		    authenticationEntryPoint);
		http.addFilterBefore(traceIdFilter, SecurityContextHolderFilter.class)
		    .addFilterAfter(jwtAuthenticationFilter, SecurityContextHolderFilter.class).csrf(csrf -> csrf.disable())
		    .formLogin(form -> form.disable()).httpBasic(basic -> basic.disable())
		    .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
		    .exceptionHandling(exceptions -> exceptions.authenticationEntryPoint(authenticationEntryPoint)
		        .accessDeniedHandler(accessDeniedHandler))
		    .authorizeHttpRequests(authorize -> authorize.requestMatchers(HttpMethod.GET, "/api/v1/health").permitAll()
		        .requestMatchers(HttpMethod.POST, "/api/v1/users", "/api/v1/auth/kakao").permitAll()
		        .requestMatchers(HttpMethod.POST, "/api/v1/pairs/invitations").hasRole("CHILD")
		        .requestMatchers(HttpMethod.POST, "/api/v1/pairs/join").hasRole("PARENT")
		        .requestMatchers(HttpMethod.PUT, "/api/v1/assignments/*/child-answer").hasRole("CHILD")
		        .requestMatchers(HttpMethod.PUT, "/api/v1/assignments/*/parent-recording").hasRole("PARENT")
		        .requestMatchers(HttpMethod.GET, "/api/v1/recordings/*").hasRole("PARENT").anyRequest()
		        .authenticated());

		return http.build();
	}
}
