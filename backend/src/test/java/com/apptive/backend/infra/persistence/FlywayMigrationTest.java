package com.apptive.backend.infra.persistence;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class FlywayMigrationTest {

	private static final List<String> TABLES = List.of("APP_USERS", "FAMILY_PAIRS", "PAIR_INVITATIONS", "QUESTIONS",
	    "ASSIGNMENTS", "CHILD_ANSWERS", "RECORDINGS");

	@Autowired
	private Flyway flyway;

	@Autowired
	private JdbcTemplate jdbcTemplate;

	@Test
	void appliesInitialSchemaAndPassesValidation() {
		assertThat(flyway.info().current().getVersion().getVersion()).isEqualTo("2");
		assertThat(flyway.validateWithResult().validationSuccessful).isTrue();

		List<String> migratedTables = jdbcTemplate.queryForList("""
		    select table_name
		    from information_schema.tables
		    where table_schema = 'PUBLIC'
		      and table_name in ('APP_USERS', 'FAMILY_PAIRS', 'PAIR_INVITATIONS', 'QUESTIONS',
		                         'ASSIGNMENTS', 'CHILD_ANSWERS', 'RECORDINGS')
		    """, String.class);
		assertThat(migratedTables).containsExactlyInAnyOrderElementsOf(TABLES);
	}
}
