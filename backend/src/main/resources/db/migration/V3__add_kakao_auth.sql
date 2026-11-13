alter table app_users drop constraint uk_app_users_device_role;

alter table app_users alter column device_id drop not null;

alter table app_users add column auth_provider varchar(20);
alter table app_users add column auth_subject varchar(255);

alter table app_users
    add constraint uk_app_users_auth_identity unique (auth_provider, auth_subject);

alter table app_users
    add constraint ck_app_users_auth_provider
    check (auth_provider is null or auth_provider in ('KAKAO'));

alter table app_users
    add constraint ck_app_users_auth_identity
    check ((auth_provider is null and auth_subject is null)
        or (auth_provider is not null and auth_subject is not null));

create table refresh_tokens (
    id varchar(40) not null,
    user_id varchar(40) not null,
    token_hash varchar(64) not null,
    expires_at timestamp(6) with time zone not null,
    revoked_at timestamp(6) with time zone,
    created_at timestamp(6) with time zone not null,
    constraint pk_refresh_tokens primary key (id),
    constraint uk_refresh_tokens_token_hash unique (token_hash),
    constraint fk_refresh_tokens_user foreign key (user_id) references app_users (id) on delete cascade
);

create index idx_refresh_tokens_user_active
    on refresh_tokens (user_id, revoked_at, expires_at);
