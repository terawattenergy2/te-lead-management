-- Additive Terawatt Lead Hub schema. Inspect existing project before applying.
begin;
create table public.tw_epcs (
 id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 1 and 150),
 email text not null check(length(email) between 3 and 254), active boolean not null default true
);
create table public.tw_members (
 user_id uuid primary key references auth.users(id) on delete cascade,
 role text not null check(role in ('admin','epc')),
 epc_id uuid references public.tw_epcs(id),
 check((role='admin' and epc_id is null) or (role='epc' and epc_id is not null))
);
create table public.tw_leads (
 id uuid primary key default gen_random_uuid(), name text not null, phone text not null, email text not null,
 province text not null, answers jsonb not null, source text not null default 'website', campaign text not null default '',
 consent_at timestamptz not null, created_at timestamptz not null default now()
);
create table public.tw_assignments (
 id uuid primary key default gen_random_uuid(),lead_id uuid not null references public.tw_leads(id),
 epc_id uuid not null references public.tw_epcs(id),sent_at timestamptz not null default now(),
 accepted_at timestamptz,revoked_at timestamptz,
 status text not null default 'รอรับ Lead' check(status in ('รอรับ Lead','Pending','Close','Lost','ดึงคืน')),
 assigned_by uuid not null references auth.users(id)
);
create unique index tw_active_assignment on public.tw_assignments(lead_id,epc_id) where revoked_at is null;
create index tw_assignment_expiry on public.tw_assignments(sent_at) where status='รอรับ Lead';
create table public.tw_events (
 id bigint generated always as identity primary key,lead_id uuid not null references public.tw_leads(id),
 assignment_id uuid references public.tw_assignments(id),actor uuid references auth.users(id),
 message text not null,created_at timestamptz not null default now()
);
create table public.tw_email_outbox (
 id uuid primary key default gen_random_uuid(),assignment_id uuid not null references public.tw_assignments(id),
 recipient text not null,kind text not null default 'assignment',status text not null default 'queued',
 created_at timestamptz not null default now(),sent_at timestamptz,last_error text,
 unique(assignment_id,kind)
);
alter table public.tw_epcs enable row level security;
alter table public.tw_members enable row level security;
alter table public.tw_leads enable row level security;
alter table public.tw_assignments enable row level security;
alter table public.tw_events enable row level security;
alter table public.tw_email_outbox enable row level security;
revoke all on public.tw_epcs,public.tw_members,public.tw_leads,public.tw_assignments,public.tw_events,public.tw_email_outbox from anon,authenticated;
grant select on public.tw_members to authenticated;
create policy tw_own_membership on public.tw_members for select to authenticated using(user_id=auth.uid());

create function public.tw_submit_lead(p_name text,p_phone text,p_email text,p_province text,p_answers jsonb,p_consent boolean,p_source text default 'website',p_campaign text default '') returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if p_consent is distinct from true then raise exception 'Consent required';end if;
 if p_name is null or length(trim(p_name)) not between 1 and 150 or p_province is null or length(trim(p_province)) not between 1 and 100 or p_phone is null or p_phone !~ '^[0-9+ ()-]{9,16}$' or p_email is null or length(p_email)>254 or p_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Invalid contact information';end if;
 if p_answers is null or jsonb_typeof(p_answers)<>'object' or not(p_answers ?& array['property','bill','ownership','timeline']) or length(p_answers::text)>2000 then raise exception 'Four answers required';end if;
 if p_answers->>'property' not in ('บ้านพักอาศัย','อาคารพาณิชย์','โรงงาน / อุตสาหกรรม') or p_answers->>'bill' not in ('ต่ำกว่า 3,000 บาท','3,000–10,000 บาท','10,001–50,000 บาท','มากกว่า 50,000 บาท') or p_answers->>'ownership' not in ('เป็นเจ้าของ','เช่า / ได้รับอนุญาตจากเจ้าของ','กำลังวางแผนสร้าง') or p_answers->>'timeline' not in ('ภายใน 1 เดือน','ภายใน 3 เดือน','ภายใน 6 เดือน','กำลังศึกษาข้อมูล') or p_answers->>'property' is null or p_answers->>'bill' is null or p_answers->>'ownership' is null or p_answers->>'timeline' is null then raise exception 'Invalid answers';end if;
 insert into public.tw_leads(name,phone,email,province,answers,source,campaign,consent_at) values(trim(p_name),trim(p_phone),trim(p_email),trim(p_province),p_answers,left(coalesce(p_source,'website'),150),left(coalesce(p_campaign,''),200),now()) returning id into v_id;
 insert into public.tw_events(lead_id,message) values(v_id,'ลูกค้าส่งแบบสอบถามและให้ความยินยอม');return v_id;
end $$;

create function public.tw_epc_list() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.tw_members where user_id=auth.uid()) then raise exception 'Access denied';end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'name',e.name,'email',e.email)) from public.tw_epcs e where e.active and (exists(select 1 from public.tw_members where user_id=auth.uid() and role='admin') or e.id=(select epc_id from public.tw_members where user_id=auth.uid()))),'[]'::jsonb);
end $$;

create function public.tw_list_leads() returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.tw_members; result jsonb;
begin
 select * into m from public.tw_members where user_id=auth.uid();if not found then raise exception 'Access denied';end if;
 select coalesce(jsonb_agg(row_data order by created_at desc),'[]'::jsonb) into result from (
 select l.created_at,jsonb_build_object(
 'id',coalesce(a.id,l.id),'leadId',l.id,'assignmentId',a.id,'name',case when m.role='admin' or a.accepted_at is not null then l.name else 'ข้อมูลลูกค้าถูกปกปิด' end,
 'phone',case when m.role='admin' or a.accepted_at is not null then l.phone end,
 'email',case when m.role='admin' or a.accepted_at is not null then l.email end,
 'province',l.province,'type',l.answers->>'property','answers',l.answers,'createdAt',l.created_at,
 'source',case when m.role='admin' then l.source end,'campaign',case when m.role='admin' then l.campaign end,
 'epc',e.name,'epcId',e.id,'sent',a.sent_at,'status',coalesce(a.status,'Lead ใหม่'),
 'expired',coalesce(a.status='รอรับ Lead' and a.sent_at+interval '5 days'<=now(),false),
 'logs',coalesce((select jsonb_agg(jsonb_build_object('text',v.message,'time',v.created_at) order by v.created_at desc) from public.tw_events v where v.lead_id=l.id and (m.role='admin' or v.assignment_id=a.id)),'[]'::jsonb)) as row_data
 from public.tw_leads l left join public.tw_assignments a on a.lead_id=l.id and a.revoked_at is null left join public.tw_epcs e on e.id=a.epc_id
 where m.role='admin' or a.epc_id=m.epc_id
 ) rows;return result;
end $$;

create function public.tw_assign_lead(p_lead_id uuid,p_epc_ids uuid[]) returns void language plpgsql security definer set search_path='' as $$
declare e public.tw_epcs; v_id uuid;
begin
 if not exists(select 1 from public.tw_members where user_id=auth.uid() and role='admin') then raise exception 'Admin required';end if;
 perform 1 from public.tw_leads where id=p_lead_id for update;if not found then raise exception 'Lead not found';end if;
 if coalesce(cardinality(p_epc_ids),0)=0 then raise exception 'Select EPC';end if;
 if exists(select 1 from unnest(p_epc_ids) x where not exists(select 1 from public.tw_epcs where id=x and active)) then raise exception 'Invalid EPC';end if;
 for e in select * from public.tw_epcs where id=any(p_epc_ids) and active loop
 insert into public.tw_assignments(lead_id,epc_id,assigned_by) values(p_lead_id,e.id,auth.uid()) returning id into v_id;
 insert into public.tw_events(lead_id,assignment_id,actor,message) values(p_lead_id,v_id,auth.uid(),'ส่ง Lead ให้ '||e.name);
 insert into public.tw_email_outbox(assignment_id,recipient) values(v_id,e.email);
 end loop;
end $$;

create function public.tw_accept_lead(p_assignment_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare a public.tw_assignments;
begin
 select * into a from public.tw_assignments where id=p_assignment_id for update;
 if not found or not exists(select 1 from public.tw_members where user_id=auth.uid() and role='epc' and epc_id=a.epc_id) then raise exception 'Access denied';end if;
 if a.revoked_at is not null or a.status<>'รอรับ Lead' or a.sent_at+interval '5 days'<=now() then raise exception 'Lead unavailable or expired';end if;
 update public.tw_assignments set status='Pending',accepted_at=now() where id=a.id;
 insert into public.tw_events(lead_id,assignment_id,actor,message) values(a.lead_id,a.id,auth.uid(),'EPC รับ Lead แล้ว');
end $$;

create function public.tw_update_status(p_assignment_id uuid,p_status text) returns void language plpgsql security definer set search_path='' as $$
declare a public.tw_assignments;
begin
 select * into a from public.tw_assignments where id=p_assignment_id for update;
 if not found or a.revoked_at is not null or a.accepted_at is null then raise exception 'Lead must be accepted';end if;
 if not exists(select 1 from public.tw_members where user_id=auth.uid() and (role='admin' or (role='epc' and epc_id=a.epc_id))) then raise exception 'Access denied';end if;
 if p_status not in ('Pending','Close','Lost') or p_status is null then raise exception 'Invalid status';end if;
 update public.tw_assignments set status=p_status where id=a.id;
 insert into public.tw_events(lead_id,assignment_id,actor,message) values(a.lead_id,a.id,auth.uid(),'อัปเดตสถานะเป็น '||p_status);
end $$;

create function public.tw_follow_up(p_assignment_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare a public.tw_assignments;
begin
 if not exists(select 1 from public.tw_members where user_id=auth.uid() and role='admin') then raise exception 'Admin required';end if;
 select * into a from public.tw_assignments where id=p_assignment_id and revoked_at is null for update;
 if not found or a.status<>'รอรับ Lead' or a.sent_at+interval '3 days'>now() then raise exception 'Follow-up not due';end if;
 insert into public.tw_events(lead_id,assignment_id,actor,message) values(a.lead_id,a.id,auth.uid(),'Admin โทรติดตาม EPC แล้ว');
end $$;

create function public.tw_reclaim_expired() returns integer language plpgsql security definer set search_path='' as $$
declare a record; n integer:=0;
begin
 if coalesce(auth.role(),'')<>'service_role' and not exists(select 1 from public.tw_members where user_id=auth.uid() and role='admin') then raise exception 'Admin required';end if;
 for a in update public.tw_assignments set revoked_at=now(),status='ดึงคืน' where status='รอรับ Lead' and revoked_at is null and sent_at+interval '5 days'<=now() returning id,lead_id loop
 insert into public.tw_events(lead_id,assignment_id,message) values(a.lead_id,a.id,'ดึง Lead คืนอัตโนมัติ: ไม่รับภายใน 5 วัน');n:=n+1;
 end loop;return n;
end $$;
revoke all on function public.tw_submit_lead(text,text,text,text,jsonb,boolean,text,text) from public,anon,authenticated;
grant execute on function public.tw_submit_lead(text,text,text,text,jsonb,boolean,text,text) to anon,authenticated;
revoke all on function public.tw_epc_list(),public.tw_list_leads(),public.tw_assign_lead(uuid,uuid[]),public.tw_accept_lead(uuid),public.tw_update_status(uuid,text),public.tw_follow_up(uuid),public.tw_reclaim_expired() from public,anon,authenticated;
grant execute on function public.tw_epc_list(),public.tw_list_leads(),public.tw_assign_lead(uuid,uuid[]),public.tw_accept_lead(uuid),public.tw_update_status(uuid,text),public.tw_follow_up(uuid),public.tw_reclaim_expired() to authenticated;
grant execute on function public.tw_reclaim_expired() to service_role;
commit;
-- Configure cron separately after verifying pg_cron availability:
-- select cron.schedule('tw-reclaim-expired','*/15 * * * *', 'select public.tw_reclaim_expired()');
-- Cron runs as the scheduling DB role; configure a dedicated scheduler wrapper if needed.
