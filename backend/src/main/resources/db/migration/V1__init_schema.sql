create table app_users (
    id varchar(40) not null,
    name varchar(50) not null,
    role varchar(10) not null,
    device_id varchar(255) not null,
    created_at timestamp(6) with time zone not null,
    constraint pk_app_users primary key (id),
    constraint uk_app_users_device_role unique (device_id, role),
    constraint ck_app_users_role check (role in ('PARENT', 'CHILD'))
);

create table family_pairs (
    id varchar(40) not null,
    parent_id varchar(40) not null,
    child_id varchar(40) not null,
    paired_at timestamp(6) with time zone not null,
    constraint pk_family_pairs primary key (id),
    constraint uk_family_pairs_parent unique (parent_id),
    constraint uk_family_pairs_child unique (child_id),
    constraint fk_family_pairs_parent foreign key (parent_id) references app_users (id),
    constraint fk_family_pairs_child foreign key (child_id) references app_users (id)
);

create table pair_invitations (
    id varchar(40) not null,
    child_id varchar(40) not null,
    invite_code varchar(6) not null,
    expires_at timestamp(6) with time zone not null,
    created_at timestamp(6) with time zone not null,
    used_at timestamp(6) with time zone,
    constraint pk_pair_invitations primary key (id),
    constraint uk_pair_invitations_invite_code unique (invite_code),
    constraint fk_pair_invitations_child foreign key (child_id) references app_users (id)
);

create index idx_pair_invitations_active_child
    on pair_invitations (child_id, used_at, expires_at, created_at);

create table questions (
    id varchar(40) not null,
    scheduled_date date not null,
    text varchar(500) not null,
    category varchar(50) not null,
    audio_url varchar(1000),
    active boolean not null,
    constraint pk_questions primary key (id),
    constraint uk_questions_scheduled_date unique (scheduled_date)
);

create table assignments (
    id varchar(40) not null,
    pair_id varchar(40) not null,
    question_id varchar(40) not null,
    assigned_date date not null,
    created_at timestamp(6) with time zone not null,
    constraint pk_assignments primary key (id),
    constraint uk_assignments_pair_date unique (pair_id, assigned_date),
    constraint fk_assignments_pair foreign key (pair_id) references family_pairs (id),
    constraint fk_assignments_question foreign key (question_id) references questions (id)
);

create table child_answers (
    id varchar(40) not null,
    assignment_id varchar(40) not null,
    text varchar(1000) not null,
    tts_status varchar(20) not null,
    tts_object_key varchar(1000),
    tts_version varchar(36),
    tts_processing_notice varchar(500),
    submitted_at timestamp(6) with time zone not null,
    updated_at timestamp(6) with time zone not null,
    constraint pk_child_answers primary key (id),
    constraint uk_child_answers_assignment unique (assignment_id),
    constraint fk_child_answers_assignment foreign key (assignment_id) references assignments (id),
    constraint ck_child_answers_tts_status
        check (tts_status in ('NOT_REQUESTED', 'PROCESSING', 'READY', 'FAILED'))
);

create table recordings (
    id varchar(40) not null,
    assignment_id varchar(40) not null,
    object_key varchar(1000) not null,
    original_filename varchar(255) not null,
    content_type varchar(100) not null,
    size_bytes bigint not null,
    idempotency_key varchar(100),
    processing_version varchar(36) not null,
    processing_status varchar(30) not null,
    stt_text text,
    summary_text text,
    failed_stage varchar(30),
    failure_code varchar(100),
    processing_notice varchar(500),
    submitted_at timestamp(6) with time zone not null,
    updated_at timestamp(6) with time zone not null,
    constraint pk_recordings primary key (id),
    constraint uk_recordings_assignment unique (assignment_id),
    constraint fk_recordings_assignment foreign key (assignment_id) references assignments (id),
    constraint ck_recordings_processing_status
        check (processing_status in ('UPLOADED', 'STT_PROCESSING', 'STT_DONE', 'LLM_PROCESSING', 'READY', 'FAILED'))
);
