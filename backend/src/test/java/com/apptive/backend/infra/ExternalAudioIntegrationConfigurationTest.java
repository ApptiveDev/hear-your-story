package com.apptive.backend.infra;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import com.apptive.backend.domain.recording.service.SpeechTranscriber;
import com.apptive.backend.domain.recording.service.StorySummarizer;
import com.apptive.backend.infra.openai.OpenAiSpeechTranscriber;
import com.apptive.backend.infra.openai.OpenAiStorySummarizer;
import com.apptive.backend.infra.storage.R2RecordingStorage;
import com.apptive.backend.infra.storage.RecordingStorage;

@SpringBootTest(properties = {"app.storage.type=r2", "app.r2.account-id=test-account",
        "app.r2.access-key-id=test-access-key", "app.r2.secret-access-key=test-secret-key",
        "app.r2.bucket-name=test-bucket", "app.audio-processing.mode=openai", "app.openai.api-key=test-openai-key"})
@ActiveProfiles("test")
class ExternalAudioIntegrationConfigurationTest {

	@Autowired
	private RecordingStorage recordingStorage;

	@Autowired
	private SpeechTranscriber speechTranscriber;

	@Autowired
	private StorySummarizer storySummarizer;

	@Test
	void selectsR2AndOpenAiImplementations() {
		assertThat(recordingStorage).isInstanceOf(R2RecordingStorage.class);
		assertThat(speechTranscriber).isInstanceOf(OpenAiSpeechTranscriber.class);
		assertThat(storySummarizer).isInstanceOf(OpenAiStorySummarizer.class);
	}
}
