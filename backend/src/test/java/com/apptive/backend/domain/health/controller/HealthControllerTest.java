package com.apptive.backend.domain.health.controller;

import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.matchesPattern;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class HealthControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@Test
	void healthIsPublicAndReturnsContractResponse() throws Exception {
		mockMvc.perform(get("/api/v1/health")).andExpect(status().isOk()).andExpect(header().exists("X-Trace-Id"))
		    .andExpect(jsonPath("$.status").value("UP")).andExpect(jsonPath("$.timestamp")
		        .value(matchesPattern("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?\\+09:00$")));
	}

	@Test
	void protectedEndpointWithoutTokenReturnsCommonErrorResponse() throws Exception {
		mockMvc.perform(get("/api/v1/today")).andExpect(status().isUnauthorized())
		    .andExpect(header().exists("X-Trace-Id")).andExpect(jsonPath("$.status").value(401))
		    .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"))
		    .andExpect(jsonPath("$.message").value("인증이 필요합니다.")).andExpect(jsonPath("$.path").value("/api/v1/today"))
		    .andExpect(jsonPath("$.traceId").isNotEmpty()).andExpect(jsonPath("$.fieldErrors", empty()));
	}
}
