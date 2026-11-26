package com.apptive.backend.common.exception;

/** 외부 연동의 안전한 진단 정보. 원본 예외는 보존하지만 메시지나 응답 본문은 출력하지 않는다. */
public class DependencyException extends RuntimeException {
	private final String provider;
	private final String operation;
	private final int upstreamStatus;
	private final String providerCode;
	private final String reason;

	public DependencyException(String provider, String operation, int upstreamStatus, String providerCode,
	    String reason, Throwable cause) {
		super("Dependency operation failed", cause);
		this.provider = provider;
		this.operation = operation;
		this.upstreamStatus = upstreamStatus;
		this.providerCode = providerCode;
		this.reason = reason;
	}

	public String provider() {
		return provider;
	}
	public String operation() {
		return operation;
	}
	public int upstreamStatus() {
		return upstreamStatus;
	}
	public String providerCode() {
		return providerCode;
	}
	public String reason() {
		return reason;
	}
}
