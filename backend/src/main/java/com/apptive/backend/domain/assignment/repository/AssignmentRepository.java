package com.apptive.backend.domain.assignment.repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import jakarta.persistence.LockModeType;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.apptive.backend.domain.assignment.entity.Assignment;

public interface AssignmentRepository extends JpaRepository<Assignment, String> {

	Optional<Assignment> findByFamilyPair_IdAndAssignedDate(String pairId, LocalDate assignedDate);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select a from Assignment a join fetch a.familyPair where a.id = :assignmentId")
	Optional<Assignment> findByIdForUpdate(@Param("assignmentId") String assignmentId);

	@Query("""
	    select a from Assignment a
	    join fetch a.question
	    where a.familyPair.id = :pairId
	      and exists (select r.id from Recording r where r.assignment = a)
	      and exists (select ca.id from ChildAnswer ca where ca.assignment = a)
	    order by a.assignedDate desc, a.id desc
	    """)
	List<Assignment> findRevealedFirstPage(@Param("pairId") String pairId, Pageable pageable);

	@Query("""
	    select a from Assignment a
	    join fetch a.question
	    where a.familyPair.id = :pairId
	      and exists (select r.id from Recording r where r.assignment = a)
	      and exists (select ca.id from ChildAnswer ca where ca.assignment = a)
	      and (a.assignedDate < :cursorDate
	           or (a.assignedDate = :cursorDate and a.id < :cursorId))
	    order by a.assignedDate desc, a.id desc
	    """)
	List<Assignment> findRevealedAfter(@Param("pairId") String pairId, @Param("cursorDate") LocalDate cursorDate,
	    @Param("cursorId") String cursorId, Pageable pageable);

	@Query("""
	    select a from Assignment a
	    join fetch a.question
	    where a.familyPair.id = :pairId
	      and a.assignedDate between :startDate and :endDate
	      and exists (select r.id from Recording r where r.assignment = a)
	      and exists (select ca.id from ChildAnswer ca where ca.assignment = a)
	    order by a.assignedDate asc, a.id asc
	    """)
	List<Assignment> findRevealedByMonth(@Param("pairId") String pairId, @Param("startDate") LocalDate startDate,
	    @Param("endDate") LocalDate endDate);
}
