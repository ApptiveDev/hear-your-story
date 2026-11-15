package com.apptive.backend.domain.user.service;

import com.apptive.backend.domain.user.entity.AccountDeletionTaskType;

record AccountDeletionTaskClaim(String taskId, AccountDeletionTaskType type, String targetValue) {
}
