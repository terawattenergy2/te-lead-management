-- Remove contact fields from all nested questionnaire/import objects before EPC acceptance.
create or replace function public.tw_redact_lead_contact(p_value jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare result jsonb;begin
 if jsonb_typeof(p_value)='object' then
 select coalesce(jsonb_object_agg(key,public.tw_redact_lead_contact(value)),'{}'::jsonb) into result from jsonb_each(p_value) where regexp_replace(lower(key),'[^a-z0-9ก-๙]','','g') not in ('name','customername','fullname','contactname','phone','telephone','mobile','email','line','lineid','partneremail','ชื่อ','ชื่อนามสกุล','เบอร์โทร','เบอร์โทรศัพท์','อีเมล','ไอดีไลน์','gps','location','coordinates','latitude','longitude','lat','lng','lon','address','installationaddress','installationlocation','googlemaps','googlemap','mapsurl','mapurl','สถานที่ติดตั้ง','ที่อยู่','พิกัด');return result;
 elsif jsonb_typeof(p_value)='array' then select coalesce(jsonb_agg(public.tw_redact_lead_contact(value)),'[]'::jsonb) into result from jsonb_array_elements(p_value);return result;
 end if;return p_value;
end $$;
revoke all on function public.tw_redact_lead_contact(jsonb) from public,anon;
grant execute on function public.tw_redact_lead_contact(jsonb) to authenticated,service_role;
do $$ declare s text;begin
 s:=pg_get_functiondef('public.tw_epc_portal_leads(uuid)'::regprocedure);
 s:=replace(s,'else l.answers-''survey''-''imported'' end','else public.tw_redact_lead_contact(l.answers) end');execute s;
 s:=pg_get_functiondef('public.tw_list_leads()'::regprocedure);
 s:=replace(s,'else l.answers-''survey''-''imported'' end','else public.tw_redact_lead_contact(l.answers) end');execute s;
end $$;
