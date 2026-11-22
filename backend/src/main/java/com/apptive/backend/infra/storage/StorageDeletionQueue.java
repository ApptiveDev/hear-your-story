package com.apptive.backend.infra.storage;

import java.time.Clock;
import java.time.OffsetDateTime;

import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.id.IdGenerator;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class StorageDeletionQueue {
	private final StorageDeletionTaskRepository repository;
	private final IdGenerator idGenerator;
	private final Clock clock;

	@Transactional(propagation = Propagation.MANDATORY)
	public void enqueue(String objectKey) {
		if (objectKey != null && !objectKey.isBlank()) {
			repository.save(new StorageDeletionTask(idGenerator.generate("sdk"), objectKey, OffsetDateTime.now(clock)));
		}
	}

	@Transactional
	public StorageDeletionClaim claimNext() {
		OffsetDateTime now = OffsetDateTime.now(clock);
		return repository.findReadyForUpdate(now, PageRequest.of(0, 1)).stream().findFirst().map(task -> {
			task.claim(now);
			return new StorageDeletionClaim(task.getId(), task.getObjectKey());
		}).orElse(null);
	}

	@Transactional
	public void complete(String taskId) {
		repository.deleteById(taskId);
	}

	public record StorageDeletionClaim(String taskId, String objectKey) {
	}
}
