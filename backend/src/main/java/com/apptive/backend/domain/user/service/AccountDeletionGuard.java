package com.apptive.backend.domain.user.service;

import org.springframework.stereotype.Component;

import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.domain.user.entity.AccountDeletionStatus;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.repository.AccountDeletionRequestRepository;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Component
public class AccountDeletionGuard {

	private final AccountDeletionRequestRepository deletionRequestRepository;
	private final AuthSubjectHasher authSubjectHasher;

	public void requireNotProcessing(AuthProvider authProvider, String authSubject) {
		String authSubjectHash = authSubjectHasher.hash(authSubject);
		if (deletionRequestRepository.existsByAuthProviderAndAuthSubjectHashAndStatus(authProvider, authSubjectHash,
		    AccountDeletionStatus.PROCESSING)) {
			throw new ApiException(ErrorCode.ACCOUNT_DELETION_IN_PROGRESS);
		}
	}
}
