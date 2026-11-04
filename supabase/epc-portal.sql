begin;
create table public.tw_epc_login_challenges (
 id uuid primary key default gen_random_uuid(),epc_id uuid references public.tw_epcs(id),code_hash text not null,
 address_hash text not null,ip_hash text not null,attempts integer not null default 0,
 used boolean not null default false,created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '10 minutes'
);
create index tw_epc_login_address on public.tw_epc_login_challenges(address_hash,created_at);
create index tw_epc_login_ip on public.tw_epc_login_challenges(ip_hash,created_at);
create table public.tw_epc_sessions (
 token_hash text primary key,epc_id uuid not null references public.tw_epcs(id),created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '8 hours'
);
alter table public.tw_epc_login_challenges enable row level security;
alter table public.tw_epc_sessions enable row level security;
revoke all on public.tw_epc_login_challenges,public.tw_epc_sessions from public,anon,authenticated;
grant select,insert,update,delete on public.tw_epc_login_challenges,public.tw_epc_sessions to service_role;

create function public.tw_epc_login_request(p_email text,p_phone text,p_code_hash text,p_address_hash text,p_ip_hash text) returns jsonb language plpgsql security invoker set search_path='' as $$
declare e public.tw_epcs; v_id uuid; phone_digits text;
begin
 perform pg_advisory_xact_lock(hashtextextended('tw-epc-login:'||p_address_hash,0));
 perform pg_advisory_xact_lock(hashtextextended('tw-epc-ip:'||p_ip_hash,0));
 if (select count(*) from public.tw_epc_login_challenges where address_hash=p_address_hash and created_at>now()-interval '1 hour')>=5 or (select count(*) from public.tw_epc_login_challenges where ip_hash=p_ip_hash and created_at>now()-interval '1 hour')>=30 then return jsonb_build_object('limited',true);end if;
 phone_digits:=regexp_replace(p_phone,'[^0-9]','','g');if phone_digits like '66%' then phone_digits:='0'||substr(phone_digits,3);end if;
 select * into e from public.tw_epcs where active and lower(email)=lower(trim(p_email)) and (case when regexp_replace(phone,'[^0-9]','','g') like '66%' then '0'||substr(regexp_replace(phone,'[^0-9]','','g'),3) else regexp_replace(phone,'[^0-9]','','g') end)=phone_digits;
 update public.tw_epc_login_challenges set used=true where address_hash=p_address_hash and not used;
 insert into public.tw_epc_login_challenges(epc_id,code_hash,address_hash,ip_hash) values(e.id,p_code_hash,p_address_hash,p_ip_hash) returning id into v_id;
 return jsonb_build_object('challengeId',v_id,'email',e.email,'epcId',e.id);
end $$;

create function public.tw_epc_verify_login(p_challenge_id uuid,p_code_hash text,p_session_hash text) returns uuid language plpgsql security invoker set search_path='' as $$
declare c public.tw_epc_login_challenges;
begin
 select * into c from public.tw_epc_login_challenges where id=p_challenge_id for update;
 if not found or c.used or c.expires_at<=now() or c.attempts>=5 then return null;end if;
 update public.tw_epc_login_challenges set attempts=attempts+1 where id=c.id;
 if c.code_hash<>p_code_hash or c.epc_id is null or not exists(select 1 from public.tw_epcs where id=c.epc_id and active) then return null;end if;
 update public.tw_epc_login_challenges set used=true where id=c.id;
 insert into public.tw_epc_sessions(token_hash,epc_id) values(p_session_hash,c.epc_id);return c.epc_id;
end $$;

create function public.tw_epc_portal_leads(p_epc_id uuid) returns jsonb language sql security invoker set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'leadId',l.id,'status',a.status,'sentAt',a.sent_at,'acceptedAt',a.accepted_at,
 'expired',a.status='รอรับ Lead' and a.sent_at+interval '5 days'<=now(),
 'name',case when a.accepted_at is not null then l.name else 'ข้อมูลลูกค้าถูกปกปิด' end,
 'phone',case when a.accepted_at is not null then l.phone end,
 'email',case when a.accepted_at is not null then l.email end,
 'province',l.province,'answers',l.answers,
 'logs',coalesce((select jsonb_agg(jsonb_build_object('text',v.message,'time',v.created_at) order by v.created_at desc) from public.tw_events v where v.assignment_id=a.id),'[]'::jsonb)
 ) order by a.sent_at desc),'[]'::jsonb) from public.tw_assignments a join public.tw_leads l on l.id=a.lead_id
 where a.epc_id=p_epc_id and a.revoked_at is null;
$$;

create function public.tw_epc_portal_action(p_epc_id uuid,p_assignment_id uuid,p_action text,p_status text default null) returns void language plpgsql security invoker set search_path='' as $$
declare a public.tw_assignments; msg text;
begin
 select * into a from public.tw_assignments where id=p_assignment_id and epc_id=p_epc_id and revoked_at is null for update;
 if not found then raise exception 'ไม่พบ Lead หรือไม่มีสิทธิ์เข้าถึง';end if;
 if p_action='accept' then
 if a.accepted_at is not null then return;end if;
 if a.status<>'รอรับ Lead' or a.sent_at+interval '5 days'<=now() then raise exception 'Lead ไม่พร้อมรับหรือครบกำหนด 5 วันแล้ว';end if;
 update public.tw_assignments set accepted_at=now(),status='Pending' where id=a.id;msg:='EPC รับ Lead ผ่าน EPC Portal';
 elsif p_action='status' then
 if a.accepted_at is null then raise exception 'ต้องรับ Lead ก่อนอัปเดตสถานะ';end if;
 if p_status is null or p_status not in ('Pending','Close','Lost') then raise exception 'สถานะไม่ถูกต้อง';end if;
 update public.tw_assignments set status=p_status where id=a.id;msg:='EPC อัปเดตสถานะเป็น '||p_status;
 else raise exception 'คำสั่งไม่ถูกต้อง';end if;
 insert into public.tw_events(lead_id,assignment_id,message) values(a.lead_id,a.id,msg);
end $$;
revoke all on function public.tw_epc_login_request(text,text,text,text,text),public.tw_epc_verify_login(uuid,text,text),public.tw_epc_portal_leads(uuid),public.tw_epc_portal_action(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.tw_epc_login_request(text,text,text,text,text),public.tw_epc_verify_login(uuid,text,text),public.tw_epc_portal_leads(uuid),public.tw_epc_portal_action(uuid,uuid,text,text) to service_role;
grant select on public.tw_epcs,public.tw_leads,public.tw_events to service_role;
grant update on public.tw_assignments to service_role;
grant insert on public.tw_events to service_role;
grant usage on sequence public.tw_events_id_seq to service_role;
commit;
