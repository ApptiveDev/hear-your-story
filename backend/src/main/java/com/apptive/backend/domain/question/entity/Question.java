package com.apptive.backend.domain.question.entity;

import java.time.LocalDate;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import lombok.Getter;

@Getter
@Entity
@Table(name = "questions")
public class Question {

	@Id
	@Column(length = 40, nullable = false, updatable = false)
	private String id;

	@Column(name = "scheduled_date", nullable = false, unique = true)
	private LocalDate scheduledDate;

	@Column(length = 500, nullable = false)
	private String text;

	@Column(length = 50, nullable = false)
	private String category;

	@Column(name = "audio_url", length = 1000)
	private String audioUrl;

	@Column(nullable = false)
	private boolean active;

	protected Question() {
	}

	public Question(String id, LocalDate scheduledDate, String text, String category, String audioUrl, boolean active) {
		this.id = id;
		updateFromSeed(scheduledDate, text, category, audioUrl, active);
	}

	public void updateFromSeed(LocalDate scheduledDate, String text, String category, String audioUrl, boolean active) {
		this.scheduledDate = scheduledDate;
		this.text = text;
		this.category = category;
		this.audioUrl = audioUrl;
		this.active = active;
	}

}
