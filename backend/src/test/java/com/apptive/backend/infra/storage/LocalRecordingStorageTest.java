package com.apptive.backend.infra.storage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.nio.file.NoSuchFileException;
import java.nio.file.Path;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import com.apptive.backend.common.exception.DependencyException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.common.exception.StorageException;

class LocalRecordingStorageTest {
	@TempDir
	Path directory;

	@Test
	void missingFilePreservesCauseAndOperationWithoutChangingApiError() {
		var storage = new LocalRecordingStorage(directory.toString());
		assertThatThrownBy(() -> storage.read("recordings/missing.m4a"))
		    .isInstanceOfSatisfying(StorageException.class, failure -> {
			    assertThat(failure.getErrorCode()).isEqualTo(ErrorCode.STORAGE_ERROR);
			    assertThat(failure.getCause()).isInstanceOfSatisfying(DependencyException.class, diagnostic -> {
				    assertThat(diagnostic.provider()).isEqualTo("LOCAL");
				    assertThat(diagnostic.operation()).isEqualTo("READ_AUDIO");
				    assertThat(diagnostic.reason()).isEqualTo("FILE_NOT_FOUND");
			    });
		    }).hasRootCauseInstanceOf(NoSuchFileException.class);
	}
}
