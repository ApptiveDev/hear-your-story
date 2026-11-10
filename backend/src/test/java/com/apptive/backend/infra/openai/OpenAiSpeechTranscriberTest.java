package com.apptive.backend.infra.openai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.content;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
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
import com.apptive.backend.domain.recording.service.AudioSource;

class OpenAiSpeechTranscriberTest {

	private MockRestServiceServer server;
	private OpenAiSpeechTranscriber transcriber;

	@BeforeEach
	void setUp() {
		RestClient.Builder builder = RestClient.builder();
		server = MockRestServiceServer.bindTo(builder).build();
		OpenAiProperties properties = new OpenAiProperties("test-key", "https://api.openai.test/v1",
		    "gpt-4o-mini-transcribe", "gpt-4o-mini", "gpt-4o-mini-tts", "alloy", Duration.ofSeconds(1),
		    Duration.ofSeconds(5));
		RestClient client = builder.baseUrl(properties.baseUrl())
		    .defaultHeader("Authorization", "Bearer " + properties.apiKey()).build();
		transcriber = new OpenAiSpeechTranscriber(client, properties);
	}

	@Test
	void transcribesKoreanM4a() {
		server.expect(requestTo("https://api.openai.test/v1/audio/transcriptions")).andExpect(method(HttpMethod.POST))
		    .andExpect(header("Authorization", "Bearer test-key"))
		    .andExpect(content().contentTypeCompatibleWith(MediaType.MULTIPART_FORM_DATA))
		    .andExpect(content().string(containsString("gpt-4o-mini-transcribe")))
		    .andExpect(content().string(containsString("answer.m4a"))).andExpect(content().string(containsString("ko")))
		    .andRespond(withSuccess("{\"text\":\"어릴 때 고무줄놀이를 했어요.\"}", MediaType.APPLICATION_JSON));

		String text = transcriber.transcribe(new AudioSource(new byte[]{1, 2, 3}, "answer.m4a", "audio/mp4"));

		assertThat(text).isEqualTo("어릴 때 고무줄놀이를 했어요.");
		server.verify();
	}

	@Test
	void mapsProviderFailureWithoutLeakingResponse() {
		server.expect(requestTo("https://api.openai.test/v1/audio/transcriptions")).andRespond(withServerError());

		assertThatThrownBy(() -> transcriber.transcribe(new AudioSource(new byte[]{1}, "answer.m4a", "audio/mp4")))
		    .isInstanceOf(AudioProcessingException.class)
		    .satisfies(exception -> assertThat(((AudioProcessingException) exception).failureCode())
		        .isEqualTo("OPENAI_STT_FAILED"));
	}
}
