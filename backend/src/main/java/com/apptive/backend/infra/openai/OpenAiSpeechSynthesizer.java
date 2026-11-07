package com.apptive.backend.infra.openai;

import java.util.Map;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import com.apptive.backend.domain.answer.service.SpeechSynthesizer;
import com.apptive.backend.domain.recording.service.AudioProcessingException;

@Component
@ConditionalOnProperty(name = "app.audio-processing.mode", havingValue = "openai")
public class OpenAiSpeechSynthesizer implements SpeechSynthesizer {

	private final RestClient restClient;
	private final OpenAiProperties properties;

	public OpenAiSpeechSynthesizer(RestClient openAiRestClient, OpenAiProperties properties) {
		this.restClient = openAiRestClient;
		this.properties = properties;
	}

	@Override
	public byte[] synthesize(String text) {
		try {
			byte[] audio = restClient.post().uri("/audio/speech").contentType(MediaType.APPLICATION_JSON)
			    .accept(MediaType.valueOf("audio/mpeg")).body(Map.of("model", properties.ttsModel(), "voice",
			        properties.ttsVoice(), "input", text, "response_format", "mp3"))
			    .retrieve().body(byte[].class);
			if (audio == null || audio.length == 0) {
				throw new AudioProcessingException("TTS", "OPENAI_TTS_EMPTY_RESPONSE");
			}
			return audio;
		} catch (AudioProcessingException exception) {
			throw exception;
		} catch (RuntimeException exception) {
			throw new AudioProcessingException("TTS", "OPENAI_TTS_FAILED", exception);
		}
	}
}
