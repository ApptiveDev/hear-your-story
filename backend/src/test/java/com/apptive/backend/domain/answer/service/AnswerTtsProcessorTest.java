package com.apptive.backend.domain.answer.service;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.apptive.backend.infra.storage.RecordingStorage;

class AnswerTtsProcessorTest {

	private AnswerTtsStatusService statusService;
	private SpeechSynthesizer synthesizer;
	private RecordingStorage storage;
	private AnswerTtsProcessor processor;

	@BeforeEach
	void setUp() {
		statusService = mock(AnswerTtsStatusService.class);
		synthesizer = mock(SpeechSynthesizer.class);
		storage = mock(RecordingStorage.class);
		processor = new AnswerTtsProcessor(statusService, synthesizer, storage);
	}

	@Test
	void generatesStoresAndMarksReady() {
		ChildAnswerSavedEvent event = new ChildAnswerSavedEvent("ans_1", "version-1");
		byte[] audio = new byte[]{1, 2, 3};
		when(statusService.findSource("ans_1", "version-1")).thenReturn(new AnswerTtsSource("자녀의 답변"));
		when(synthesizer.synthesize("자녀의 답변")).thenReturn(audio);
		when(storage.storeAnswerAudio("ans_1", audio)).thenReturn("tts/ans_1/new.mp3");
		when(statusService.markReady("ans_1", "version-1", "tts/ans_1/new.mp3"))
		    .thenReturn(TtsReadyResult.accepted("tts/ans_1/old.mp3"));

		processor.process(event);

		verify(storage).delete("tts/ans_1/old.mp3");
		verify(statusService, never()).markFailed("ans_1", "version-1");
	}

	@Test
	void marksFailedWhenSynthesisFails() {
		ChildAnswerSavedEvent event = new ChildAnswerSavedEvent("ans_1", "version-1");
		when(statusService.findSource("ans_1", "version-1")).thenReturn(new AnswerTtsSource("자녀의 답변"));
		when(synthesizer.synthesize("자녀의 답변")).thenThrow(new IllegalStateException("provider failed"));

		processor.process(event);

		verify(statusService).markFailed("ans_1", "version-1");
		verify(storage, never()).storeAnswerAudio(any(), any());
	}

	@Test
	void discardsAudioFromStaleAnswerVersion() {
		ChildAnswerSavedEvent event = new ChildAnswerSavedEvent("ans_1", "version-1");
		byte[] audio = new byte[]{1};
		when(statusService.findSource("ans_1", "version-1")).thenReturn(new AnswerTtsSource("수정 전 답변"));
		when(synthesizer.synthesize("수정 전 답변")).thenReturn(audio);
		when(storage.storeAnswerAudio("ans_1", audio)).thenReturn("tts/ans_1/stale.mp3");
		when(statusService.markReady("ans_1", "version-1", "tts/ans_1/stale.mp3")).thenReturn(TtsReadyResult.stale());

		processor.process(event);

		verify(storage).delete("tts/ans_1/stale.mp3");
	}
}
