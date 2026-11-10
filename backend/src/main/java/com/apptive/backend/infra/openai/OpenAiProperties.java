package com.apptive.backend.infra.openai;

import java.time.Duration;

import jakarta.validation.constraints.NotBlank;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@ConfigurationProperties("app.openai")
@Validated
public record OpenAiProperties(@NotBlank String apiKey, @NotBlank String baseUrl, @NotBlank String transcriptionModel,
    @NotBlank String summaryModel, @NotBlank String ttsModel, @NotBlank String ttsVoice, Duration connectTimeout,
    Duration readTimeout) {

	public Duration effectiveConnectTimeout() {
		return connectTimeout == null ? Duration.ofSeconds(10) : connectTimeout;
	}

	public Duration effectiveReadTimeout() {
		return readTimeout == null ? Duration.ofSeconds(90) : readTimeout;
	}
}
