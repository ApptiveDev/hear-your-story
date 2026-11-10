package com.apptive.backend.common.exception;

import java.time.OffsetDateTime;
import java.util.List;

public record ApiErrorResponse(OffsetDateTime timestamp, int status, String errorCode, String message, String path,
    String traceId, List<FieldErrorResponse> fieldErrors) {
}
