BEGIN;
DO $$
DECLARE
  admin_id uuid;
  company_a uuid;
  company_b uuid;
  customer_lead_id uuid;
  assignment_a uuid;
  assignment_b uuid;
  reassignment_id uuid;
  preview jsonb;
BEGIN
  SELECT user_id INTO STRICT admin_id FROM public.tw_members WHERE role='admin' LIMIT 1;
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
  INSERT INTO public.tw_epcs(name,email,phone,employee_count)
  VALUES ('Workflow QA A',gen_random_uuid()||'@example.invalid','0812345678',2) RETURNING id INTO company_a;
  INSERT INTO public.tw_epcs(name,email,phone,employee_count)
  VALUES ('Workflow QA B',gen_random_uuid()||'@example.invalid','0899999999',2) RETURNING id INTO company_b;

  customer_lead_id := public.tw_submit_customer_survey(
    '{"name":"QA customer","phone":"0810000000","email":"workflow@example.invalid","line":"private-line","gps":"13.25,100.25","province":"กรุงเทพมหานคร","property":"บ้านพักอาศัย","billAmount":"3500","ev":"ไม่มี","usage":"ตลอดเวลา","battery":"ขอคำแนะนำ"}',
    'QA', '', true
  );
  PERFORM public.tw_assign_lead(customer_lead_id,ARRAY[company_a,company_b]);
  SELECT id INTO STRICT assignment_a FROM public.tw_assignments WHERE tw_assignments.lead_id=customer_lead_id AND epc_id=company_a;
  SELECT id INTO STRICT assignment_b FROM public.tw_assignments WHERE tw_assignments.lead_id=customer_lead_id AND epc_id=company_b;

  preview := public.tw_epc_portal_leads(company_a)->0;
  IF preview->>'id' IS DISTINCT FROM assignment_a::text
    OR preview->>'phone' IS NOT NULL OR preview->>'email' IS NOT NULL
    OR preview->>'name' IS DISTINCT FROM 'ข้อมูลลูกค้าถูกปกปิด'
    OR preview::text ~ 'QA customer|0810000000|workflow@example.invalid|private-line|13.25,100.25'
    OR preview#>>'{answers,survey,billAmount}' IS DISTINCT FROM '3500'
  THEN RAISE EXCEPTION 'Invalid pending preview'; END IF;

  BEGIN
    PERFORM public.tw_epc_portal_action(company_b,assignment_a,'decline');
    RAISE EXCEPTION 'Wrong EPC declined' USING ERRCODE='check_violation';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;
  PERFORM public.tw_epc_portal_action(company_a,assignment_a,'decline');
  IF public.tw_epc_portal_leads(company_a)<>'[]'
    OR NOT EXISTS (SELECT 1 FROM public.tw_events WHERE assignment_id=assignment_a AND message LIKE 'EPC ปฏิเสธ Lead:%')
    OR NOT EXISTS (SELECT 1 FROM public.tw_email_outbox WHERE assignment_id=assignment_a AND status='skipped')
  THEN RAISE EXCEPTION 'Decline failed to revoke assignment, log event, or stop pending email'; END IF;
  IF public.tw_epc_portal_leads(company_b)->0->>'id' IS DISTINCT FROM assignment_b::text
  THEN RAISE EXCEPTION 'Decline affected another EPC'; END IF;
  BEGIN
    PERFORM public.tw_epc_portal_action(company_a,assignment_a,'accept');
    RAISE EXCEPTION 'Declined assignment accepted' USING ERRCODE='check_violation';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;

  UPDATE public.tw_email_outbox SET status='uncertain' WHERE assignment_id=assignment_b;
  BEGIN
    PERFORM public.tw_retry_assignment_email(assignment_b);
    RAISE EXCEPTION 'Uncertain email allowed to retry' USING ERRCODE='check_violation';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;
  UPDATE public.tw_email_outbox SET status='failed' WHERE assignment_id=assignment_b;
  PERFORM public.tw_retry_assignment_email(assignment_b);
  IF (SELECT count(*) FROM public.tw_claim_gmail_batch(assignment_b))<>1
  THEN RAISE EXCEPTION 'Targeted email claim failed'; END IF;
  IF (SELECT count(*) FROM public.tw_claim_gmail_batch(assignment_b))<>0
  THEN RAISE EXCEPTION 'Targeted email claim was not exclusive'; END IF;

  UPDATE public.tw_assignments SET sent_at=now()-interval '71 hours 59 minutes' WHERE id=assignment_b;
  PERFORM tw_private.reclaim_expired();
  IF NOT EXISTS (SELECT 1 FROM public.tw_assignments WHERE id=assignment_b AND revoked_at IS NULL)
  THEN RAISE EXCEPTION 'Reclaimed before 72 hours'; END IF;

  UPDATE public.tw_assignments SET sent_at=now()-interval '72 hours' WHERE id=assignment_b;
  BEGIN
    PERFORM public.tw_epc_portal_action(company_b,assignment_b,'accept');
    RAISE EXCEPTION 'Expired assignment accepted' USING ERRCODE='check_violation';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;
  PERFORM tw_private.reclaim_expired();
  PERFORM tw_private.reclaim_expired();
  IF public.tw_epc_portal_leads(company_b)<>'[]'
    OR (SELECT count(*) FROM public.tw_events WHERE assignment_id=assignment_b AND message LIKE 'ดึง Lead คืนอัตโนมัติ:%')<>1
    OR NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(public.tw_list_leads()) AS lead
      WHERE lead->>'leadId'=customer_lead_id::text AND lead->>'status'='Lead ใหม่'
    )
  THEN RAISE EXCEPTION 'Expired lead did not return to Admin exactly once'; END IF;

  PERFORM public.tw_assign_lead(customer_lead_id,ARRAY[company_a]);
  SELECT id INTO STRICT reassignment_id FROM public.tw_assignments
  WHERE tw_assignments.lead_id=customer_lead_id AND epc_id=company_a AND revoked_at IS NULL;
  PERFORM public.tw_epc_portal_action(company_a,reassignment_id,'accept');
  preview := public.tw_epc_portal_leads(company_a)->0;
  IF preview->>'phone' IS DISTINCT FROM '0810000000'
    OR preview#>>'{answers,survey,line}' IS DISTINCT FROM 'private-line'
    OR preview#>>'{answers,survey,gps}' IS DISTINCT FROM '13.25,100.25'
  THEN RAISE EXCEPTION 'Contact unavailable following acceptance'; END IF;
  BEGIN
    PERFORM public.tw_epc_portal_action(company_a,reassignment_id,'decline');
    RAISE EXCEPTION 'Accepted assignment declined' USING ERRCODE='check_violation';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;
  UPDATE public.tw_assignments SET sent_at=now()-interval '73 hours' WHERE id=reassignment_id;
  PERFORM tw_private.reclaim_expired();
  IF NOT EXISTS (SELECT 1 FROM public.tw_assignments WHERE id=reassignment_id AND status='Pending' AND revoked_at IS NULL)
  THEN RAISE EXCEPTION 'Accepted assignment reclaimed'; END IF;
END $$;
ROLLBACK;
