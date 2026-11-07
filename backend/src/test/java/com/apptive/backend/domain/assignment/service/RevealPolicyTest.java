package com.apptive.backend.domain.assignment.service;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

import com.apptive.backend.domain.assignment.entity.RevealStatus;
import com.apptive.backend.domain.assignment.entity.SubmissionStatus;

class RevealPolicyTest {

	private final RevealPolicy revealPolicy = new RevealPolicy();

	@Test
	void resolvesMutualSubmissionStates() {
		assertThat(revealPolicy.resolve(SubmissionStatus.NOT_SUBMITTED, SubmissionStatus.NOT_SUBMITTED))
		    .isEqualTo(RevealStatus.WAITING_FOR_BOTH);
		assertThat(revealPolicy.resolve(SubmissionStatus.SUBMITTED, SubmissionStatus.NOT_SUBMITTED))
		    .isEqualTo(RevealStatus.WAITING_FOR_CHILD);
		assertThat(revealPolicy.resolve(SubmissionStatus.NOT_SUBMITTED, SubmissionStatus.SUBMITTED))
		    .isEqualTo(RevealStatus.WAITING_FOR_PARENT);
		assertThat(revealPolicy.resolve(SubmissionStatus.SUBMITTED, SubmissionStatus.SUBMITTED))
		    .isEqualTo(RevealStatus.REVEALED);
	}

	@Test
	void skippedDoesNotRevealBeforePolicyIsDecided() {
		assertThat(revealPolicy.resolve(SubmissionStatus.SKIPPED, SubmissionStatus.SUBMITTED))
		    .isEqualTo(RevealStatus.WAITING_FOR_PARENT);
		assertThat(revealPolicy.resolve(SubmissionStatus.SUBMITTED, SubmissionStatus.SKIPPED))
		    .isEqualTo(RevealStatus.WAITING_FOR_CHILD);
	}
}
