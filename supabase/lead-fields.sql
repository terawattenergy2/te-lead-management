-- Only Lead Hub functions. Preserve all historical CSV fields separately from active assignments.
create or replace function public.tw_admin_create_lead(p_lead jsonb,p_details jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_id uuid; k text;
begin
 if not exists(select 1 from public.tw_members where user_id=auth.uid() and role='admin') then raise exception 'Admin only';end if;
 if jsonb_typeof(p_details) is distinct from 'object' or length(p_details::text)>10000 then raise exception 'Invalid details';end if;
 foreach k in array array['Assigned At','Confirmed At','Last Update','Reminder Sent At','Recall At'] loop
 if coalesce(p_details->>k,'')<>'' then perform (p_details->>k)::timestamp;end if;
 end loop;
 if coalesce(p_details->>'Partner Email','')<>'' and (p_details->>'Partner Email') !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Invalid partner email';end if;
 v_id:=public.tw_submit_lead(p_lead->>'name',p_lead->>'phone',p_lead->>'email',p_lead->>'province',p_lead->'answers',true,p_lead->>'source',p_lead->>'campaign');
 update public.tw_leads set answers=answers||jsonb_build_object('imported',p_details-'Token') where id=v_id;
 return v_id;
end $$;
revoke all on function public.tw_admin_create_lead(jsonb,jsonb) from public,anon;
grant execute on function public.tw_admin_create_lead(jsonb,jsonb) to authenticated;

create or replace function public.tw_lead_tracking() returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.tw_members where user_id=auth.uid() and role='admin') then raise exception 'Admin only';end if;
 return coalesce((select jsonb_object_agg(coalesce(a.id,l.id)::text,
 coalesce(l.answers->'imported','{}'::jsonb)||case when a.id is null then '{}'::jsonb else jsonb_build_object(
 'Partner ID',e.id,'Partner Company',e.name,'Partner Email',e.email,'Status',a.status,
 'Assigned At',to_char(a.sent_at at time zone 'Asia/Bangkok','YYYY-MM-DD HH24:MI:SS'),
 'Confirmed At',case when a.accepted_at is not null then to_char(a.accepted_at at time zone 'Asia/Bangkok','YYYY-MM-DD HH24:MI:SS') end,
 'Last Update',(select to_char(max(v.created_at) at time zone 'Asia/Bangkok','YYYY-MM-DD HH24:MI:SS') from public.tw_events v where v.assignment_id=a.id),
 'Reminder Sent At',(select to_char(max(o.sent_at) at time zone 'Asia/Bangkok','YYYY-MM-DD HH24:MI:SS') from public.tw_email_outbox o where o.assignment_id=a.id and o.kind='reminder' and o.status='sent'),
 'Recall At',(select to_char(max(old.revoked_at) at time zone 'Asia/Bangkok','YYYY-MM-DD HH24:MI:SS') from public.tw_assignments old where old.lead_id=l.id)) end)
 from public.tw_leads l left join public.tw_assignments a on a.lead_id=l.id and a.revoked_at is null left join public.tw_epcs e on e.id=a.epc_id),'{}'::jsonb);
end $$;
revoke all on function public.tw_lead_tracking() from public,anon;
grant execute on function public.tw_lead_tracking() to authenticated;
