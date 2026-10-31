begin;
-- Only extend the Lead Hub table; leave all other application data unchanged.
alter table public.tw_epcs add column employee_count integer check(employee_count between 1 and 10000000);
alter table public.tw_epcs add column phone text check(phone is null or phone ~ '^[0-9+ ()-]{9,20}$');
alter table public.tw_epcs add column purchased_products text[] not null default '{}';
create unique index tw_epcs_active_email on public.tw_epcs(lower(email)) where active;

create function public.tw_save_epc(p_name text,p_employee_count integer,p_email text,p_phone text,p_products text[],p_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if auth.uid() is null or not exists(select 1 from public.tw_members where user_id=auth.uid() and role='admin') then raise exception 'Admin required';end if;
 if p_name is null or length(trim(p_name)) not between 1 and 150 then raise exception 'กรุณากรอกชื่อบริษัทไม่เกิน 150 ตัวอักษร';end if;
 if p_employee_count is null or p_employee_count not between 1 and 10000000 then raise exception 'จำนวนคนในองค์กรต้องเป็นจำนวนเต็มตั้งแต่ 1 คน';end if;
 if p_email is null or length(p_email)>254 or trim(p_email) !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'รูปแบบอีเมลไม่ถูกต้อง';end if;
 if p_phone is null or trim(p_phone) !~ '^[0-9+ ()-]{9,20}$' then raise exception 'กรุณากรอกเบอร์ติดต่อที่ถูกต้อง';end if;
 if p_products is null or cardinality(p_products)>50 or exists(select 1 from unnest(p_products) x where x is null or length(trim(x)) not between 1 and 150) then raise exception 'สินค้าต้องไม่เกิน 50 รายการ รายการละไม่เกิน 150 ตัวอักษร';end if;
 if p_id is null then
 insert into public.tw_epcs(name,email,employee_count,phone,purchased_products) values(trim(p_name),lower(trim(p_email)),p_employee_count,trim(p_phone),p_products) returning id into v_id;
 else
 update public.tw_epcs set name=trim(p_name),email=lower(trim(p_email)),employee_count=p_employee_count,phone=trim(p_phone),purchased_products=p_products where id=p_id and active returning id into v_id;
 if not found then raise exception 'ไม่พบ EPC';end if;
 end if;
 return v_id;
 exception when unique_violation then raise exception 'อีเมลกลางนี้มี EPC อยู่ในระบบแล้ว';
end $$;
revoke all on function public.tw_save_epc(text,integer,text,text,text[],uuid) from public,anon,authenticated;
grant execute on function public.tw_save_epc(text,integer,text,text,text[],uuid) to authenticated;

create or replace function public.tw_epc_list() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.tw_members where user_id=auth.uid()) then raise exception 'Access denied';end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'name',e.name,'email',e.email,'employeeCount',e.employee_count,'phone',e.phone,'products',e.purchased_products) order by e.name) from public.tw_epcs e where e.active and (exists(select 1 from public.tw_members where user_id=auth.uid() and role='admin') or e.id=(select epc_id from public.tw_members where user_id=auth.uid()))),'[]'::jsonb);
end $$;
revoke all on function public.tw_epc_list() from public,anon,authenticated;
grant execute on function public.tw_epc_list() to authenticated;
commit;
