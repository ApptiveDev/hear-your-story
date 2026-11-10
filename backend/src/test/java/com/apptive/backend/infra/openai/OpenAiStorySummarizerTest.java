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

class OpenAiStorySummarizerTest {

	private MockRestServiceServer server;
	private OpenAiStorySummarizer summarizer;

	@BeforeEach
	void setUp() {
		RestClient.Builder builder = RestClient.builder();
		server = MockRestServiceServer.bindTo(builder).build();
		OpenAiProperties properties = new OpenAiProperties("test-key", "https://api.openai.test/v1",
		    "gpt-4o-mini-transcribe", "gpt-4o-mini", "gpt-4o-mini-tts", "alloy", Duration.ofSeconds(1),
		    Duration.ofSeconds(5));
		summarizer = new OpenAiStorySummarizer(builder.baseUrl(properties.baseUrl()).build(), properties);
	}

	@Test
	void summarizesTranscriptWithoutStoringResponse() {
		server.expect(requestTo("https://api.openai.test/v1/responses")).andExpect(method(HttpMethod.POST))
		    .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
		    .andExpect(content().string(containsString("\"store\":false")))
		    .andExpect(content().string(containsString("어릴 때 고무줄놀이를 했어요")))
		    .andExpect(content().string(containsString("원문에 없는 사람")))
		    .andRespond(withSuccess("{\"output_text\":\"어릴 때 동네에서 고무줄놀이를 했어요.\"}", MediaType.APPLICATION_JSON));

		String summary = summarizer.summarize("어릴 때 고무줄놀이를 했어요");

		assertThat(summary).isEqualTo("어릴 때 동네에서 고무줄놀이를 했어요.");
		server.verify();
	}

	@Test
	void readsTextFromRawResponseOutput() {
		server.expect(requestTo("https://api.openai.test/v1/responses")).andRespond(withSuccess("""
		    {
		      "output": [{
		        "content": [{"type":"output_text","text":"정리된 이야기입니다."}]
		      }]
		    }
		    """, MediaType.APPLICATION_JSON));

		assertThat(summarizer.summarize("원문입니다.")).isEqualTo("정리된 이야기입니다.");
	}

	@Test
	void mapsProviderFailure() {
		server.expect(requestTo("https://api.openai.test/v1/responses")).andRespond(withServerError());

		assertThatThrownBy(() -> summarizer.summarize("원문입니다.")).isInstanceOf(AudioProcessingException.class)
		    .satisfies(exception -> assertThat(((AudioProcessingException) exception).failureCode())
		        .isEqualTo("OPENAI_LLM_FAILED"));
	}
}
