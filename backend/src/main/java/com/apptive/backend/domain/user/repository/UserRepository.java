package com.apptive.backend.domain.user.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.User;

public interface UserRepository extends JpaRepository<User, String> {

	Optional<User> findByAuthProviderAndAuthSubject(AuthProvider authProvider, String authSubject);
}
