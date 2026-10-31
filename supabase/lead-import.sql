-- Additive, Lead Hub only. Does not modify other app tables or Auth.
create or replace function public.tw_import_leads(p_rows jsonb,p_filename text,p_consent boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r jsonb; v_id uuid; n int:=0; skipped int:=0; v_phone text; v_name text;
begin
 if not exists(select 1 from public.tw_members where user_id=auth.uid() and role='admin') then raise exception 'Admin only';end if;
 if p_consent is distinct from true then raise exception 'Consent required';end if;
 if jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows)>500 or octet_length(p_rows::text)>2097152 then raise exception 'Invalid import size';end if;
 perform pg_advisory_xact_lock(743819272);
 for r in select value from jsonb_array_elements(p_rows) loop
 v_name:=trim(r->>'Customer Name');v_phone:=r->>'Phone';
 if coalesce(length(v_name),0) not between 1 and 150 or coalesce(v_phone,'') !~ '^(0[0-9]{8,9}|\+[0-9]{9,15})$' or coalesce(length(trim(r->>'Province')),0) not between 1 and 100 or length(r::text)>12000 then raise exception 'Invalid import row';end if;
 if coalesce(r->>'Email','')<>'' and (length(r->>'Email')>254 or (r->>'Email') !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') then raise exception 'Invalid email';end if;
 if exists(select 1 from public.tw_leads l where l.source='CSV import' and (
 (coalesce(r->>'Lead ID','')<>'' and l.answers->'imported'->>'Lead ID'=r->>'Lead ID'
 and coalesce(l.answers->'imported'->>'Created At','')=coalesce(r->>'Created At','')
 and coalesce(nullif(l.answers->'imported'->>'Partner ID',''),l.answers->'imported'->>'Partner Company','')=coalesce(nullif(r->>'Partner ID',''),r->>'Partner Company',''))
 or (coalesce(r->>'Lead ID','')='' and l.answers->'imported'=r-'Token')
 )) then skipped:=skipped+1;continue;end if;
 insert into public.tw_leads(name,phone,email,province,answers,source,campaign,consent_at) values(v_name,v_phone,coalesce(r->>'Email',''),trim(r->>'Province'),jsonb_build_object('property',coalesce(nullif(r->>'Project Type',''),'ไม่ระบุ'),'bill','ไม่ระบุ','ownership','ไม่ระบุ','timeline','ไม่ระบุ','imported',r-'Token'),'CSV import',left(p_filename,200),now()) returning id into v_id;
 insert into public.tw_events(lead_id,actor,message) values(v_id,auth.uid(),'Admin นำเข้า Lead จาก CSV: '||left(p_filename,200));n:=n+1;
 end loop;
 return jsonb_build_object('imported',n,'skipped',skipped);
end $$;
revoke all on function public.tw_import_leads(jsonb,text,boolean) from public,anon;
grant execute on function public.tw_import_leads(jsonb,text,boolean) to authenticated;
