package com.apptive.backend.domain.recording.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.apptive.backend.domain.recording.entity.Recording;

public interface RecordingRepository extends JpaRepository<Recording, String> {

	Optional<Recording> findByAssignment_Id(String assignmentId);

	List<Recording> findAllByAssignment_IdIn(List<String> assignmentIds);
}
