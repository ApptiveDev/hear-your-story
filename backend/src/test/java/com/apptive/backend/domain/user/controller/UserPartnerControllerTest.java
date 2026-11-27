package com.apptive.backend.domain.user.controller;

import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Clock;
import java.time.OffsetDateTime;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import com.apptive.backend.common.auth.JwtTokenProvider;
import com.apptive.backend.domain.pair.entity.FamilyPair;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class UserPartnerControllerTest {

	@Autowired
	private MockMvc mockMvc;
	@Autowired
	private UserRepository users;
	@Autowired
	private FamilyPairRepository pairs;
	@Autowired
	private JwtTokenProvider tokens;
	@Autowired
	private Clock clock;

	@Test
	void bothMembersReceiveOnlyTheirPartnersName() throws Exception {
		User parent = user("usr_partner_parent", "영희", Role.PARENT);
		User child = user("usr_partner_child", "민수", Role.CHILD);
		pairs.save(new FamilyPair("pair_partner", parent, child, OffsetDateTime.now(clock)));
		assertPartner(parent, "민수");
		assertPartner(child, "영희");
	}

	@Test
	void unpairedUserCannotReadAnotherPairsName() throws Exception {
		User parent = user("usr_other_parent", "다른부모", Role.PARENT);
		User child = user("usr_other_child", "다른자녀", Role.CHILD);
		pairs.save(new FamilyPair("pair_other", parent, child, OffsetDateTime.now(clock)));
		User viewer = user("usr_unpaired_viewer", "조회자", Role.PARENT);
		assertUnpaired(viewer);
	}

	@Test
	void deactivatedPairDoesNotExposeFormerPartnersName() throws Exception {
		User parent = user("usr_former_parent", "영희", Role.PARENT);
		User child = user("usr_former_child", "민수", Role.CHILD);
		FamilyPair pair = pairs.save(new FamilyPair("pair_former", parent, child, OffsetDateTime.now(clock)));
		pair.deactivate(OffsetDateTime.now(clock));
		assertUnpaired(parent);
		assertUnpaired(child);
	}

	@Test
	void nextLookupReturnsRenamedPartnerAndNewPairOnly() throws Exception {
		User parent = user("usr_repaired_parent", "영희", Role.PARENT);
		User oldChild = user("usr_old_child", "이전자녀", Role.CHILD);
		FamilyPair oldPair = pairs.save(new FamilyPair("pair_old", parent, oldChild, OffsetDateTime.now(clock)));
		oldPair.deactivate(OffsetDateTime.now(clock));
		pairs.flush();
		User child = user("usr_new_child", "새자녀", Role.CHILD);
		pairs.save(new FamilyPair("pair_new", parent, child, OffsetDateTime.now(clock)));
		child.renameTo("바뀐이름");
		assertPartner(parent, "바뀐이름");
		assertUnpaired(oldChild);
	}

	@Test
	void anonymousRequestCannotReadPartner() throws Exception {
		mockMvc.perform(get("/api/v1/users/me")).andExpect(status().isUnauthorized());
	}

	private User user(String id, String name, Role role) {
		return users.save(new User(id, name, role, AuthProvider.KAKAO, id, OffsetDateTime.now(clock)));
	}

	private void assertPartner(User user, String name) throws Exception {
		mockMvc
		    .perform(get("/api/v1/users/me").header("Authorization",
		        "Bearer " + tokens.issue(user.getId(), user.getRole()).value()))
		    .andExpect(status().isOk()).andExpect(jsonPath("$.pairingStatus").value("PAIRED"))
		    .andExpect(jsonPath("$.partnerName").value(name));
	}

	private void assertUnpaired(User user) throws Exception {
		mockMvc
		    .perform(get("/api/v1/users/me").header("Authorization",
		        "Bearer " + tokens.issue(user.getId(), user.getRole()).value()))
		    .andExpect(status().isOk()).andExpect(jsonPath("$.pairingStatus").value("UNPAIRED"))
		    .andExpect(jsonPath("$.partnerName").value(nullValue()));
	}
}
