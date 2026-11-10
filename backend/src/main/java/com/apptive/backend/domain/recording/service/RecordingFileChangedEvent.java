package com.apptive.backend.domain.recording.service;

record RecordingFileChangedEvent(String newObjectKey, String previousObjectKey) {
}
