package com.apptive.backend.domain.auth.service;

import com.apptive.backend.domain.user.entity.User;

public record RotatedRefreshToken(User user, IssuedRefreshToken issuedToken) {
}
