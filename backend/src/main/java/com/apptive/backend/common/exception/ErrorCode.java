package com.apptive.backend.common.exception;

import org.springframework.http.HttpStatus;

public enum ErrorCode {
	VALIDATION_ERROR(HttpStatus.BAD_REQUEST, "요청값이 올바르지 않습니다."), INVALID_AUDIO_FORMAT(HttpStatus.BAD_REQUEST,
	    "m4a(AAC) 형식의 녹음 파일만 업로드할 수 있습니다."), UNAUTHORIZED(HttpStatus.UNAUTHORIZED, "인증이 필요합니다."), TOKEN_EXPIRED(
	        HttpStatus.UNAUTHORIZED, "인증 토큰이 만료되었습니다."), KAKAO_ID_TOKEN_INVALID(HttpStatus.UNAUTHORIZED,
	            "카카오 로그인 정보가 올바르지 않습니다."), REGISTRATION_TOKEN_INVALID(HttpStatus.UNAUTHORIZED,
	                "가입 인증 정보가 올바르지 않습니다."), ROLE_NOT_ALLOWED(HttpStatus.FORBIDDEN,
	                    "해당 역할로는 요청할 수 없습니다."), PAIR_ACCESS_DENIED(HttpStatus.FORBIDDEN,
	                        "해당 가족의 질문에 접근할 수 없습니다."), USER_NOT_FOUND(HttpStatus.NOT_FOUND,
	                            "사용자를 찾을 수 없습니다."), ASSIGNMENT_NOT_FOUND(HttpStatus.NOT_FOUND,
	                                "배정된 질문을 찾을 수 없습니다."), RECORDING_NOT_FOUND(HttpStatus.NOT_FOUND,
	                                    "녹음을 찾을 수 없습니다."), INVITE_CODE_NOT_FOUND(HttpStatus.NOT_FOUND,
	                                        "초대 코드를 찾을 수 없습니다."), TODAY_ASSIGNMENT_NOT_FOUND(HttpStatus.NOT_FOUND,
	                                            "오늘 배정된 질문을 찾을 수 없습니다."), RESOURCE_NOT_FOUND(HttpStatus.NOT_FOUND,
	                                                "요청한 리소스를 찾을 수 없습니다."), ALREADY_PAIRED(HttpStatus.CONFLICT,
	                                                    "이미 페어링된 사용자입니다."), PAIR_NOT_FOUND(HttpStatus.CONFLICT,
	                                                        "페어링된 사용자를 찾을 수 없습니다."), INVITE_CODE_USED(
	                                                            HttpStatus.CONFLICT,
	                                                            "이미 사용된 초대 코드입니다."), INVITE_CODE_EXPIRED(
	                                                                HttpStatus.CONFLICT,
	                                                                "만료된 초대 코드입니다."), KAKAO_ACCOUNT_ALREADY_REGISTERED(
	                                                                    HttpStatus.CONFLICT,
	                                                                    "이미 가입된 카카오 계정입니다."), ANSWER_LOCKED(
	                                                                        HttpStatus.CONFLICT,
	                                                                        "공개된 답변은 수정할 수 없습니다."), AUDIO_FILE_TOO_LARGE(
	                                                                            HttpStatus.PAYLOAD_TOO_LARGE,
	                                                                            "녹음 파일은 10MiB 이하여야 합니다."), AUDIO_DURATION_OUT_OF_RANGE(
	                                                                                HttpStatus.UNPROCESSABLE_ENTITY,
	                                                                                "녹음 길이는 1초 이상 60초 이하여야 합니다."), STORAGE_ERROR(
	                                                                                    HttpStatus.BAD_GATEWAY,
	                                                                                    "녹음 파일 저장 중 오류가 발생했습니다."), INTERNAL_ERROR(
	                                                                                        HttpStatus.INTERNAL_SERVER_ERROR,
	                                                                                        "서버 내부 오류가 발생했습니다.");

	private final HttpStatus status;
	private final String message;

	ErrorCode(HttpStatus status, String message) {
		this.status = status;
		this.message = message;
	}

	public HttpStatus status() {
		return status;
	}

	public String message() {
		return message;
	}
}
