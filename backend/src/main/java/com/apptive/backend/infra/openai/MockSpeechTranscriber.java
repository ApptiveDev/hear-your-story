package com.apptive.backend.infra.openai;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import com.apptive.backend.domain.recording.service.AudioSource;
import com.apptive.backend.domain.recording.service.SpeechTranscriber;

@Component
@ConditionalOnProperty(name = "app.audio-processing.mode", havingValue = "mock", matchIfMissing = true)
public class MockSpeechTranscriber implements SpeechTranscriber {

	@Override
	public String transcribe(AudioSource audioSource) {
		return "Mock STT 처리 결과입니다.";
	}
}
