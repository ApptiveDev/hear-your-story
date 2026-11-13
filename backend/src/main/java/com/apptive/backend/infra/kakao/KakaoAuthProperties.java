package com.apptive.backend.infra.kakao;

import jakarta.validation.constraints.NotBlank;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "app.auth.kakao")
public record KakaoAuthProperties(@NotBlank String nativeAppKey, @NotBlank String issuer, @NotBlank String jwkSetUri) {
}
