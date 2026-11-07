package com.apptive.backend.infra.storage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.net.URL;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.mock.web.MockMultipartFile;

import software.amazon.awssdk.core.ResponseBytes;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.presigner.model.PresignedGetObjectRequest;

class R2RecordingStorageTest {

	private S3Client s3Client;
	private S3Presigner presigner;
	private R2RecordingStorage storage;

	@BeforeEach
	void setUp() {
		s3Client = mock(S3Client.class);
		presigner = mock(S3Presigner.class);
		R2Properties properties = new R2Properties("account", "access-key", "secret-key", "recordings",
		    Duration.ofMinutes(15));
		Clock clock = Clock.fixed(Instant.parse("2026-09-26T10:00:00Z"), ZoneOffset.UTC);
		storage = new R2RecordingStorage(s3Client, presigner, properties, clock);
	}

	@Test
	void storesM4aInPrivateBucket() {
		MockMultipartFile file = new MockMultipartFile("audioFile", "answer.m4a", "audio/mp4", new byte[]{1, 2, 3});

		String objectKey = storage.store("rec_123", file);

		assertThat(objectKey).startsWith("recordings/rec_123/").endsWith(".m4a");
		ArgumentCaptor<PutObjectRequest> request = ArgumentCaptor.forClass(PutObjectRequest.class);
		verify(s3Client).putObject(request.capture(), any(software.amazon.awssdk.core.sync.RequestBody.class));
		assertThat(request.getValue().bucket()).isEqualTo("recordings");
		assertThat(request.getValue().key()).isEqualTo(objectKey);
		assertThat(request.getValue().contentType()).isEqualTo("audio/mp4");
	}

	@Test
	void readsStoredAudioBytes() {
		byte[] audio = new byte[]{4, 5, 6};
		when(s3Client.getObjectAsBytes(any(software.amazon.awssdk.services.s3.model.GetObjectRequest.class)))
		    .thenReturn(ResponseBytes.fromByteArray(GetObjectResponse.builder().build(), audio));

		assertThat(storage.read("recordings/rec_123/audio.m4a")).containsExactly(audio);
	}

	@Test
	void createsFifteenMinuteSignedReadUrl() throws Exception {
		PresignedGetObjectRequest signedRequest = mock(PresignedGetObjectRequest.class);
		when(signedRequest.url()).thenReturn(new URL("https://example.r2.dev/signed"));
		when(presigner.presignGetObject(any(GetObjectPresignRequest.class))).thenReturn(signedRequest);

		SignedAudioUrl signed = storage.createSignedReadUrl("recordings/rec_123/audio.m4a").orElseThrow();

		assertThat(signed.url()).isEqualTo("https://example.r2.dev/signed");
		assertThat(signed.expiresAt()).isEqualTo("2026-09-26T10:15:00Z");
	}
}
