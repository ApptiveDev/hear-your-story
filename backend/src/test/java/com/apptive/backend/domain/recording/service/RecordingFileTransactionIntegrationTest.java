package com.apptive.backend.domain.recording.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.concurrent.atomic.AtomicInteger;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import com.apptive.backend.common.auth.AuthenticatedUser;
import com.apptive.backend.domain.assignment.entity.Assignment;
import com.apptive.backend.domain.assignment.repository.AssignmentRepository;
import com.apptive.backend.domain.pair.entity.FamilyPair;
import com.apptive.backend.domain.pair.repository.FamilyPairRepository;
import com.apptive.backend.domain.question.entity.Question;
import com.apptive.backend.domain.question.repository.QuestionRepository;
import com.apptive.backend.domain.recording.entity.Recording;
import com.apptive.backend.domain.recording.repository.RecordingRepository;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;
import com.apptive.backend.domain.user.repository.UserRepository;
import com.apptive.backend.infra.storage.RecordingStorage;

@SpringBootTest
@ActiveProfiles("test")
class RecordingFileTransactionIntegrationTest {

	private static final String OLD_OBJECT_KEY = "recordings/rec_transaction/old.m4a";
	private static final String NEW_OBJECT_KEY = "recordings/rec_transaction/new.m4a";
	private static final AtomicInteger TEST_SEQUENCE = new AtomicInteger();

	@Autowired
	private RecordingUploadService recordingUploadService;

	@Autowired
	private RecordingRepository recordingRepository;

	@Autowired
	private AssignmentRepository assignmentRepository;

	@Autowired
	private FamilyPairRepository familyPairRepository;

	@Autowired
	private UserRepository userRepository;

	@Autowired
	private QuestionRepository questionRepository;

	@Autowired
	private PlatformTransactionManager transactionManager;

	@Autowired
	private Clock clock;

	@MockitoBean
	private RecordingStorage recordingStorage;

	@MockitoBean
	private RecordingProcessor recordingProcessor;

	private AuthenticatedUser authenticatedParent;
	private String assignmentId;
	private String recordingId;
	private String pairId;
	private String parentId;
	private String childId;
	private String questionId;

	@BeforeEach
	void setUp() {
		int sequence = TEST_SEQUENCE.incrementAndGet();
		String suffix = Integer.toString(sequence);
		TransactionTemplate transaction = new TransactionTemplate(transactionManager);
		transaction.executeWithoutResult(status -> {
			OffsetDateTime now = OffsetDateTime.now(clock);
			User parent = userRepository.save(
			    new User("usr_transaction_parent_" + suffix, "부모", Role.PARENT, "transaction-parent-" + suffix, now));
			User child = userRepository.save(
			    new User("usr_transaction_child_" + suffix, "자녀", Role.CHILD, "transaction-child-" + suffix, now));
			FamilyPair pair = familyPairRepository
			    .save(new FamilyPair("pair_transaction_" + suffix, parent, child, now));
			LocalDate assignedDate = LocalDate.of(2090, 1, 1).plusDays(sequence);
			questionId = "qst_transaction_" + suffix;
			Question question = questionRepository
			    .save(new Question(questionId, assignedDate, "기억하고 싶은 일은 무엇인가요?", "DAILY", null, true));
			Assignment assignment = assignmentRepository
			    .save(new Assignment("asg_transaction_" + suffix, pair, question, assignedDate, now));
			recordingId = "rec_transaction_" + suffix;
			recordingRepository.save(new Recording(recordingId, assignment, OLD_OBJECT_KEY, "old.m4a", "audio/mp4", 12,
			    "old-key", "old-version", now));

			authenticatedParent = new AuthenticatedUser(parent.getId(), parent.getRole());
			assignmentId = assignment.getId();
			pairId = pair.getId();
			parentId = parent.getId();
			childId = child.getId();
		});
	}

	@AfterEach
	void cleanUp() {
		TransactionTemplate transaction = new TransactionTemplate(transactionManager);
		transaction.executeWithoutResult(status -> {
			recordingRepository.deleteById(recordingId);
			assignmentRepository.deleteById(assignmentId);
			familyPairRepository.deleteById(pairId);
			userRepository.deleteById(parentId);
			userRepository.deleteById(childId);
			questionRepository.deleteById(questionId);
		});
	}

	@Test
	void rollbackKeepsPreviousFileAndDeletesNewFile() {
		when(recordingStorage.store(eq(recordingId), any())).thenReturn(NEW_OBJECT_KEY);

		TransactionTemplate transaction = new TransactionTemplate(transactionManager);
		transaction.executeWithoutResult(status -> {
			recordingUploadService.put(assignmentId, validAudio(), "new-key", authenticatedParent);
			status.setRollbackOnly();
		});

		verify(recordingStorage, never()).delete(OLD_OBJECT_KEY);
		verify(recordingStorage).delete(NEW_OBJECT_KEY);
		assertThat(recordingRepository.findById(recordingId).orElseThrow().getObjectKey()).isEqualTo(OLD_OBJECT_KEY);
	}

	@Test
	void commitDeletesPreviousFileAndKeepsNewFile() {
		when(recordingStorage.store(eq(recordingId), any())).thenReturn(NEW_OBJECT_KEY);

		TransactionTemplate transaction = new TransactionTemplate(transactionManager);
		transaction.executeWithoutResult(
		    status -> recordingUploadService.put(assignmentId, validAudio(), "new-key", authenticatedParent));

		verify(recordingStorage).delete(OLD_OBJECT_KEY);
		verify(recordingStorage, never()).delete(NEW_OBJECT_KEY);
		assertThat(recordingRepository.findById(recordingId).orElseThrow().getObjectKey()).isEqualTo(NEW_OBJECT_KEY);
	}

	private MockMultipartFile validAudio() {
		return new MockMultipartFile("audioFile", "new.m4a", "audio/mp4",
		    new byte[]{0, 0, 0, 16, 'f', 't', 'y', 'p', 'M', '4', 'A', ' '});
	}
}
