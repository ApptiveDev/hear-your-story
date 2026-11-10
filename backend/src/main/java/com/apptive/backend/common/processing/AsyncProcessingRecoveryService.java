package com.apptive.backend.common.processing;

import java.time.Clock;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.EnumSet;
import java.util.List;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.domain.answer.entity.ChildAnswer;
import com.apptive.backend.domain.answer.entity.TtsStatus;
import com.apptive.backend.domain.answer.repository.ChildAnswerRepository;
import com.apptive.backend.domain.answer.service.ChildAnswerSavedEvent;
import com.apptive.backend.domain.recording.entity.ProcessingStatus;
import com.apptive.backend.domain.recording.entity.Recording;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.recording.service.RecordingUploadedEvent;

@Service
public class AsyncProcessingRecoveryService {

	private static final EnumSet<ProcessingStatus> RECOVERABLE_RECORDING_STATUSES = EnumSet.of(
	    ProcessingStatus.UPLOADED, ProcessingStatus.STT_PROCESSING, ProcessingStatus.STT_DONE,
	    ProcessingStatus.LLM_PROCESSING);

	private final RecordingRepository recordingRepository;
	private final ChildAnswerRepository childAnswerRepository;
	private final ApplicationEventPublisher eventPublisher;
	private final Clock clock;
	private final Duration staleAfter;
	private final int batchSize;

	public AsyncProcessingRecoveryService(RecordingRepository recordingRepository,
	    ChildAnswerRepository childAnswerRepository, ApplicationEventPublisher eventPublisher, Clock clock,
	    @Value("${app.processing-recovery.stale-after:5m}") Duration staleAfter,
	    @Value("${app.processing-recovery.batch-size:50}") int batchSize) {
		if (staleAfter.isZero() || staleAfter.isNegative()) {
			throw new IllegalArgumentException("processing recovery stale-after must be positive");
		}
		if (batchSize < 1) {
			throw new IllegalArgumentException("processing recovery batch-size must be positive");
		}
		this.recordingRepository = recordingRepository;
		this.childAnswerRepository = childAnswerRepository;
		this.eventPublisher = eventPublisher;
		this.clock = clock;
		this.staleAfter = staleAfter;
		this.batchSize = batchSize;
	}

	@Transactional
	public ProcessingRecoveryResult recoverStale() {
		OffsetDateTime now = OffsetDateTime.now(clock);
		OffsetDateTime cutoff = now.minus(staleAfter);
		PageRequest batch = PageRequest.of(0, batchSize);

		List<Recording> recordings = recordingRepository.findStaleForUpdate(RECOVERABLE_RECORDING_STATUSES, cutoff,
		    batch);
		for (Recording recording : recordings) {
			String version = UUID.randomUUID().toString();
			recording.restartProcessing(version, now);
			eventPublisher.publishEvent(new RecordingUploadedEvent(recording.getId(), version));
		}

		List<ChildAnswer> answers = childAnswerRepository.findStaleTtsForUpdate(TtsStatus.PROCESSING, cutoff, batch);
		for (ChildAnswer answer : answers) {
			String version = UUID.randomUUID().toString();
			answer.restartTts(version, now);
			eventPublisher.publishEvent(new ChildAnswerSavedEvent(answer.getId(), version));
		}

		return new ProcessingRecoveryResult(recordings.size(), answers.size());
	}
}
