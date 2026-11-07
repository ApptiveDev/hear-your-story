package com.apptive.backend.domain.recording.service;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;

import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.infra.storage.RecordingStorage;

class RecordingProcessorTest {

	private RecordingStatusService statusService;
	private RecordingStorage recordingStorage;
	private SpeechTranscriber speechTranscriber;
	private StorySummarizer storySummarizer;
	private RecordingProcessor processor;
	private RecordingUploadedEvent event;

	@BeforeEach
	void setUp() {
		statusService = mock(RecordingStatusService.class);
		recordingStorage = mock(RecordingStorage.class);
		speechTranscriber = mock(SpeechTranscriber.class);
		storySummarizer = mock(StorySummarizer.class);
		processor = new RecordingProcessor(statusService, recordingStorage, speechTranscriber, storySummarizer, 0);
		event = new RecordingUploadedEvent("rec_123", "version-1");

		when(statusService.markSttProcessing("rec_123", "version-1")).thenReturn(true);
		when(statusService.findProcessingSource("rec_123", "version-1"))
		    .thenReturn(new RecordingProcessingSource("recordings/rec_123/audio.m4a", "answer.m4a", "audio/mp4"));
		when(recordingStorage.read("recordings/rec_123/audio.m4a")).thenReturn(new byte[]{1, 2, 3});
		when(speechTranscriber.transcribe(any(AudioSource.class))).thenReturn("받아쓰기 원문");
		when(statusService.markSttDone("rec_123", "version-1", "받아쓰기 원문")).thenReturn(true);
		when(statusService.markLlmProcessing("rec_123", "version-1")).thenReturn(true);
		when(storySummarizer.summarize("받아쓰기 원문")).thenReturn("정리된 이야기");
	}

	@Test
	void processesStoredAudioThroughSttAndLlm() {
		processor.process(event);

		InOrder order = inOrder(statusService, recordingStorage, speechTranscriber, storySummarizer);
		order.verify(statusService).markSttProcessing("rec_123", "version-1");
		order.verify(statusService).findProcessingSource("rec_123", "version-1");
		order.verify(recordingStorage).read("recordings/rec_123/audio.m4a");
		order.verify(speechTranscriber).transcribe(any(AudioSource.class));
		order.verify(statusService).markSttDone("rec_123", "version-1", "받아쓰기 원문");
		order.verify(statusService).markLlmProcessing("rec_123", "version-1");
		order.verify(storySummarizer).summarize("받아쓰기 원문");
		order.verify(statusService).markReady("rec_123", "version-1", "정리된 이야기");
	}

	@Test
	void sttFailureIsSavedAndLlmIsNotCalled() {
		when(speechTranscriber.transcribe(any(AudioSource.class)))
		    .thenThrow(new AudioProcessingException("STT", "OPENAI_STT_FAILED"));

		processor.process(event);

		verify(statusService).markFailed("rec_123", "version-1", "STT", "OPENAI_STT_FAILED");
		verify(storySummarizer, never()).summarize(any());
	}

	@Test
	void storageReadFailureIsSavedAsSttFailure() {
		when(recordingStorage.read("recordings/rec_123/audio.m4a"))
		    .thenThrow(new ApiException(ErrorCode.STORAGE_ERROR));

		processor.process(event);

		verify(statusService).markFailed("rec_123", "version-1", "STT", "STORAGE_READ_FAILED");
		verify(speechTranscriber, never()).transcribe(any());
	}

	@Test
	void llmFailurePreservesTranscriptAndMarksFailed() {
		when(storySummarizer.summarize("받아쓰기 원문")).thenThrow(new AudioProcessingException("LLM", "OPENAI_LLM_FAILED"));

		processor.process(event);

		verify(statusService).markSttDone("rec_123", "version-1", "받아쓰기 원문");
		verify(statusService).markFailed("rec_123", "version-1", "LLM", "OPENAI_LLM_FAILED");
		verify(statusService, never()).markReady(any(), any(), any());
	}

	@Test
	void staleUploadEventStopsBeforeReadingStorage() {
		when(statusService.markSttProcessing("rec_123", "version-1")).thenReturn(false);

		processor.process(event);

		verify(recordingStorage, never()).read(any());
		verify(speechTranscriber, never()).transcribe(any());
	}
}
