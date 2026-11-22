create table storage_deletion_tasks (
    id varchar(40) not null primary key,
    object_key varchar(1000) not null,
    next_attempt_at timestamp(6) with time zone not null,
    attempts integer not null
);
create index idx_storage_deletion_tasks_ready on storage_deletion_tasks (next_attempt_at, id);
