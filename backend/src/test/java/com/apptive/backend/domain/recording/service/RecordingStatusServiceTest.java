package com.apptive.backend.domain.recording.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.apptive.backend.domain.assignment.entity.Assignment;
import com.apptive.backend.domain.recording.entity.ProcessingStatus;
import com.apptive.backend.domain.recording.entity.Recording;
import com.apptive.backend.domain.recording.repository.RecordingRepository;

class RecordingStatusServiceTest {

	@Test
	void allStateChangesUseLockedLookup() {
		RecordingRepository repository = mock(RecordingRepository.class);
		Clock clock = Clock.fixed(Instant.parse("2026-11-10T00:00:00Z"), ZoneOffset.UTC);
		RecordingStatusService service = new RecordingStatusService(repository, clock);
		Recording recording = new Recording("rec_1", mock(Assignment.class), "recordings/rec_1/audio.m4a", "audio.m4a",
		    "audio/mp4", 128, "key-1", "version-1", OffsetDateTime.now(clock));
		when(repository.findByIdForUpdate("rec_1")).thenReturn(Optional.of(recording));

		assertThat(service.markSttProcessing("rec_1", "version-1")).isTrue();
		assertThat(service.markSttDone("rec_1", "version-1", "받아쓰기")).isTrue();
		assertThat(service.markLlmProcessing("rec_1", "version-1")).isTrue();
		assertThat(service.markReady("rec_1", "version-1", "요약")).isTrue();
		service.markFailed("rec_1", "version-1", "LLM", "LLM_FAILED");

		verify(repository, times(5)).findByIdForUpdate("rec_1");
		verify(repository, never()).findById("rec_1");
		assertThat(recording.getProcessingStatus()).isEqualTo(ProcessingStatus.FAILED);
	}
}
