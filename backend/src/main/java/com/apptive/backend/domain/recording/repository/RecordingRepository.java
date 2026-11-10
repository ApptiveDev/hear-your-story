package com.apptive.backend.domain.recording.repository;

import java.time.OffsetDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

import jakarta.persistence.LockModeType;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.apptive.backend.domain.recording.entity.ProcessingStatus;
import com.apptive.backend.domain.recording.entity.Recording;

public interface RecordingRepository extends JpaRepository<Recording, String> {

	Optional<Recording> findByAssignment_Id(String assignmentId);

	List<Recording> findAllByAssignment_IdIn(List<String> assignmentIds);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select r from Recording r where r.id = :recordingId")
	Optional<Recording> findByIdForUpdate(@Param("recordingId") String recordingId);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("""
	    select r from Recording r
	    where r.processingStatus in :statuses
	      and r.updatedAt < :cutoff
	    order by r.updatedAt asc
	    """)
	List<Recording> findStaleForUpdate(@Param("statuses") Collection<ProcessingStatus> statuses,
	    @Param("cutoff") OffsetDateTime cutoff, Pageable pageable);
}
