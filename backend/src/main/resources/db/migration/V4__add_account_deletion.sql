alter table app_users add column account_status varchar(30) not null default 'ACTIVE';
alter table app_users add column deleted_at timestamp(6) with time zone;

alter table app_users
    add constraint ck_app_users_account_status
    check (account_status in ('ACTIVE', 'DELETION_PENDING', 'DELETED'));

alter table family_pairs drop constraint uk_family_pairs_parent;
alter table family_pairs drop constraint uk_family_pairs_child;
alter table family_pairs add column pairing_slot varchar(40) not null default 'ACTIVE';
alter table family_pairs add column deactivated_at timestamp(6) with time zone;

alter table family_pairs
    add constraint uk_family_pairs_parent_slot unique (parent_id, pairing_slot);
alter table family_pairs
    add constraint uk_family_pairs_child_slot unique (child_id, pairing_slot);

alter table recordings alter column object_key drop not null;
alter table recordings alter column original_filename drop not null;
alter table recordings alter column content_type drop not null;
alter table recordings alter column processing_version drop not null;
alter table recordings alter column processing_status drop not null;
alter table recordings add column deleted_at timestamp(6) with time zone;

alter table child_answers alter column text drop not null;
alter table child_answers alter column tts_status drop not null;
alter table child_answers add column deleted_at timestamp(6) with time zone;

create table account_deletion_requests (
    id varchar(40) not null,
    user_id varchar(40) not null,
    auth_provider varchar(20),
    auth_subject_hash varchar(64),
    status varchar(30) not null,
    requested_at timestamp(6) with time zone not null,
    completed_at timestamp(6) with time zone,
    updated_at timestamp(6) with time zone not null,
    constraint pk_account_deletion_requests primary key (id),
    constraint uk_account_deletion_requests_user unique (user_id),
    constraint fk_account_deletion_requests_user foreign key (user_id) references app_users (id),
    constraint ck_account_deletion_requests_status
        check (status in ('PROCESSING', 'COMPLETED'))
);

create index idx_account_deletion_requests_auth_identity
    on account_deletion_requests (auth_provider, auth_subject_hash, status);

create table account_deletion_tasks (
    id varchar(40) not null,
    deletion_request_id varchar(40) not null,
    task_type varchar(30) not null,
    target_value varchar(1000) not null,
    status varchar(20) not null,
    attempts integer not null,
    next_attempt_at timestamp(6) with time zone not null,
    last_failure_code varchar(100),
    created_at timestamp(6) with time zone not null,
    updated_at timestamp(6) with time zone not null,
    constraint pk_account_deletion_tasks primary key (id),
    constraint fk_account_deletion_tasks_request
        foreign key (deletion_request_id) references account_deletion_requests (id) on delete cascade,
    constraint ck_account_deletion_tasks_type
        check (task_type in ('STORAGE_OBJECT', 'KAKAO_UNLINK')),
    constraint ck_account_deletion_tasks_status
        check (status in ('PENDING', 'PROCESSING', 'RETRY'))
);

create index idx_account_deletion_tasks_ready
    on account_deletion_tasks (status, next_attempt_at, updated_at);
