package com.apptive.backend.domain.user.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.apptive.backend.domain.user.entity.AccountDeletionRequest;
import com.apptive.backend.domain.user.entity.AccountDeletionStatus;
import com.apptive.backend.domain.user.entity.AuthProvider;

public interface AccountDeletionRequestRepository extends JpaRepository<AccountDeletionRequest, String> {

	Optional<AccountDeletionRequest> findByUser_Id(String userId);

	boolean existsByAuthProviderAndAuthSubjectHashAndStatus(AuthProvider authProvider, String authSubjectHash,
	    AccountDeletionStatus status);
}
