CREATE OR REPLACE FUNCTION public.tw_lead_preview(p_answers jsonb)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
 SELECT jsonb_strip_nulls(jsonb_build_object(
   'property', CASE WHEN property IN (
     'บ้านพักอาศัย','สำนักงาน/ ออฟฟิศ','อาคารพาณิชย์','โรงงาน','โรงงาน / อุตสาหกรรม'
   ) THEN property END,
   'bill', CASE WHEN bill ~ '^[0-9,. –-]{1,30} บาท( / เดือน)?$'
     OR bill IN ('ต่ำกว่า 3,000 บาท','มากกว่า 50,000 บาท') THEN bill END,
   'survey', jsonb_build_object(
     'billAmount', CASE WHEN bill_amount ~ '^[0-9]{1,9}(\.[0-9]{1,2})?$' THEN bill_amount END,
     'ev', CASE WHEN ev IN ('มี','ไม่มี') THEN ev END,
     'usage', CASE WHEN usage IN (
       'ใช้ช่วงกลางวันเป็นหลัก','ใช้ช่วงกลางวันมากกว่า','ใช้ช่วงกลางคืนเป็นหลัก','ตลอดเวลา'
     ) THEN usage END,
     'battery', CASE WHEN battery IN ('ต้องการ','ไม่ต้องการ','ขอคำแนะนำ') THEN battery END
   )
 ))
 FROM (SELECT p_answers->>'property' AS property, p_answers->>'bill' AS bill,
   p_answers#>>'{survey,billAmount}' AS bill_amount, p_answers#>>'{survey,ev}' AS ev,
   p_answers#>>'{survey,usage}' AS usage, p_answers#>>'{survey,battery}' AS battery
 ) AS answers;
$$;
REVOKE ALL ON FUNCTION public.tw_lead_preview(jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tw_lead_preview(jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.tw_epc_portal_leads(p_epc_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
 select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'leadId',l.id,'status',a.status,'sentAt',a.sent_at,'acceptedAt',a.accepted_at,
 'deadline',a.sent_at+interval '72 hours',
 'expired',a.status='รอรับ Lead' and a.sent_at+interval '72 hours'<=now(),
 'name',case when a.accepted_at is not null then l.name else 'ข้อมูลลูกค้าถูกปกปิด' end,
 'phone',case when a.accepted_at is not null then l.phone end,
 'email',case when a.accepted_at is not null then l.email end,
 'province',l.province,'answers',case when a.accepted_at is not null then l.answers else public.tw_lead_preview(l.answers) end,
 'logs',coalesce((select jsonb_agg(jsonb_build_object('text',v.message,'time',v.created_at) order by v.created_at desc) from public.tw_events v where v.assignment_id=a.id),'[]'::jsonb)
 ) order by a.sent_at desc),'[]'::jsonb) from public.tw_assignments a join public.tw_leads l on l.id=a.lead_id
 where a.epc_id=p_epc_id and a.revoked_at is null and l.deleted_at is null;
$function$;

CREATE OR REPLACE FUNCTION public.tw_list_leads()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.tw_members; result jsonb;
begin
 select * into m from public.tw_members where user_id=auth.uid();if not found then raise exception 'Access denied';end if;
 select coalesce(jsonb_agg(row_data order by created_at desc),'[]'::jsonb) into result from (
 select l.created_at,jsonb_build_object(
 'id',coalesce(a.id,l.id),'leadId',l.id,'assignmentId',a.id,'name',case when m.role='admin' or a.accepted_at is not null then l.name else 'ข้อมูลลูกค้าถูกปกปิด' end,
 'phone',case when m.role='admin' or a.accepted_at is not null then l.phone end,
 'email',case when m.role='admin' or a.accepted_at is not null then l.email end,
 'province',l.province,'type',case when m.role='admin' or a.accepted_at is not null then l.answers->>'property' else public.tw_lead_preview(l.answers)->>'property' end,'answers',case when m.role='admin' or a.accepted_at is not null then l.answers else public.tw_lead_preview(l.answers) end,'createdAt',l.created_at,
 'source',case when m.role='admin' then l.source end,'campaign',case when m.role='admin' then l.campaign end,
 'epc',e.name,'epcId',e.id,'sent',a.sent_at,'acceptedAt',a.accepted_at,'deadline',a.sent_at+interval '72 hours',
 'emailStatus',case when m.role='admin' then (select o.status from public.tw_email_outbox o where o.assignment_id=a.id and o.kind='assignment') end,'status',coalesce(a.status,'Lead ใหม่'),
 'expired',coalesce(a.status='รอรับ Lead' and a.sent_at+interval '72 hours'<=now(),false),
 'logs',coalesce((select jsonb_agg(jsonb_build_object('text',v.message,'time',v.created_at) order by v.created_at desc) from public.tw_events v where v.lead_id=l.id and (m.role='admin' or v.assignment_id=a.id)),'[]'::jsonb)) as row_data
 from public.tw_leads l left join public.tw_assignments a on a.lead_id=l.id and a.revoked_at is null left join public.tw_epcs e on e.id=a.epc_id
 where l.deleted_at is null and (m.role='admin' or a.epc_id=m.epc_id)
 ) rows;return result;
end $function$;

CREATE OR REPLACE FUNCTION public.tw_epc_portal_action(p_epc_id uuid, p_assignment_id uuid, p_action text, p_status text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare a public.tw_assignments; msg text;
begin
 select * into a from public.tw_assignments where id=p_assignment_id and epc_id=p_epc_id and revoked_at is null for update;
 if not found then raise exception 'ไม่พบ Lead หรือไม่มีสิทธิ์เข้าถึง';end if;
 if p_action='accept' then
 if a.accepted_at is not null then return;end if;
 if a.status<>'รอรับ Lead' or a.sent_at+interval '72 hours'<=clock_timestamp() then raise exception 'Lead ไม่พร้อมรับหรือครบกำหนด 3 วันแล้ว';end if;
 update public.tw_assignments set accepted_at=now(),status='Pending' where id=a.id;msg:='EPC รับ Lead ผ่าน EPC Portal';
 elsif p_action='decline' then
 if a.accepted_at is not null or a.status<>'รอรับ Lead' or a.sent_at+interval '72 hours'<=clock_timestamp() then
   raise exception 'Lead นี้ไม่สามารถปฏิเสธได้แล้ว';
 end if;
 update public.tw_assignments set revoked_at=now(),status='ดึงคืน' where id=a.id;
 update public.tw_email_outbox set status='skipped',last_error='EPC ปฏิเสธ Lead'
 where assignment_id=a.id and status in ('queued','failed');
 msg:='EPC ปฏิเสธ Lead: '||(select e.name from public.tw_epcs e where e.id=a.epc_id);
 elsif p_action='status' then
 if a.accepted_at is null then raise exception 'ต้องรับ Lead ก่อนอัปเดตสถานะ';end if;
 if p_status is null or p_status not in ('Pending','Close','Lost') then raise exception 'สถานะไม่ถูกต้อง';end if;
 update public.tw_assignments set status=p_status where id=a.id;msg:='EPC อัปเดตสถานะเป็น '||p_status;
 else raise exception 'คำสั่งไม่ถูกต้อง';end if;
 insert into public.tw_events(lead_id,assignment_id,message) values(a.lead_id,a.id,msg);
end $function$;

CREATE OR REPLACE FUNCTION public.tw_accept_lead(p_assignment_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare a public.tw_assignments;
begin
 select * into a from public.tw_assignments where id=p_assignment_id for update;
 if not found or not exists(select 1 from public.tw_members where user_id=auth.uid() and role='epc' and epc_id=a.epc_id) then raise exception 'Access denied';end if;
 if a.revoked_at is not null or a.status<>'รอรับ Lead' or a.sent_at+interval '72 hours'<=clock_timestamp() then raise exception 'Lead unavailable or expired';end if;
 update public.tw_assignments set status='Pending',accepted_at=now() where id=a.id;
 insert into public.tw_events(lead_id,assignment_id,actor,message) values(a.lead_id,a.id,auth.uid(),'EPC รับ Lead แล้ว');
end $function$;

CREATE OR REPLACE FUNCTION public.tw_claim_gmail_batch(p_assignment_id uuid)
RETURNS SETOF public.tw_email_outbox LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$
 WITH batch AS (
   SELECT o.id FROM public.tw_email_outbox o
   JOIN public.tw_assignments a ON a.id=o.assignment_id
   WHERE o.status='queued' AND a.revoked_at IS NULL AND a.status='รอรับ Lead'
     AND a.sent_at>now()-interval '72 hours'
     AND (p_assignment_id IS NULL OR (a.id=p_assignment_id AND o.kind='assignment'))
   ORDER BY o.created_at LIMIT 3 FOR UPDATE OF o SKIP LOCKED
 )
 UPDATE public.tw_email_outbox o
 SET status='sending',attempts=o.attempts+1,attempt_id=gen_random_uuid(),last_error=null
 FROM batch WHERE o.id=batch.id RETURNING o.*;
$$;
REVOKE ALL ON FUNCTION public.tw_claim_gmail_batch(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tw_claim_gmail_batch(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.tw_claim_gmail_batch()
RETURNS SETOF public.tw_email_outbox LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$
 SELECT * FROM public.tw_claim_gmail_batch(null::uuid);
$$;

CREATE SCHEMA IF NOT EXISTS tw_private;
REVOKE ALL ON SCHEMA tw_private FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION tw_private.reclaim_expired()
RETURNS integer LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE assignment record; reclaimed integer := 0;
BEGIN
 FOR assignment IN
   UPDATE public.tw_assignments SET revoked_at=now(),status='ดึงคืน'
   WHERE status='รอรับ Lead' AND revoked_at IS NULL AND sent_at<=now()-interval '72 hours'
   RETURNING id,lead_id,epc_id
 LOOP
   UPDATE public.tw_email_outbox SET status='skipped',last_error='Lead หมดเวลารับ'
   WHERE assignment_id=assignment.id AND status IN ('queued','failed');
   INSERT INTO public.tw_events(lead_id,assignment_id,message)
   VALUES (assignment.lead_id,assignment.id,'ดึง Lead คืนอัตโนมัติ: ไม่รับภายใน 3 วัน · '||
     (SELECT e.name FROM public.tw_epcs e WHERE e.id=assignment.epc_id));
   reclaimed := reclaimed + 1;
 END LOOP;
 RETURN reclaimed;
END;
$$;
REVOKE ALL ON FUNCTION tw_private.reclaim_expired() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.tw_reclaim_expired()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
 IF coalesce(auth.role(),'')<>'service_role' AND NOT EXISTS (
   SELECT 1 FROM public.tw_members WHERE user_id=auth.uid() AND role='admin'
 ) THEN
   RAISE EXCEPTION 'Admin required';
 END IF;
 RETURN tw_private.reclaim_expired();
END;
$$;

CREATE OR REPLACE FUNCTION public.tw_retry_assignment_email(p_assignment_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.tw_members WHERE user_id=auth.uid() AND role='admin') THEN
   RAISE EXCEPTION 'Admin required';
 END IF;
 PERFORM 1 FROM public.tw_assignments
 WHERE id=p_assignment_id AND revoked_at IS NULL AND status='รอรับ Lead'
   AND sent_at>clock_timestamp()-interval '72 hours'
 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Lead ไม่พร้อมส่งอีเมล'; END IF;
 UPDATE public.tw_email_outbox SET status='queued',last_error=null
 WHERE assignment_id=p_assignment_id AND kind='assignment' AND status='failed';
 IF NOT FOUND THEN RAISE EXCEPTION 'ส่งซ้ำได้เฉพาะอีเมลที่ยืนยันแล้วว่าส่งไม่สำเร็จ'; END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.tw_retry_assignment_email(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tw_retry_assignment_email(uuid) TO authenticated;

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
SELECT cron.schedule('tw-reclaim-expired', '* * * * *', 'SELECT tw_private.reclaim_expired()');
