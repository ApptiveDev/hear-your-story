package com.apptive.backend.domain.story.service;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.Base64;

import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;

record StoryCursor(LocalDate assignedDate, String assignmentId) {

	static StoryCursor decode(String encoded) {
		if (encoded == null || encoded.isBlank()) {
			return null;
		}
		try {
			String decoded = new String(Base64.getUrlDecoder().decode(encoded), StandardCharsets.UTF_8);
			int separator = decoded.indexOf(':');
			if (separator <= 0 || separator == decoded.length() - 1) {
				throw new IllegalArgumentException("invalid cursor payload");
			}
			return new StoryCursor(LocalDate.parse(decoded.substring(0, separator)), decoded.substring(separator + 1));
		} catch (IllegalArgumentException | DateTimeParseException exception) {
			throw new ApiException(ErrorCode.VALIDATION_ERROR);
		}
	}

	String encode() {
		String raw = assignedDate + ":" + assignmentId;
		return Base64.getUrlEncoder().withoutPadding().encodeToString(raw.getBytes(StandardCharsets.UTF_8));
	}
}
