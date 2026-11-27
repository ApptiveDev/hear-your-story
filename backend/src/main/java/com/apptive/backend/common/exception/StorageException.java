package com.apptive.backend.common.exception;

/** API 계약은 STORAGE_ERROR로 유지하면서 저장 작업의 원인을 보존한다. */
public class StorageException extends ApiException {
	public StorageException(DependencyException cause) {
		super(ErrorCode.STORAGE_ERROR, cause);
	}
}
