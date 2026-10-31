-- Reversible Lead Hub deletion only.
alter table public.tw_leads add column if not exists deleted_at timestamptz;
create or replace function public.tw_delete_lead(p_lead_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.tw_members where user_id=auth.uid() and role='admin') then raise exception 'Admin only';end if;
 perform 1 from public.tw_leads where id=p_lead_id and deleted_at is null for update;if not found then raise exception 'Lead unavailable';end if;
 if exists(select 1 from public.tw_email_outbox o join public.tw_assignments a on a.id=o.assignment_id where a.lead_id=p_lead_id and o.status='sending') then raise exception 'อีเมลกำลังส่ง กรุณาลองอีกครั้งหลังส่งเสร็จ';end if;
 update public.tw_leads set deleted_at=now() where id=p_lead_id;
 update public.tw_assignments set revoked_at=now(),status='ดึงคืน' where lead_id=p_lead_id and revoked_at is null;
 update public.tw_email_outbox o set status='skipped',last_error='Admin deleted lead' where o.status in ('queued','failed') and exists(select 1 from public.tw_assignments a where a.id=o.assignment_id and a.lead_id=p_lead_id);
 insert into public.tw_events(lead_id,actor,message) values(p_lead_id,auth.uid(),'Admin ย้าย Lead ไปถังขยะ');
end $$;
create or replace function public.tw_deleted_leads() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.tw_members where user_id=auth.uid() and role='admin') then raise exception 'Admin only';end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'deletedAt',deleted_at) order by deleted_at desc) from public.tw_leads where deleted_at is not null),'[]'::jsonb);
end $$;
create or replace function public.tw_restore_lead(p_lead_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.tw_members where user_id=auth.uid() and role='admin') then raise exception 'Admin only';end if;
 update public.tw_leads set deleted_at=null where id=p_lead_id and deleted_at is not null;if not found then raise exception 'Lead unavailable';end if;
 insert into public.tw_events(lead_id,actor,message) values(p_lead_id,auth.uid(),'Admin กู้คืน Lead ต้องเลือกมอบหมาย EPC ใหม่');
end $$;
revoke all on function public.tw_delete_lead(uuid),public.tw_deleted_leads(),public.tw_restore_lead(uuid) from public,anon;
grant execute on function public.tw_delete_lead(uuid),public.tw_deleted_leads(),public.tw_restore_lead(uuid) to authenticated;
-- Preserve deployed access checks; add only the deleted lead filter.
do $$ declare s text;begin
 s:=pg_get_functiondef('public.tw_list_leads()'::regprocedure);
 if position('l.deleted_at is null' in s)=0 then s:=replace(s,'where m.role=''admin'' or a.epc_id=m.epc_id','where l.deleted_at is null and (m.role=''admin'' or a.epc_id=m.epc_id)');execute s;end if;
 s:=pg_get_functiondef('public.tw_assign_lead(uuid,uuid[])'::regprocedure);
 if position('deleted_at is null' in s)=0 then execute replace(s,'where id=p_lead_id for update','where id=p_lead_id and deleted_at is null for update');end if;
end $$;
