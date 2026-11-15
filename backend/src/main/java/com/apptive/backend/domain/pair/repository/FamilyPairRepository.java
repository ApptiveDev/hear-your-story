package com.apptive.backend.domain.pair.repository;

import java.util.Optional;

import jakarta.persistence.LockModeType;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.apptive.backend.domain.pair.entity.FamilyPair;

public interface FamilyPairRepository extends JpaRepository<FamilyPair, String> {

	@Query("select (count(p) > 0) from FamilyPair p where p.deactivatedAt is null and (p.parent.id = :userId or p.child.id = :userId)")
	boolean existsActiveByMemberId(@Param("userId") String userId);

	@Query("select (count(p) > 0) from FamilyPair p where p.parent.id = :userId or p.child.id = :userId")
	boolean existsAnyByMemberId(@Param("userId") String userId);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select p from FamilyPair p where p.deactivatedAt is null and (p.parent.id = :userId or p.child.id = :userId)")
	Optional<FamilyPair> findActiveByMemberIdForUpdate(@Param("userId") String userId);
}
