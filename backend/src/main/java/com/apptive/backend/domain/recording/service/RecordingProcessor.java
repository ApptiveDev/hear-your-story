package com.apptive.backend.domain.recording.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.infra.storage.RecordingStorage;

@Component
public class RecordingProcessor {

	private final RecordingStatusService statusService;
	private final RecordingStorage recordingStorage;
	private final SpeechTranscriber speechTranscriber;
	private final StorySummarizer storySummarizer;
	private final long mockDelayMs;

	public RecordingProcessor(RecordingStatusService statusService, RecordingStorage recordingStorage,
	    SpeechTranscriber speechTranscriber, StorySummarizer storySummarizer,
	    @Value("${app.recording.mock-processing-delay-ms:0}") long mockDelayMs) {
		this.statusService = statusService;
		this.recordingStorage = recordingStorage;
		this.speechTranscriber = speechTranscriber;
		this.storySummarizer = storySummarizer;
		this.mockDelayMs = mockDelayMs;
	}

	@Async("recordingTaskExecutor")
	@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
	public void process(RecordingUploadedEvent event) {
		if (!statusService.markSttProcessing(event.recordingId(), event.processingVersion())) {
			return;
		}
		if (!pauseForMock(event)) {
			return;
		}
		RecordingProcessingSource source = statusService.findProcessingSource(event.recordingId(),
		    event.processingVersion());
		if (source == null) {
			return;
		}

		String transcript;
		try {
			byte[] audio = recordingStorage.read(source.objectKey());
			transcript = speechTranscriber
			    .transcribe(new AudioSource(audio, source.originalFilename(), source.contentType()));
		} catch (ApiException exception) {
			fail(event, "STT", "STORAGE_READ_FAILED");
			return;
		} catch (AudioProcessingException exception) {
			fail(event, exception.failedStage(), exception.failureCode());
			return;
		} catch (RuntimeException exception) {
			fail(event, "STT", "STT_PROCESSING_FAILED");
			return;
		}

		if (!statusService.markSttDone(event.recordingId(), event.processingVersion(), transcript)) {
			return;
		}
		if (!pauseForMock(event)) {
			return;
		}
		if (!statusService.markLlmProcessing(event.recordingId(), event.processingVersion())) {
			return;
		}

		try {
			String summary = storySummarizer.summarize(transcript);
			if (!pauseForMock(event)) {
				return;
			}
			statusService.markReady(event.recordingId(), event.processingVersion(), summary);
		} catch (AudioProcessingException exception) {
			fail(event, exception.failedStage(), exception.failureCode());
		} catch (RuntimeException exception) {
			fail(event, "LLM", "LLM_PROCESSING_FAILED");
		}
	}

	private void fail(RecordingUploadedEvent event, String stage, String failureCode) {
		statusService.markFailed(event.recordingId(), event.processingVersion(), stage, failureCode);
	}

	private boolean pauseForMock(RecordingUploadedEvent event) {
		if (mockDelayMs <= 0) {
			return true;
		}
		try {
			Thread.sleep(mockDelayMs);
			return true;
		} catch (InterruptedException exception) {
			Thread.currentThread().interrupt();
			fail(event, "PROCESSING", "PROCESSING_INTERRUPTED");
			return false;
		}
	}
}
