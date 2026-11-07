package com.apptive.backend.domain.answer.service;

import java.time.Clock;
import java.time.OffsetDateTime;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.domain.answer.entity.ChildAnswer;
import com.apptive.backend.domain.answer.repository.ChildAnswerRepository;

@Service
public class AnswerTtsStatusService {

	private static final String FAILURE_NOTICE = "음성 만들기에 실패했습니다. 글로는 계속 확인할 수 있어요.";

	private final ChildAnswerRepository childAnswerRepository;
	private final Clock clock;

	public AnswerTtsStatusService(ChildAnswerRepository childAnswerRepository, Clock clock) {
		this.childAnswerRepository = childAnswerRepository;
		this.clock = clock;
	}

	@Transactional(readOnly = true, propagation = Propagation.REQUIRES_NEW)
	public AnswerTtsSource findSource(String answerId, String ttsVersion) {
		return childAnswerRepository.findById(answerId).filter(answer -> answer.hasTtsVersion(ttsVersion))
		    .map(answer -> new AnswerTtsSource(answer.getText())).orElse(null);
	}

	@Transactional(propagation = Propagation.REQUIRES_NEW)
	public TtsReadyResult markReady(String answerId, String ttsVersion, String objectKey) {
		ChildAnswer answer = childAnswerRepository.findByIdForUpdate(answerId).orElse(null);
		if (answer == null || !answer.hasTtsVersion(ttsVersion)) {
			return TtsReadyResult.stale();
		}
		String previousObjectKey = answer.markTtsReady(objectKey, OffsetDateTime.now(clock));
		return TtsReadyResult.accepted(previousObjectKey);
	}

	@Transactional(propagation = Propagation.REQUIRES_NEW)
	public void markFailed(String answerId, String ttsVersion) {
		childAnswerRepository.findByIdForUpdate(answerId).filter(answer -> answer.hasTtsVersion(ttsVersion))
		    .ifPresent(answer -> answer.markTtsFailed(FAILURE_NOTICE, OffsetDateTime.now(clock)));
	}
}
