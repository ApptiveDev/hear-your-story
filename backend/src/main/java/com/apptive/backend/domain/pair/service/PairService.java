package com.apptive.backend.domain.pair.service;

import java.time.Clock;
import java.time.OffsetDateTime;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;
import com.apptive.backend.common.id.IdGenerator;
import com.apptive.backend.domain.pair.dto.InvitationResponse;
import com.apptive.backend.domain.pair.dto.JoinPairResponse;
import com.apptive.backend.domain.pair.dto.PairMemberResponse;
import com.apptive.backend.domain.pair.dto.PairResponse;
import com.apptive.backend.domain.pair.entity.FamilyPair;
import com.apptive.backend.domain.pair.entity.PairInvitation;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.pair.repository.PairInvitationRepository;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;

@Service
public class PairService {

	private static final int INVITATION_VALID_HOURS = 24;
	private static final int MAX_CODE_GENERATION_ATTEMPTS = 20;

	private final UserRepository userRepository;
	private final FamilyPairRepository familyPairRepository;
	private final PairInvitationRepository invitationRepository;
	private final InviteCodeGenerator inviteCodeGenerator;
	private final IdGenerator idGenerator;
	private final Clock clock;

	public PairService(UserRepository userRepository, FamilyPairRepository familyPairRepository,
	    PairInvitationRepository invitationRepository, InviteCodeGenerator inviteCodeGenerator, IdGenerator idGenerator,
	    Clock clock) {
		this.userRepository = userRepository;
		this.familyPairRepository = familyPairRepository;
		this.invitationRepository = invitationRepository;
		this.inviteCodeGenerator = inviteCodeGenerator;
		this.idGenerator = idGenerator;
		this.clock = clock;
	}

	@Transactional
	public InvitationResponse createInvitation(AuthenticatedUser authenticatedUser) {
		requireRole(authenticatedUser, Role.CHILD);
		User child = findUser(authenticatedUser.userId());
		if (familyPairRepository.existsByMemberId(child.getId())) {
			throw new ApiException(ErrorCode.ALREADY_PAIRED);
		}

		OffsetDateTime now = OffsetDateTime.now(clock);
		PairInvitation invitation = invitationRepository
		    .findFirstByChild_IdAndUsedAtIsNullAndExpiresAtAfterOrderByCreatedAtDesc(child.getId(), now)
		    .orElseGet(() -> invitationRepository.save(new PairInvitation(idGenerator.generate("inv"), child,
		        generateUniqueCode(), now.plusHours(INVITATION_VALID_HOURS), now)));
		return toInvitationResponse(invitation);
	}

	@Transactional
	public JoinPairResponse join(AuthenticatedUser authenticatedUser, String inviteCode) {
		requireRole(authenticatedUser, Role.PARENT);
		User parent = findUser(authenticatedUser.userId());
		if (familyPairRepository.existsByMemberId(parent.getId())) {
			throw new ApiException(ErrorCode.ALREADY_PAIRED);
		}

		PairInvitation invitation = invitationRepository.findByInviteCodeForUpdate(inviteCode)
		    .orElseThrow(() -> new ApiException(ErrorCode.INVITE_CODE_NOT_FOUND));
		if (invitation.getUsedAt() != null) {
			throw new ApiException(ErrorCode.INVITE_CODE_USED);
		}

		OffsetDateTime now = OffsetDateTime.now(clock);
		if (!invitation.getExpiresAt().isAfter(now)) {
			throw new ApiException(ErrorCode.INVITE_CODE_EXPIRED);
		}
		User child = invitation.getChild();
		if (familyPairRepository.existsByMemberId(child.getId())) {
			throw new ApiException(ErrorCode.ALREADY_PAIRED);
		}

		FamilyPair pair = familyPairRepository.save(new FamilyPair(idGenerator.generate("pair"), parent, child, now));
		invitation.markUsed(now);
		return new JoinPairResponse(toPairResponse(pair));
	}

	private User findUser(String userId) {
		return userRepository.findById(userId).orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));
	}

	private void requireRole(AuthenticatedUser user, Role requiredRole) {
		if (user.role() != requiredRole) {
			throw new ApiException(ErrorCode.ROLE_NOT_ALLOWED);
		}
	}

	private String generateUniqueCode() {
		for (int attempt = 0; attempt < MAX_CODE_GENERATION_ATTEMPTS; attempt++) {
			String code = inviteCodeGenerator.generate();
			if (!invitationRepository.existsByInviteCode(code)) {
				return code;
			}
		}
		throw new IllegalStateException("Unable to generate a unique invite code");
	}

	private InvitationResponse toInvitationResponse(PairInvitation invitation) {
		return new InvitationResponse(invitation.getId(), invitation.getInviteCode(), invitation.getExpiresAt());
	}

	private PairResponse toPairResponse(FamilyPair pair) {
		return new PairResponse(pair.getId(),
		    new PairMemberResponse(pair.getParent().getId(), pair.getParent().getName()),
		    new PairMemberResponse(pair.getChild().getId(), pair.getChild().getName()), pair.getPairedAt());
	}
}
