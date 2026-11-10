package com.apptive.backend.domain.answer.repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import jakarta.persistence.LockModeType;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.apptive.backend.domain.answer.entity.ChildAnswer;
import com.apptive.backend.domain.answer.entity.TtsStatus;

public interface ChildAnswerRepository extends JpaRepository<ChildAnswer, String> {

	Optional<ChildAnswer> findByAssignment_Id(String assignmentId);

	List<ChildAnswer> findAllByAssignment_IdIn(List<String> assignmentIds);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select ca from ChildAnswer ca where ca.id = :answerId")
	Optional<ChildAnswer> findByIdForUpdate(@Param("answerId") String answerId);

	@Query("""
	    select ca from ChildAnswer ca
	    join fetch ca.assignment a
	    join fetch a.familyPair
	    where ca.id = :answerId
	    """)
	Optional<ChildAnswer> findByIdWithAssignment(@Param("answerId") String answerId);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("""
	    select ca from ChildAnswer ca
	    where ca.ttsStatus = :status
	      and ca.ttsVersion is not null
	      and ca.updatedAt < :cutoff
	    order by ca.updatedAt asc
	    """)
	List<ChildAnswer> findStaleTtsForUpdate(@Param("status") TtsStatus status, @Param("cutoff") OffsetDateTime cutoff,
	    Pageable pageable);
}
