package com.apptive.backend.domain.recording.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import com.apptive.backend.infra.storage.RecordingStorage;

@Component
public class RecordingFileTransactionListener {

	private static final Logger log = LoggerFactory.getLogger(RecordingFileTransactionListener.class);

	private final RecordingStorage recordingStorage;

	public RecordingFileTransactionListener(RecordingStorage recordingStorage) {
		this.recordingStorage = recordingStorage;
	}

	@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
	public void deletePreviousFileAfterCommit(RecordingFileChangedEvent event) {
		if (event.previousObjectKey() == null || event.previousObjectKey().equals(event.newObjectKey())) {
			return;
		}
		deleteSafely(event.previousObjectKey(), "commit");
	}

	@TransactionalEventListener(phase = TransactionPhase.AFTER_ROLLBACK)
	public void deleteNewFileAfterRollback(RecordingFileChangedEvent event) {
		deleteSafely(event.newObjectKey(), "rollback");
	}

	private void deleteSafely(String objectKey, String transactionResult) {
		try {
			recordingStorage.delete(objectKey);
		} catch (RuntimeException exception) {
			log.warn("Recording file cleanup failed after transaction {}: type={}", transactionResult,
			    exception.getClass().getSimpleName());
		}
	}
}
