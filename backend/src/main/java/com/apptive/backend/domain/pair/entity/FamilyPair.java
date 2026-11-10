package com.apptive.backend.domain.pair.entity;

import java.time.OffsetDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

import com.apptive.backend.domain.user.entity.User;

import lombok.Getter;

@Getter
@Entity
@Table(name = "family_pairs", uniqueConstraints = {
        @UniqueConstraint(name = "uk_family_pairs_parent", columnNames = "parent_id"),
        @UniqueConstraint(name = "uk_family_pairs_child", columnNames = "child_id")})
public class FamilyPair {

	@Id
	@Column(length = 40, nullable = false, updatable = false)
	private String id;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "parent_id", nullable = false, updatable = false)
	private User parent;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "child_id", nullable = false, updatable = false)
	private User child;

	@Column(name = "paired_at", nullable = false, updatable = false)
	private OffsetDateTime pairedAt;

	protected FamilyPair() {
	}

	public FamilyPair(String id, User parent, User child, OffsetDateTime pairedAt) {
		this.id = id;
		this.parent = parent;
		this.child = child;
		this.pairedAt = pairedAt;
	}

	public boolean hasParent(String userId) {
		return parent.getId().equals(userId);
	}

	public boolean hasChild(String userId) {
		return child.getId().equals(userId);
	}

}
