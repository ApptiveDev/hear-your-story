package com.apptive.backend.common.exception;

import java.util.List;

import jakarta.servlet.http.HttpServletRequest;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

@RestControllerAdvice
public class GlobalExceptionHandler {

	private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

	private final ApiErrorFactory apiErrorFactory;

	public GlobalExceptionHandler(ApiErrorFactory apiErrorFactory) {
		this.apiErrorFactory = apiErrorFactory;
	}

	@ExceptionHandler(ApiException.class)
	public ResponseEntity<ApiErrorResponse> handleApiException(ApiException exception, HttpServletRequest request) {
		ErrorCode errorCode = exception.getErrorCode();
		return ResponseEntity.status(errorCode.status())
		    .body(apiErrorFactory.create(request, errorCode, exception.getMessage(), List.of()));
	}

	@ExceptionHandler(MethodArgumentNotValidException.class)
	public ResponseEntity<ApiErrorResponse> handleValidation(MethodArgumentNotValidException exception,
	    HttpServletRequest request) {
		List<FieldErrorResponse> fieldErrors = exception.getBindingResult().getFieldErrors().stream()
		    .map(this::toFieldErrorResponse).toList();

		return ResponseEntity.badRequest().body(apiErrorFactory.create(request, ErrorCode.VALIDATION_ERROR,
		    ErrorCode.VALIDATION_ERROR.message(), fieldErrors));
	}

	@ExceptionHandler(HttpMessageNotReadableException.class)
	public ResponseEntity<ApiErrorResponse> handleUnreadableMessage(HttpMessageNotReadableException exception,
	    HttpServletRequest request) {
		return ResponseEntity.badRequest().body(apiErrorFactory.create(request, ErrorCode.VALIDATION_ERROR,
		    ErrorCode.VALIDATION_ERROR.message(), List.of()));
	}

	@ExceptionHandler(MethodArgumentTypeMismatchException.class)
	public ResponseEntity<ApiErrorResponse> handleTypeMismatch(MethodArgumentTypeMismatchException exception,
	    HttpServletRequest request) {
		return ResponseEntity.badRequest()
		    .body(apiErrorFactory.create(request, ErrorCode.VALIDATION_ERROR, ErrorCode.VALIDATION_ERROR.message(),
		        List.of(new FieldErrorResponse(exception.getName(), "type_mismatch"))));
	}

	@ExceptionHandler(MissingServletRequestPartException.class)
	public ResponseEntity<ApiErrorResponse> handleMissingRequestPart(MissingServletRequestPartException exception,
	    HttpServletRequest request) {
		return ResponseEntity.badRequest()
		    .body(apiErrorFactory.create(request, ErrorCode.VALIDATION_ERROR, ErrorCode.VALIDATION_ERROR.message(),
		        List.of(new FieldErrorResponse(exception.getRequestPartName(), "required"))));
	}

	@ExceptionHandler(HttpMediaTypeNotSupportedException.class)
	public ResponseEntity<ApiErrorResponse> handleUnsupportedMediaType(HttpMediaTypeNotSupportedException exception,
	    HttpServletRequest request) {
		return ResponseEntity.badRequest().body(apiErrorFactory.create(request, ErrorCode.INVALID_AUDIO_FORMAT,
		    ErrorCode.INVALID_AUDIO_FORMAT.message(), List.of()));
	}

	@ExceptionHandler(MaxUploadSizeExceededException.class)
	public ResponseEntity<ApiErrorResponse> handleMaxUploadSize(MaxUploadSizeExceededException exception,
	    HttpServletRequest request) {
		return ResponseEntity.status(ErrorCode.AUDIO_FILE_TOO_LARGE.status()).body(apiErrorFactory.create(request,
		    ErrorCode.AUDIO_FILE_TOO_LARGE, ErrorCode.AUDIO_FILE_TOO_LARGE.message(), List.of()));
	}

	@ExceptionHandler(NoResourceFoundException.class)
	public ResponseEntity<ApiErrorResponse> handleNotFound(NoResourceFoundException exception,
	    HttpServletRequest request) {
		return ResponseEntity.status(ErrorCode.RESOURCE_NOT_FOUND.status()).body(apiErrorFactory.create(request,
		    ErrorCode.RESOURCE_NOT_FOUND, ErrorCode.RESOURCE_NOT_FOUND.message(), List.of()));
	}

	@ExceptionHandler(Exception.class)
	public ResponseEntity<ApiErrorResponse> handleUnexpected(Exception exception, HttpServletRequest request) {
		log.error("Unhandled exception: type={}, traceId={}", exception.getClass().getName(),
		    request.getAttribute(com.apptive.backend.common.web.TraceIdFilter.TRACE_ID_ATTRIBUTE));

		return ResponseEntity.status(ErrorCode.INTERNAL_ERROR.status()).body(
		    apiErrorFactory.create(request, ErrorCode.INTERNAL_ERROR, ErrorCode.INTERNAL_ERROR.message(), List.of()));
	}

	private FieldErrorResponse toFieldErrorResponse(FieldError fieldError) {
		String reason = fieldError.getCode() == null
		    ? "invalid"
		    : fieldError.getCode().replaceAll("([a-z])([A-Z])", "$1_$2").toLowerCase();
		return new FieldErrorResponse(fieldError.getField(), reason);
	}
}
