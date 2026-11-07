package com.apptive.backend.infra.openai;

import java.util.List;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import com.apptive.backend.domain.recording.service.AudioProcessingException;
import com.apptive.backend.domain.recording.service.StorySummarizer;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

@Component
@ConditionalOnProperty(name = "app.audio-processing.mode", havingValue = "openai")
public class OpenAiStorySummarizer implements StorySummarizer {

	private static final String INSTRUCTIONS = """
	    당신은 가족의 기억을 기록하는 편집자입니다.
	    입력된 받아쓰기 원문에 있는 내용만 사용해 자연스러운 한국어 1인칭 이야기로 정리하세요.
	    원문에 없는 사람, 사실, 날짜, 장소, 감정은 추가하거나 추측하지 마세요.
	    의미를 바꾸지 말고 반복과 불필요한 추임새만 정리해 2~4문장으로 작성하세요.
	    제목, 설명, 따옴표 없이 정리된 이야기 본문만 출력하세요.
	    """;

	private final RestClient restClient;
	private final OpenAiProperties properties;

	public OpenAiStorySummarizer(RestClient openAiRestClient, OpenAiProperties properties) {
		this.restClient = openAiRestClient;
		this.properties = properties;
	}

	@Override
	public String summarize(String transcript) {
		ResponseRequest request = new ResponseRequest(properties.summaryModel(), INSTRUCTIONS,
		    "받아쓰기 원문:\n" + transcript, false, 300);
		try {
			ResponseBody response = restClient.post().uri("/responses").contentType(MediaType.APPLICATION_JSON)
			    .body(request).retrieve().body(ResponseBody.class);
			String summary = extractText(response);
			if (summary == null || summary.isBlank()) {
				throw new AudioProcessingException("LLM", "OPENAI_LLM_EMPTY");
			}
			return summary.trim();
		} catch (AudioProcessingException exception) {
			throw exception;
		} catch (RestClientException exception) {
			throw new AudioProcessingException("LLM", "OPENAI_LLM_FAILED", exception);
		}
	}

	private String extractText(ResponseBody response) {
		if (response == null) {
			return null;
		}
		if (response.outputText() != null && !response.outputText().isBlank()) {
			return response.outputText();
		}
		if (response.output() == null) {
			return null;
		}
		return response.output().stream().filter(item -> item.content() != null)
		    .flatMap(item -> item.content().stream()).map(OutputContent::text)
		    .filter(text -> text != null && !text.isBlank()).findFirst().orElse(null);
	}

	private record ResponseRequest(String model, String instructions, String input, boolean store,
	    @JsonProperty("max_output_tokens") int maxOutputTokens) {
	}

	@JsonIgnoreProperties(ignoreUnknown = true)
	private record ResponseBody(@JsonProperty("output_text") String outputText, List<OutputItem> output) {
	}

	@JsonIgnoreProperties(ignoreUnknown = true)
	private record OutputItem(List<OutputContent> content) {
	}

	@JsonIgnoreProperties(ignoreUnknown = true)
	private record OutputContent(String text) {
	}
}
