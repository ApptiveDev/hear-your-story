package com.apptive.backend.domain.assignment.entity;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import java.time.OffsetDateTime;

import org.junit.jupiter.api.Test;

import com.apptive.backend.domain.pair.entity.FamilyPair;
import com.apptive.backend.domain.question.entity.Question;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;

class AssignmentTest {

	@Test
	void determinesParentAndChildOwnershipThroughFamilyPair() {
		OffsetDateTime now = OffsetDateTime.parse("2026-11-10T10:00:00+09:00");
		User parent = new User("usr_parent", "부모", Role.PARENT, "parent-device", now);
		User child = new User("usr_child", "자녀", Role.CHILD, "child-device", now);
		FamilyPair pair = new FamilyPair("pair_1", parent, child, now);
		Question question = new Question("qst_1", LocalDate.of(2026, 11, 10), "질문", "DAILY", null, true);
		Assignment assignment = new Assignment("asg_1", pair, question, LocalDate.of(2026, 11, 10), now);

		assertThat(pair.hasParent(parent.getId())).isTrue();
		assertThat(pair.hasChild(child.getId())).isTrue();
		assertThat(assignment.belongsToParent(parent.getId())).isTrue();
		assertThat(assignment.belongsToChild(child.getId())).isTrue();
		assertThat(assignment.belongsToParent(child.getId())).isFalse();
		assertThat(assignment.belongsToChild(parent.getId())).isFalse();
	}
}
