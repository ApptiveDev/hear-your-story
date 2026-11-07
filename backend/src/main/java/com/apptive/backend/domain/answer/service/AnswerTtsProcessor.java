package com.apptive.backend.domain.answer.service;

import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import com.apptive.backend.infra.storage.RecordingStorage;

@Component
public class AnswerTtsProcessor {

	private final AnswerTtsStatusService statusService;
	private final SpeechSynthesizer speechSynthesizer;
	private final RecordingStorage recordingStorage;

	public AnswerTtsProcessor(AnswerTtsStatusService statusService, SpeechSynthesizer speechSynthesizer,
	    RecordingStorage recordingStorage) {
		this.statusService = statusService;
		this.speechSynthesizer = speechSynthesizer;
		this.recordingStorage = recordingStorage;
	}

	@Async("recordingTaskExecutor")
	@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
	public void process(ChildAnswerSavedEvent event) {
		AnswerTtsSource source = statusService.findSource(event.answerId(), event.ttsVersion());
		if (source == null) {
			return;
		}

		String newObjectKey = null;
		try {
			byte[] audio = speechSynthesizer.synthesize(source.text());
			newObjectKey = recordingStorage.storeAnswerAudio(event.answerId(), audio);
			TtsReadyResult result = statusService.markReady(event.answerId(), event.ttsVersion(), newObjectKey);
			if (!result.accepted()) {
				recordingStorage.delete(newObjectKey);
				return;
			}
			if (result.previousObjectKey() != null && !result.previousObjectKey().equals(newObjectKey)) {
				recordingStorage.delete(result.previousObjectKey());
			}
		} catch (RuntimeException exception) {
			if (newObjectKey != null) {
				recordingStorage.delete(newObjectKey);
			}
			statusService.markFailed(event.answerId(), event.ttsVersion());
		}
	}
}
