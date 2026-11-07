package com.apptive.backend.infra.storage;

import java.net.URI;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

@Configuration
@ConditionalOnProperty(name = "app.storage.type", havingValue = "r2")
@EnableConfigurationProperties(R2Properties.class)
public class R2StorageConfig {

	@Bean
	public S3Client r2S3Client(R2Properties properties) {
		return S3Client.builder().endpointOverride(endpoint(properties)).credentialsProvider(credentials(properties))
		    .region(Region.of("auto")).serviceConfiguration(
		        S3Configuration.builder().pathStyleAccessEnabled(true).chunkedEncodingEnabled(false).build())
		    .build();
	}

	@Bean
	public S3Presigner r2S3Presigner(R2Properties properties) {
		return S3Presigner.builder().endpointOverride(endpoint(properties)).credentialsProvider(credentials(properties))
		    .region(Region.of("auto"))
		    .serviceConfiguration(S3Configuration.builder().pathStyleAccessEnabled(true).build()).build();
	}

	private StaticCredentialsProvider credentials(R2Properties properties) {
		return StaticCredentialsProvider
		    .create(AwsBasicCredentials.create(properties.accessKeyId(), properties.secretAccessKey()));
	}

	private URI endpoint(R2Properties properties) {
		return URI.create("https://" + properties.accountId() + ".r2.cloudflarestorage.com");
	}
}
