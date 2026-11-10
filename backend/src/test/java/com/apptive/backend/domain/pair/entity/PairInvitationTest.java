package com.apptive.backend.domain.pair.entity;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;

import org.junit.jupiter.api.Test;

import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;

class PairInvitationTest {

	@Test
	void determinesWhetherInvitationIsUsedOrExpired() {
		OffsetDateTime now = OffsetDateTime.parse("2026-11-10T10:00:00+09:00");
		User child = new User("usr_child", "자녀", Role.CHILD, "child-device", now);
		PairInvitation invitation = new PairInvitation("inv_1", child, "123456", now.plusHours(1), now);

		assertThat(invitation.isUsed()).isFalse();
		assertThat(invitation.isExpiredAt(now)).isFalse();
		assertThat(invitation.isExpiredAt(now.plusHours(1))).isTrue();

		invitation.markUsed(now.plusMinutes(1));

		assertThat(invitation.isUsed()).isTrue();
	}
}
