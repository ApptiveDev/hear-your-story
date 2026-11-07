package com.apptive.backend.infra.storage;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Optional;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import com.apptive.backend.common.exception.ApiException;
import com.apptive.backend.common.exception.ErrorCode;

@Component
@ConditionalOnProperty(name = "app.storage.type", havingValue = "local", matchIfMissing = true)
public class LocalRecordingStorage implements RecordingStorage {

	private final Path rootDirectory;

	public LocalRecordingStorage(
	    @Value("${app.storage.local-directory:${java.io.tmpdir}/4team-recordings}") String rootDirectory) {
		this.rootDirectory = Path.of(rootDirectory).toAbsolutePath().normalize();
	}

	@Override
	public byte[] read(String objectKey) {
		try {
			return Files.readAllBytes(resolveSafely(objectKey));
		} catch (IOException exception) {
			throw new ApiException(ErrorCode.STORAGE_ERROR);
		}
	}

	@Override
	public Optional<SignedAudioUrl> createSignedReadUrl(String objectKey) {
		return Optional.empty();
	}

	@Override
	public String store(String recordingId, MultipartFile file) {
		String objectKey = "recordings/" + recordingId + "/" + UUID.randomUUID() + ".m4a";
		Path destination = resolveSafely(objectKey);
		try (InputStream input = file.getInputStream()) {
			Files.createDirectories(destination.getParent());
			Files.copy(input, destination, StandardCopyOption.REPLACE_EXISTING);
			return objectKey;
		} catch (IOException exception) {
			throw new ApiException(ErrorCode.STORAGE_ERROR);
		}
	}

	@Override
	public String storeAnswerAudio(String answerId, byte[] audio) {
		String objectKey = "tts/" + answerId + "/" + UUID.randomUUID() + ".mp3";
		Path destination = resolveSafely(objectKey);
		try {
			Files.createDirectories(destination.getParent());
			Files.write(destination, audio);
			return objectKey;
		} catch (IOException exception) {
			throw new ApiException(ErrorCode.STORAGE_ERROR);
		}
	}

	@Override
	public void delete(String objectKey) {
		if (objectKey == null) {
			return;
		}
		try {
			Files.deleteIfExists(resolveSafely(objectKey));
		} catch (IOException exception) {
			throw new ApiException(ErrorCode.STORAGE_ERROR);
		}
	}

	private Path resolveSafely(String objectKey) {
		Path resolved = rootDirectory.resolve(objectKey).normalize();
		if (!resolved.startsWith(rootDirectory)) {
			throw new ApiException(ErrorCode.STORAGE_ERROR);
		}
		return resolved;
	}
}
