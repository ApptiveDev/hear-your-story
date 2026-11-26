package com.apptive.backend.domain.recording.service;

import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import com.apptive.backend.common.exception.FailureLogger;
import com.apptive.backend.infra.storage.RecordingStorage;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Component
public class RecordingFileTransactionListener {

	private final RecordingStorage recordingStorage;

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
			FailureLogger.error("FILE_CLEANUP_" + transactionResult, "STORAGE_ERROR", exception);
		}
	}
}
