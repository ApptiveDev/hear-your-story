package com.apptive.backend.domain.answer.dto;

import java.time.OffsetDateTime;

import com.apptive.backend.domain.answer.entity.TtsStatus;

public record AnswerAudioResponse(String answerId, TtsStatus ttsStatus, String audioUrl, OffsetDateTime audioExpiresAt,
    String processingNotice) {
}
