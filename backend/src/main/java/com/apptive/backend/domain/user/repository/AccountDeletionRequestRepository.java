package com.apptive.backend.domain.user.repository;

import java.util.Optional;

import jakarta.persistence.LockModeType;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.apptive.backend.domain.user.entity.AccountDeletionRequest;
import com.apptive.backend.domain.user.entity.AccountDeletionStatus;
import com.apptive.backend.domain.user.entity.AuthProvider;

public interface AccountDeletionRequestRepository extends JpaRepository<AccountDeletionRequest, String> {

	Optional<AccountDeletionRequest> findByUser_Id(String userId);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select request from AccountDeletionRequest request join fetch request.user where request.id = :requestId")
	Optional<AccountDeletionRequest> findByIdForUpdate(@Param("requestId") String requestId);

	boolean existsByAuthProviderAndAuthSubjectHashAndStatus(AuthProvider authProvider, String authSubjectHash,
	    AccountDeletionStatus status);
}
