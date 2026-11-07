package com.apptive.backend.domain.assignment.entity;

import java.time.LocalDate;
import java.time.OffsetDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

import com.apptive.backend.domain.pair.entity.FamilyPair;
import com.apptive.backend.domain.question.entity.Question;

@Entity
@Table(name = "assignments", uniqueConstraints = @UniqueConstraint(name = "uk_assignments_pair_date", columnNames = {
        "pair_id", "assigned_date"}))
public class Assignment {

	@Id
	@Column(length = 40, nullable = false, updatable = false)
	private String id;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "pair_id", nullable = false, updatable = false)
	private FamilyPair familyPair;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "question_id", nullable = false, updatable = false)
	private Question question;

	@Column(name = "assigned_date", nullable = false, updatable = false)
	private LocalDate assignedDate;

	@Column(name = "created_at", nullable = false, updatable = false)
	private OffsetDateTime createdAt;

	protected Assignment() {
	}

	public Assignment(String id, FamilyPair familyPair, Question question, LocalDate assignedDate,
	    OffsetDateTime createdAt) {
		this.id = id;
		this.familyPair = familyPair;
		this.question = question;
		this.assignedDate = assignedDate;
		this.createdAt = createdAt;
	}

	public String getId() {
		return id;
	}

	public FamilyPair getFamilyPair() {
		return familyPair;
	}

	public Question getQuestion() {
		return question;
	}

	public LocalDate getAssignedDate() {
		return assignedDate;
	}

	public OffsetDateTime getCreatedAt() {
		return createdAt;
	}
}
