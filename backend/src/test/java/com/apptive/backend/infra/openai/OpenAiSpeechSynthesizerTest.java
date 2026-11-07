package com.apptive.backend.infra.openai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.content;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withServerError;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import java.time.Duration;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import com.apptive.backend.domain.recording.service.AudioProcessingException;

class OpenAiSpeechSynthesizerTest {

	private MockRestServiceServer server;
	private OpenAiSpeechSynthesizer synthesizer;

	@BeforeEach
	void setUp() {
		RestClient.Builder builder = RestClient.builder();
		server = MockRestServiceServer.bindTo(builder).build();
		OpenAiProperties properties = new OpenAiProperties("test-key", "https://api.openai.test/v1",
		    "gpt-4o-mini-transcribe", "gpt-4o-mini", "gpt-4o-mini-tts", "alloy", Duration.ofSeconds(1),
		    Duration.ofSeconds(5));
		synthesizer = new OpenAiSpeechSynthesizer(builder.baseUrl(properties.baseUrl()).build(), properties);
	}

	@Test
	void synthesizesChildAnswerAsMp3() {
		byte[] expected = new byte[]{1, 2, 3, 4};
		server.expect(requestTo("https://api.openai.test/v1/audio/speech")).andExpect(method(HttpMethod.POST))
		    .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
		    .andExpect(content().string(containsString("\"model\":\"gpt-4o-mini-tts\"")))
		    .andExpect(content().string(containsString("\"voice\":\"alloy\"")))
		    .andExpect(content().string(containsString("자녀의 답변입니다")))
		    .andRespond(withSuccess(expected, MediaType.valueOf("audio/mpeg")));

		assertThat(synthesizer.synthesize("자녀의 답변입니다")).isEqualTo(expected);
		server.verify();
	}

	@Test
	void mapsProviderFailure() {
		server.expect(requestTo("https://api.openai.test/v1/audio/speech")).andRespond(withServerError());

		assertThatThrownBy(() -> synthesizer.synthesize("답변")).isInstanceOf(AudioProcessingException.class)
		    .satisfies(exception -> assertThat(((AudioProcessingException) exception).failureCode())
		        .isEqualTo("OPENAI_TTS_FAILED"));
	}
}
