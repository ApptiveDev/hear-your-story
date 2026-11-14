package com.apptive.backend.domain.user.repository;

import java.util.Optional;

import jakarta.persistence.LockModeType;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.apptive.backend.domain.user.entity.AccountStatus;
import com.apptive.backend.domain.user.entity.AuthProvider;
import com.apptive.backend.domain.user.entity.User;

public interface UserRepository extends JpaRepository<User, String> {

	Optional<User> findByAuthProviderAndAuthSubject(AuthProvider authProvider, String authSubject);

	boolean existsByIdAndAccountStatus(String id, AccountStatus accountStatus);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select user from User user where user.id = :userId")
	Optional<User> findByIdForUpdate(@Param("userId") String userId);
}
