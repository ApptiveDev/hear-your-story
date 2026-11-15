package com.apptive.backend.domain.user.service;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.common.id.IdGenerator;
import com.apptive.backend.domain.answer.entity.ChildAnswer;
import com.apptive.backend.domain.answer.repository.ChildAnswerRepository;
import com.apptive.backend.domain.auth.repository.RefreshTokenRepository;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.pair.repository.PairInvitationRepository;
import com.apptive.backend.domain.recording.entity.Recording;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.user.dto.AccountDeletionResponse;
import com.apptive.backend.domain.user.entity.AccountDeletionRequest;
import com.apptive.backend.domain.user.entity.AccountDeletionTask;
import com.apptive.backend.domain.user.entity.AccountDeletionTaskType;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.AccountDeletionRequestRepository;
import com.apptive.backend.domain.user.repository.AccountDeletionTaskRepository;
import com.apptive.backend.domain.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
@Service
public class AccountDeletionService {

	private final UserRepository userRepository;
	private final FamilyPairRepository familyPairRepository;
	private final PairInvitationRepository pairInvitationRepository;
	private final RecordingRepository recordingRepository;
	private final ChildAnswerRepository childAnswerRepository;
	private final RefreshTokenRepository refreshTokenRepository;
	private final AccountDeletionRequestRepository deletionRequestRepository;
	private final AccountDeletionTaskRepository deletionTaskRepository;
	private final AuthSubjectHasher authSubjectHasher;
	private final IdGenerator idGenerator;
	private final Clock clock;

	@Transactional
	public AccountDeletionResponse requestDeletion(AuthenticatedUser authenticatedUser) {
		User user = userRepository.findByIdForUpdate(authenticatedUser.userId())
		    .orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));
		if (!user.isActive() || deletionRequestRepository.findByUser_Id(user.getId()).isPresent()) {
			throw new ApiException(ErrorCode.ACCOUNT_DELETION_IN_PROGRESS);
		}

		OffsetDateTime now = OffsetDateTime.now(clock);
		AuthProvider authProvider = user.getAuthProvider();
		String authSubject = user.getAuthSubject();
		String authSubjectHash = authSubject == null ? null : authSubjectHasher.hash(authSubject);
		AccountDeletionRequest request = deletionRequestRepository
		    .save(new AccountDeletionRequest(idGenerator.generate("del"), user, authProvider, authSubjectHash, now));

		familyPairRepository.findActiveByMemberIdForUpdate(user.getId()).ifPresent(pair -> pair.deactivate(now));
		List<String> objectKeys = deleteOwnedAnswers(user.getRole(), user.getId(), now);
		if (createTasks(request, authProvider, authSubject, objectKeys, now) == 0) {
			request.complete(now);
		}

		pairInvitationRepository.deleteAllByChild_Id(user.getId());
		refreshTokenRepository.deleteAllByUser_Id(user.getId());
		user.requestDeletion(now);

		return new AccountDeletionResponse(request.getId(), request.getStatus().name(), request.getRequestedAt());
	}

	private List<String> deleteOwnedAnswers(Role role, String userId, OffsetDateTime now) {
		List<String> objectKeys = new ArrayList<>();
		if (role == Role.PARENT) {
			for (Recording recording : recordingRepository.findAllOwnedByParentForUpdate(userId)) {
				addIfPresent(objectKeys, recording.deletePersonalData(now));
			}
		} else {
			for (ChildAnswer answer : childAnswerRepository.findAllOwnedByChildForUpdate(userId)) {
				addIfPresent(objectKeys, answer.deletePersonalData(now));
			}
		}
		return objectKeys;
	}

	private int createTasks(AccountDeletionRequest request, AuthProvider authProvider, String authSubject,
	    List<String> objectKeys, OffsetDateTime now) {
		List<AccountDeletionTask> tasks = new ArrayList<>();
		for (String objectKey : objectKeys) {
			tasks.add(new AccountDeletionTask(idGenerator.generate("dtk"), request,
			    AccountDeletionTaskType.STORAGE_OBJECT, objectKey, now));
		}
		if (authProvider == AuthProvider.KAKAO && authSubject != null) {
			tasks.add(new AccountDeletionTask(idGenerator.generate("dtk"), request,
			    AccountDeletionTaskType.KAKAO_UNLINK, authSubject, now));
		}
		deletionTaskRepository.saveAll(tasks);
		return tasks.size();
	}

	private void addIfPresent(List<String> objectKeys, String objectKey) {
		if (objectKey != null && !objectKey.isBlank()) {
			objectKeys.add(objectKey);
		}
	}
}
