package com.apptive.backend.domain.pair.repository;

import java.time.OffsetDateTime;
import java.util.Optional;

import jakarta.persistence.LockModeType;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.apptive.backend.domain.pair.entity.PairInvitation;

public interface PairInvitationRepository extends JpaRepository<PairInvitation, String> {

	Optional<PairInvitation> findFirstByChild_IdAndUsedAtIsNullAndExpiresAtAfterOrderByCreatedAtDesc(String childId,
	    OffsetDateTime now);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select i from PairInvitation i join fetch i.child where i.inviteCode = :inviteCode")
	Optional<PairInvitation> findByInviteCodeForUpdate(@Param("inviteCode") String inviteCode);

	boolean existsByInviteCode(String inviteCode);
}
