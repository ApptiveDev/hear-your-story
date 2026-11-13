package com.apptive.backend.common.auth;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "app.auth")
public record JwtProperties(@NotBlank String jwtSecret, @Min(1) long accessTokenExpirationMinutes,
    @Min(1) long registrationTokenExpirationMinutes, @Min(1) long refreshTokenExpirationDays) {
}
