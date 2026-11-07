package com.apptive.backend.domain.recording.service;

import java.io.IOException;
import java.io.InputStream;
import java.util.Locale;
import java.util.Set;

import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;

@Component
public class AudioFileValidator {

	private static final long MAX_SIZE_BYTES = 10L * 1024 * 1024;
	private static final Set<String> ALLOWED_CONTENT_TYPES = Set.of("audio/mp4", "audio/m4a", "audio/aac");

	public void validate(MultipartFile file) {
		if (file == null || file.isEmpty()) {
			throw new ApiException(ErrorCode.INVALID_AUDIO_FORMAT);
		}
		if (file.getSize() > MAX_SIZE_BYTES) {
			throw new ApiException(ErrorCode.AUDIO_FILE_TOO_LARGE);
		}

		String filename = file.getOriginalFilename();
		String contentType = file.getContentType();
		if (filename == null || !filename.toLowerCase(Locale.ROOT).endsWith(".m4a") || contentType == null
		    || !ALLOWED_CONTENT_TYPES.contains(contentType.toLowerCase(Locale.ROOT)) || !hasIsoBaseMediaHeader(file)) {
			throw new ApiException(ErrorCode.INVALID_AUDIO_FORMAT);
		}
	}

	private boolean hasIsoBaseMediaHeader(MultipartFile file) {
		byte[] header = new byte[8];
		try (InputStream input = file.getInputStream()) {
			if (input.read(header) < header.length) {
				return false;
			}
			return header[4] == 'f' && header[5] == 't' && header[6] == 'y' && header[7] == 'p';
		} catch (IOException exception) {
			throw new ApiException(ErrorCode.INVALID_AUDIO_FORMAT);
		}
	}
}
