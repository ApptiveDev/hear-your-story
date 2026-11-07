package com.apptive.backend.infra.openai;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.MediaType;
import org.springframework.http.client.MultipartBodyBuilder;
import org.springframework.stereotype.Component;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import com.apptive.backend.domain.recording.service.AudioProcessingException;
import com.apptive.backend.domain.recording.service.AudioSource;
import com.apptive.backend.domain.recording.service.SpeechTranscriber;

@Component
@ConditionalOnProperty(name = "app.audio-processing.mode", havingValue = "openai")
public class OpenAiSpeechTranscriber implements SpeechTranscriber {

	private final RestClient restClient;
	private final OpenAiProperties properties;

	public OpenAiSpeechTranscriber(RestClient openAiRestClient, OpenAiProperties properties) {
		this.restClient = openAiRestClient;
		this.properties = properties;
	}

	@Override
	public String transcribe(AudioSource audioSource) {
		MultipartBodyBuilder body = new MultipartBodyBuilder();
		body.part("file", namedResource(audioSource)).contentType(MediaType.parseMediaType(audioSource.contentType()));
		body.part("model", properties.transcriptionModel());
		body.part("language", "ko");
		body.part("response_format", "json");

		try {
			TranscriptionResponse response = restClient.post().uri("/audio/transcriptions")
			    .contentType(MediaType.MULTIPART_FORM_DATA).body(asMultipart(body)).retrieve()
			    .body(TranscriptionResponse.class);
			if (response == null || response.text() == null || response.text().isBlank()) {
				throw new AudioProcessingException("STT", "OPENAI_STT_EMPTY");
			}
			return response.text().trim();
		} catch (AudioProcessingException exception) {
			throw exception;
		} catch (RestClientException exception) {
			throw new AudioProcessingException("STT", "OPENAI_STT_FAILED", exception);
		}
	}

	private ByteArrayResource namedResource(AudioSource audioSource) {
		return new ByteArrayResource(audioSource.content()) {
			@Override
			public String getFilename() {
				return audioSource.filename();
			}
		};
	}

	private MultiValueMap<String, org.springframework.http.HttpEntity<?>> asMultipart(MultipartBodyBuilder body) {
		return body.build();
	}

	private record TranscriptionResponse(String text) {
	}
}
