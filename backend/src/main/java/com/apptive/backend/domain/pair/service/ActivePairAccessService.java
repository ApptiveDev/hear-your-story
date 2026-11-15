package com.apptive.backend.domain.pair.service;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.domain.pair.entity.FamilyPair;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Service
public class ActivePairAccessService {

	private final UserRepository userRepository;
	private final FamilyPairRepository familyPairRepository;

	@Transactional(propagation = Propagation.MANDATORY)
	public FamilyPair lockForSubmission(AuthenticatedUser authenticatedUser) {
		User user = userRepository.findByIdForUpdate(authenticatedUser.userId())
		    .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));
		if (!user.isActive()) {
			throw new ApiException(ErrorCode.UNAUTHORIZED);
		}
		return familyPairRepository.findActiveByMemberIdForUpdate(user.getId())
		    .orElseThrow(() -> new ApiException(ErrorCode.PAIR_ACCESS_DENIED));
	}
}
