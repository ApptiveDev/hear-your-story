package com.apptive.backend.infra.storage;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
public class StorageDeletionProcessor {
	private static final Logger log = LoggerFactory.getLogger(StorageDeletionProcessor.class);
	private final StorageDeletionQueue queue;
	private final RecordingStorage storage;

	@Scheduled(initialDelayString = "${app.storage-deletion.initial-delay:10s}", fixedDelayString = "${app.storage-deletion.fixed-delay:1m}")
	public void processPendingTasks() {
		for (int i = 0; i < 50; i++) {
			StorageDeletionQueue.StorageDeletionClaim claim = queue.claimNext();
			if (claim == null)
				return;
			try {
				storage.delete(claim.objectKey());
				queue.complete(claim.taskId());
			} catch (RuntimeException exception) {
				log.warn("Storage deletion will be retried: type={}", exception.getClass().getSimpleName());
			}
		}
	}
}
