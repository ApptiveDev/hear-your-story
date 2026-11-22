package com.apptive.backend.infra.storage;

import java.time.OffsetDateTime;
import java.util.List;

import jakarta.persistence.LockModeType;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface StorageDeletionTaskRepository extends JpaRepository<StorageDeletionTask, String> {
	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select t from StorageDeletionTask t where t.nextAttemptAt <= :now order by t.nextAttemptAt, t.id")
	List<StorageDeletionTask> findReadyForUpdate(@Param("now") OffsetDateTime now, Pageable pageable);
}
