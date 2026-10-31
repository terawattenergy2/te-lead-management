begin;
create table public.tw_gmail_sender (
 singleton boolean primary key default true check(singleton),email text not null,
 encrypted_refresh_token text not null,connected_by uuid not null references auth.users(id),connected_at timestamptz not null default now()
);
create table public.tw_gmail_oauth_states (
 state_hash text primary key,admin_id uuid not null references auth.users(id),verifier text not null,
 return_origin text not null,expires_at timestamptz not null default now()+interval '10 minutes'
);
alter table public.tw_gmail_sender enable row level security;
alter table public.tw_gmail_oauth_states enable row level security;
revoke all on public.tw_gmail_sender,public.tw_gmail_oauth_states from public,anon,authenticated;
grant select,insert,update,delete on public.tw_gmail_sender,public.tw_gmail_oauth_states to service_role;
alter table public.tw_email_outbox add column attempts integer not null default 0;
alter table public.tw_email_outbox add column attempt_id uuid;
alter table public.tw_email_outbox add column provider_message_id text;
-- Unknown outcomes are never retried automatically: Gmail has no send idempotency key.
grant select,update on public.tw_email_outbox to service_role;
grant select on public.tw_members,public.tw_assignments to service_role;
create function public.tw_claim_gmail_batch() returns setof public.tw_email_outbox language sql security invoker set search_path='' as $$
 with batch as (
 select o.id from public.tw_email_outbox o join public.tw_assignments a on a.id=o.assignment_id
 where o.status='queued' and a.revoked_at is null and a.status='รอรับ Lead' and a.sent_at+interval '5 days'>now()
 order by o.created_at limit 3 for update of o skip locked
 ) update public.tw_email_outbox o set status='sending',attempts=o.attempts+1,attempt_id=gen_random_uuid(),last_error=null
 from batch where o.id=batch.id returning o.*;
$$;
revoke all on function public.tw_claim_gmail_batch() from public,anon,authenticated;
grant execute on function public.tw_claim_gmail_batch() to service_role;
commit;
