package com.apptive.backend.infra.storage;

import java.io.IOException;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;

import lombok.RequiredArgsConstructor;
import software.amazon.awssdk.core.ResponseBytes;
import software.amazon.awssdk.core.exception.SdkException;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.PresignedGetObjectRequest;

@RequiredArgsConstructor
@Component
@ConditionalOnProperty(name = "app.storage.type", havingValue = "r2")
public class R2RecordingStorage implements RecordingStorage {

	private static final Logger log = LoggerFactory.getLogger(R2RecordingStorage.class);

	private final S3Client s3Client;
	private final S3Presigner presigner;
	private final R2Properties properties;
	private final Clock clock;

	@Override
	public String store(String recordingId, MultipartFile file) {
		String objectKey = "recordings/" + recordingId + "/" + UUID.randomUUID() + ".m4a";
		PutObjectRequest request = PutObjectRequest.builder().bucket(properties.bucketName()).key(objectKey)
		    .contentType(file.getContentType()).build();
		try {
			s3Client.putObject(request, RequestBody.fromInputStream(file.getInputStream(), file.getSize()));
			return objectKey;
		} catch (IOException | SdkException exception) {
			// 원본 예외는 debugger에서 확인하고, 로그에는 파일 경로·응답 원문을 남기지 않는다.
			String r2Code = exception instanceof S3Exception s3 && s3.awsErrorDetails() != null
			    ? s3.awsErrorDetails().errorCode()
			    : null;
			String safeCode = r2Code != null && r2Code.matches("[A-Za-z0-9_]{1,80}") ? r2Code : "unknown";
			int status = exception instanceof S3Exception s3 ? s3.statusCode() : 0;
			log.error("R2 recording upload failed: type={}, status={}, r2Code={}", exception.getClass().getSimpleName(),
			    status, safeCode);
			throw new ApiException(ErrorCode.STORAGE_ERROR, exception);
		}
	}

	@Override
	public String storeAnswerAudio(String answerId, byte[] audio) {
		String objectKey = "tts/" + answerId + "/" + UUID.randomUUID() + ".mp3";
		PutObjectRequest request = PutObjectRequest.builder().bucket(properties.bucketName()).key(objectKey)
		    .contentType("audio/mpeg").build();
		try {
			s3Client.putObject(request, RequestBody.fromBytes(audio));
			return objectKey;
		} catch (SdkException exception) {
			throw new ApiException(ErrorCode.STORAGE_ERROR);
		}
	}

	@Override
	public byte[] read(String objectKey) {
		try {
			GetObjectRequest request = GetObjectRequest.builder().bucket(properties.bucketName()).key(objectKey)
			    .build();
			ResponseBytes<GetObjectResponse> response = s3Client.getObjectAsBytes(request);
			return response.asByteArray();
		} catch (SdkException exception) {
			throw new ApiException(ErrorCode.STORAGE_ERROR);
		}
	}

	@Override
	public Optional<SignedAudioUrl> createSignedReadUrl(String objectKey) {
		GetObjectRequest getObjectRequest = GetObjectRequest.builder().bucket(properties.bucketName()).key(objectKey)
		    .build();
		GetObjectPresignRequest presignRequest = GetObjectPresignRequest.builder()
		    .signatureDuration(properties.effectiveSignedUrlDuration()).getObjectRequest(getObjectRequest).build();
		try {
			PresignedGetObjectRequest signed = presigner.presignGetObject(presignRequest);
			OffsetDateTime expiresAt = OffsetDateTime.now(clock).plus(properties.effectiveSignedUrlDuration());
			return Optional.of(new SignedAudioUrl(signed.url().toString(), expiresAt));
		} catch (SdkException exception) {
			throw new ApiException(ErrorCode.STORAGE_ERROR);
		}
	}

	@Override
	public void delete(String objectKey) {
		if (objectKey == null) {
			return;
		}
		try {
			s3Client.deleteObject(builder -> builder.bucket(properties.bucketName()).key(objectKey));
		} catch (SdkException exception) {
			throw new ApiException(ErrorCode.STORAGE_ERROR);
		}
	}
}
