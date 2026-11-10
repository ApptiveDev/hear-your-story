package com.apptive.backend.domain.answer.service;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.domain.answer.dto.AnswerAudioResponse;
import com.apptive.backend.domain.answer.entity.ChildAnswer;
import com.apptive.backend.domain.answer.entity.TtsStatus;
import com.apptive.backend.domain.answer.repository.ChildAnswerRepository;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.infra.storage.RecordingStorage;
import com.apptive.backend.infra.storage.SignedAudioUrl;

import lombok.RequiredArgsConstructor;

@Transactional(readOnly = true)
@RequiredArgsConstructor
@Service
public class AnswerAudioService {

	private final ChildAnswerRepository childAnswerRepository;
	private final RecordingRepository recordingRepository;
	private final RecordingStorage recordingStorage;

	public AnswerAudioResponse get(String answerId, AuthenticatedUser authenticatedUser) {
		if (authenticatedUser.role() != Role.PARENT) {
			throw new ApiException(ErrorCode.ROLE_NOT_ALLOWED);
		}
		ChildAnswer answer = childAnswerRepository.findByIdWithAssignment(answerId)
		    .orElseThrow(() -> new ApiException(ErrorCode.RESOURCE_NOT_FOUND));
		if (!answer.getAssignment().belongsToParent(authenticatedUser.userId())) {
			throw new ApiException(ErrorCode.PAIR_ACCESS_DENIED);
		}
		if (recordingRepository.findByAssignment_Id(answer.getAssignment().getId()).isEmpty()) {
			throw new ApiException(ErrorCode.PAIR_ACCESS_DENIED);
		}

		SignedAudioUrl signedAudio = null;
		if (answer.getTtsStatus() == TtsStatus.READY && answer.getTtsObjectKey() != null) {
			signedAudio = recordingStorage.createSignedReadUrl(answer.getTtsObjectKey()).orElse(null);
		}
		return new AnswerAudioResponse(answer.getId(), answer.getTtsStatus(),
		    signedAudio == null ? null : signedAudio.url(), signedAudio == null ? null : signedAudio.expiresAt(),
		    answer.getTtsProcessingNotice());
	}
}
