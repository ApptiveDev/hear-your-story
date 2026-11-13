package com.apptive.backend.domain.user.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.Role;
import com.apptive.backend.domain.user.entity.User;

public interface UserRepository extends JpaRepository<User, String> {

	Optional<User> findByDeviceIdAndRole(String deviceId, Role role);

	Optional<User> findByAuthProviderAndAuthSubject(AuthProvider authProvider, String authSubject);
}
