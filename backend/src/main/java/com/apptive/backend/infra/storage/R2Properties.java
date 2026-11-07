package com.apptive.backend.infra.storage;

import java.time.Duration;

import jakarta.validation.constraints.NotBlank;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@ConfigurationProperties("app.r2")
@Validated
public record R2Properties(@NotBlank String accountId, @NotBlank String accessKeyId, @NotBlank String secretAccessKey,
    @NotBlank String bucketName, Duration signedUrlDuration) {

	public Duration effectiveSignedUrlDuration() {
		return signedUrlDuration == null ? Duration.ofMinutes(15) : signedUrlDuration;
	}
}
