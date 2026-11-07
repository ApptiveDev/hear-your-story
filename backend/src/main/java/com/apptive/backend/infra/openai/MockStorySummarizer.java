package com.apptive.backend.infra.openai;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import com.apptive.backend.domain.recording.service.StorySummarizer;

@Component
@ConditionalOnProperty(name = "app.audio-processing.mode", havingValue = "mock", matchIfMissing = true)
public class MockStorySummarizer implements StorySummarizer {

	@Override
	public String summarize(String transcript) {
		return "Mock으로 정리된 이야기입니다.";
	}
}
