package com.apptive.backend.domain.health.controller;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;

import org.junit.jupiter.api.Test;

class HealthControllerSmokeTest {

	@Test
	void healthUsesProvidedClock() {
		Clock clock = Clock.fixed(Instant.parse("2026-11-03T00:00:00Z"), ZoneId.of("Asia/Seoul"));
		var response = new HealthController(clock).health();

		assertThat(response.status()).isEqualTo("UP");
		assertThat(response.timestamp().toString()).isEqualTo("2026-11-03T09:00+09:00");
	}
}
