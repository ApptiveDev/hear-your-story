package com.apptive.backend.domain.user.web;

import java.time.Clock;
import java.util.List;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.http.converter.FormHttpMessageConverter;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.client.OAuth2AuthorizedClient;
import org.springframework.security.oauth2.client.endpoint.OAuth2AccessTokenResponseClient;
import org.springframework.security.oauth2.client.endpoint.OAuth2AuthorizationCodeGrantRequest;
import org.springframework.security.oauth2.client.endpoint.RestClientAuthorizationCodeTokenResponseClient;
import org.springframework.security.oauth2.client.http.OAuth2ErrorResponseErrorHandler;
import org.springframework.security.oauth2.client.oidc.authentication.OidcIdTokenDecoderFactory;
import org.springframework.security.oauth2.client.registration.ClientRegistration;
import org.springframework.security.oauth2.client.registration.InMemoryClientRegistrationRepository;
import org.springframework.security.oauth2.client.web.DefaultOAuth2AuthorizationRequestResolver;
import org.springframework.security.oauth2.client.web.OAuth2AuthorizedClientRepository;
import org.springframework.security.oauth2.core.AuthorizationGrantType;
import org.springframework.security.oauth2.core.ClientAuthenticationMethod;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.core.http.converter.OAuth2AccessTokenResponseHttpMessageConverter;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.security.oauth2.jwt.JwtDecoderFactory;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.security.web.savedrequest.NullRequestCache;
import org.springframework.web.client.RestClient;

import com.apptive.backend.common.exception.FailureLogger;

@Configuration
@ConditionalOnProperty(name = "app.web-deletion.enabled", havingValue = "true")
@EnableConfigurationProperties(WebDeletionProperties.class)
public class WebDeletionSecurityConfig {

	@Bean
	public OAuth2AccessTokenResponseClient<OAuth2AuthorizationCodeGrantRequest> webDeletionTokenClient() {
		SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
		factory.setConnectTimeout(5_000);
		factory.setReadTimeout(10_000);
		RestClientAuthorizationCodeTokenResponseClient client = new RestClientAuthorizationCodeTokenResponseClient();
		client.setRestClient(RestClient.builder().requestFactory(factory).messageConverters(converters -> {
			converters.clear();
			converters.add(new FormHttpMessageConverter());
			converters.add(new OAuth2AccessTokenResponseHttpMessageConverter());
		}).defaultStatusHandler(new OAuth2ErrorResponseErrorHandler()).build());
		return client;
	}

	@Bean
	public JwtDecoderFactory<ClientRegistration> webDeletionIdTokenDecoderFactory() {
		// Spring OIDC의 서명·iss·aud·시간 검증과 인증 provider의 nonce 검증 사용.
		return new OidcIdTokenDecoderFactory();
	}

	@Bean
	public InMemoryClientRegistrationRepository webDeletionClients(WebDeletionProperties properties) {
		properties.validateEnabled();
		return new InMemoryClientRegistrationRepository(ClientRegistration.withRegistrationId("kakao-deletion")
		    .clientId(properties.restApiKey()).clientSecret(properties.clientSecret())
		    .clientAuthenticationMethod(ClientAuthenticationMethod.CLIENT_SECRET_POST)
		    .authorizationGrantType(AuthorizationGrantType.AUTHORIZATION_CODE).redirectUri(properties.redirectUri())
		    .scope("openid").authorizationUri("https://kauth.kakao.com/oauth/authorize")
		    .tokenUri("https://kauth.kakao.com/oauth/token").issuerUri("https://kauth.kakao.com")
		    .jwkSetUri("https://kauth.kakao.com/.well-known/jwks.json")
		    .userInfoUri("https://kapi.kakao.com/v1/oidc/userinfo").userNameAttributeName("sub").clientName("카카오 계정 확인")
		    .build());
	}

	@Bean
	@Order(1)
	public SecurityFilterChain webDeletionSecurity(HttpSecurity http, InMemoryClientRegistrationRepository clients,
	    Clock clock, OAuth2AccessTokenResponseClient<OAuth2AuthorizationCodeGrantRequest> webDeletionTokenClient)
	    throws Exception {
		HttpSessionSecurityContextRepository contexts = new HttpSessionSecurityContextRepository();
		contexts.setDisableUrlRewriting(true);
		DefaultOAuth2AuthorizationRequestResolver resolver = new DefaultOAuth2AuthorizationRequestResolver(clients,
		    "/oauth2/authorization");
		// 브라우저에 다른 카카오 세션이 남아 있어도 사용자가 직접 다시 확인한다.
		resolver.setAuthorizationRequestCustomizer(
		    builder -> builder.additionalParameters(params -> params.put("prompt", "login")));
		http.securityMatcher("/account-deletion", "/account-deletion/**", "/oauth2/authorization/kakao-deletion",
		    "/login/oauth2/code/kakao-deletion")
		    .authorizeHttpRequests(
		        auth -> auth
		            .requestMatchers("/account-deletion", "/account-deletion/error",
		                "/oauth2/authorization/kakao-deletion", "/login/oauth2/code/kakao-deletion")
		            .permitAll().anyRequest().authenticated())
		    .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED))
		    .exceptionHandling(errors -> errors.accessDeniedHandler((request, response, exception) -> {
			    response.setStatus(403);
			    response.setContentType("text/html;charset=UTF-8");
			    response.getWriter()
			        .write(WebDeletionPages
			            .page(403, "요청을 다시 확인해 주세요", "<p>확인 화면이 만료됐거나 안전한 요청으로 확인되지 않았어요. 다시 본인 확인 후 진행해 주세요.</p>")
			            .getBody());
		    })).securityContext(context -> context.securityContextRepository(contexts))
		    .requestCache(cache -> cache.requestCache(new NullRequestCache()))
		    .headers(headers -> headers.contentSecurityPolicy(policy -> policy.policyDirectives(
		        "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'"))
		        .addHeaderWriter((request, response) -> {
			        response.setHeader("Referrer-Policy", "no-referrer");
			        response.setHeader("Cache-Control", "no-store");
			        response.setHeader("X-Robots-Tag", "noindex, nofollow");
		        }))
		    // 웹 전용 체인은 CSRF 보호를 유지한다. 모바일 JWT 체인과 분리한다.
		    .oauth2Login(login -> login.clientRegistrationRepository(clients)
		        .tokenEndpoint(endpoint -> endpoint.accessTokenResponseClient(webDeletionTokenClient))
		        .authorizedClientRepository(new DiscardAuthorizedClients())
		        .authorizationEndpoint(endpoint -> endpoint.authorizationRequestResolver(resolver))
		        .loginPage("/account-deletion").successHandler((request, response, authentication) -> {
			        OidcUser oidc = (OidcUser) authentication.getPrincipal();
			        WebDeletionIdentity identity = new WebDeletionIdentity(oidc.getSubject(), clock.instant());
			        var context = SecurityContextHolder.createEmptyContext();
			        context.setAuthentication(
			            UsernamePasswordAuthenticationToken.authenticated(identity, null, List.of()));
			        SecurityContextHolder.setContext(context);
			        request.getSession().setMaxInactiveInterval(600);
			        contexts.saveContext(context, request, response);
			        response.sendRedirect("/account-deletion/confirm");
		        }).failureHandler((request, response, exception) -> {
			        // 공급자 메시지·인가 코드·토큰 대신 허용한 오류 분류만 기록한다.
			        String code = exception instanceof OAuth2AuthenticationException oauth
			            ? oauth.getError().getErrorCode()
			            : "unknown";
			        String safeCode = switch (code) {
				        case "invalid_nonce", "invalid_state_parameter", "authorization_request_not_found",
				            "invalid_id_token", "invalid_token_response", "invalid_user_info_response",
				            "access_denied" -> code;
				        default -> "authentication_failed";
			        };
			        FailureLogger.error("WEB_DELETION_AUTH", safeCode, exception);
			        if (request.getSession(false) != null) {
				        request.getSession(false).invalidate();
			        }
			        SecurityContextHolder.clearContext();
			        response.sendRedirect("/account-deletion/error");
		        }));
		return http.build();
	}

	// 인증 완료 뒤 카카오 access/refresh token을 서버 세션·DB에 저장하지 않는다.
	private static class DiscardAuthorizedClients implements OAuth2AuthorizedClientRepository {
		@Override
		public <T extends OAuth2AuthorizedClient> T loadAuthorizedClient(String registrationId,
		    Authentication principal, HttpServletRequest request) {
			return null;
		}

		@Override
		public void saveAuthorizedClient(OAuth2AuthorizedClient client, Authentication principal,
		    HttpServletRequest request, HttpServletResponse response) {
			// 이 흐름은 인증 후 외부 API를 다시 호출하지 않는다.
		}

		@Override
		public void removeAuthorizedClient(String registrationId, Authentication principal, HttpServletRequest request,
		    HttpServletResponse response) {
			// 저장하지 않으므로 삭제할 토큰도 없다.
		}
	}
}
