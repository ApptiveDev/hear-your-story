package com.apptive.backend.domain.user.repository;

import java.time.OffsetDateTime;
import java.util.Collection;
import java.util.List;

import jakarta.persistence.LockModeType;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.apptive.backend.domain.user.entity.AccountDeletionTask;
import com.apptive.backend.domain.user.entity.AccountDeletionTaskStatus;

public interface AccountDeletionTaskRepository extends JpaRepository<AccountDeletionTask, String> {

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("""
	    select task from AccountDeletionTask task
	    join fetch task.deletionRequest request
	    where (task.status in :readyStatuses and task.nextAttemptAt <= :now)
	       or (task.status = :processingStatus and task.updatedAt <= :staleBefore)
	    order by task.nextAttemptAt asc, task.createdAt asc
	    """)
	List<AccountDeletionTask> findReadyForUpdate(@Param("readyStatuses") Collection<AccountDeletionTaskStatus> statuses,
	    @Param("processingStatus") AccountDeletionTaskStatus processingStatus, @Param("now") OffsetDateTime now,
	    @Param("staleBefore") OffsetDateTime staleBefore, Pageable pageable);

	boolean existsByDeletionRequest_Id(String requestId);
}
