create table if not exists public.tw_epc_passwords(epc_id uuid primary key references public.tw_epcs(id),salt text not null,password_hash text not null,updated_at timestamptz not null default now());
create table if not exists public.tw_epc_password_attempts(bucket text primary key,started_at timestamptz not null,attempts int not null);
alter table public.tw_epc_passwords enable row level security;
alter table public.tw_epc_password_attempts enable row level security;
revoke all on public.tw_epc_passwords,public.tw_epc_password_attempts from public,anon,authenticated;
grant select,insert,update on public.tw_epc_passwords,public.tw_epc_password_attempts to service_role;
create or replace function public.tw_epc_password_limit(p_bucket text) returns boolean language plpgsql security invoker set search_path='' as $$
declare n int;begin
 insert into public.tw_epc_password_attempts as t(bucket,started_at,attempts) values(p_bucket,now(),1) on conflict(bucket) do update set attempts=case when t.started_at<now()-interval '15 minutes' then 1 else t.attempts+1 end,started_at=case when t.started_at<now()-interval '15 minutes' then now() else t.started_at end returning attempts into n;return n<=10;
end $$;
revoke all on function public.tw_epc_password_limit(text) from public,anon,authenticated;
grant execute on function public.tw_epc_password_limit(text) to service_role;
