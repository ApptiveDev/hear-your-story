package com.apptive.backend.domain.user.entity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalArgumentException;

import java.time.OffsetDateTime;

import org.junit.jupiter.api.Test;

class UserTest {

	private static final OffsetDateTime NOW = OffsetDateTime.parse("2026-11-22T23:00:00+09:00");

	@Test
	void renamesWithNormalizedName() {
		User user = new User("usr_parent", "기존 이름", Role.PARENT, "device", NOW);

		user.renameTo("  새 이름  ");

		assertThat(user.getName()).isEqualTo("새 이름");
	}

	@Test
	void countsEmojiAsUserPerceivedCharacters() {
		User user = new User("usr_parent", "김영희😊😊😊😊", Role.PARENT, "device", NOW);

		user.renameTo("가👨‍👩‍👧‍👦");

		assertThat(user.getName()).isEqualTo("가👨‍👩‍👧‍👦");
	}

	@Test
	void rejectsInvalidNameAtEntityBoundary() {
		User user = new User("usr_parent", "기존 이름", Role.PARENT, "device", NOW);

		assertThatIllegalArgumentException().isThrownBy(() -> user.renameTo("   "));
		assertThatIllegalArgumentException().isThrownBy(() -> user.renameTo("열한글자이름입니다요오"));
		assertThat(user.getName()).isEqualTo("기존 이름");
	}
}
