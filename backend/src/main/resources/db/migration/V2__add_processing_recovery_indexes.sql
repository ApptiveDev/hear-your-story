create index idx_recordings_processing_recovery
    on recordings (processing_status, updated_at);

create index idx_child_answers_tts_recovery
    on child_answers (tts_status, updated_at);
