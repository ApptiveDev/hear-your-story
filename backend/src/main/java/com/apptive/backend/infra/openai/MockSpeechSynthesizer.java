package com.apptive.backend.infra.openai;

import java.nio.charset.StandardCharsets;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import com.apptive.backend.domain.answer.service.SpeechSynthesizer;

@Component
@ConditionalOnProperty(name = "app.audio-processing.mode", havingValue = "mock", matchIfMissing = true)
public class MockSpeechSynthesizer implements SpeechSynthesizer {

	@Override
	public byte[] synthesize(String text) {
		return ("MOCK_MP3:" + text).getBytes(StandardCharsets.UTF_8);
	}
}
