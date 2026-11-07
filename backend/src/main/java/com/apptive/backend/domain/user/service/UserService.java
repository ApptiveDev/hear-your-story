package com.apptive.backend.domain.user.service;

import java.time.Clock;
import java.time.OffsetDateTime;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.IssuedToken;
import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.common.id.IdGenerator;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.user.dto.CreateUserRequest;
import com.apptive.backend.domain.user.dto.CreateUserResponse;
import com.apptive.backend.domain.user.dto.UserResponse;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;

@Service
public class UserService {

	private final UserRepository userRepository;
	private final FamilyPairRepository familyPairRepository;
	private final JwtTokenProvider tokenProvider;
	private final IdGenerator idGenerator;
	private final Clock clock;

	public UserService(UserRepository userRepository, FamilyPairRepository familyPairRepository,
	    JwtTokenProvider tokenProvider, IdGenerator idGenerator, Clock clock) {
		this.userRepository = userRepository;
		this.familyPairRepository = familyPairRepository;
		this.tokenProvider = tokenProvider;
		this.idGenerator = idGenerator;
		this.clock = clock;
	}

	@Transactional
	public UserRegistrationResult register(CreateUserRequest request) {
		String deviceId = request.deviceId().trim();
		User existingUser = userRepository.findByDeviceIdAndRole(deviceId, request.role()).orElse(null);
		boolean created = existingUser == null;
		User user = created
		    ? userRepository.save(new User(idGenerator.generate("usr"), request.name().trim(), request.role(), deviceId,
		        OffsetDateTime.now(clock)))
		    : existingUser;

		IssuedToken issuedToken = tokenProvider.issue(user.getId(), user.getRole());
		String pairingStatus = familyPairRepository.existsByMemberId(user.getId()) ? "PAIRED" : "UNPAIRED";
		return new UserRegistrationResult(
		    new CreateUserResponse(new UserResponse(user.getId(), user.getName(), user.getRole(), pairingStatus),
		        issuedToken.value(), "Bearer", issuedToken.expiresAt()),
		    created);
	}
}
