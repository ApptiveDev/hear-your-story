package com.apptive.backend.infra.openai;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

@Configuration
@ConditionalOnProperty(name = "app.audio-processing.mode", havingValue = "openai")
@EnableConfigurationProperties(OpenAiProperties.class)
public class OpenAiConfig {

	@Bean
	public RestClient openAiRestClient(OpenAiProperties properties) {
		SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
		requestFactory.setConnectTimeout(properties.effectiveConnectTimeout());
		requestFactory.setReadTimeout(properties.effectiveReadTimeout());
		return RestClient.builder().baseUrl(properties.baseUrl()).requestFactory(requestFactory)
		    .defaultHeader(HttpHeaders.AUTHORIZATION, "Bearer " + properties.apiKey()).build();
	}
}
