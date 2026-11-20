BEGIN;
DO $$
DECLARE
  a text;
  b text;
  form jsonb := '{"name":"Reference QA","line":"qa_only","phone":"0800000000","email":"qa@example.invalid","gps":"13.25,100.25","province":"กรุงเทพมหานคร","property":"บ้านพักอาศัย","billAmount":"3500","ev":"มี","usage":"ใช้ช่วงกลางวันเป็นหลัก","battery":"ต้องการ"}';
  admin_id uuid;
BEGIN
  a := public.tw_submit_customer_survey_with_reference(form,'QA','reference-test',true);
  b := public.tw_submit_customer_survey_with_reference(
    form || '{"province":"เชียงใหม่","property":"โรงงาน","ev":"ไม่มี","usage":"ใช้ช่วงกลางคืนเป็นหลัก","battery":"ไม่ต้องการ"}',
    'QA','reference-test',true
  );
  IF a !~ '^BKK-H-EV-D-BAT-[0-9]{6}$' OR b !~ '^CMI-F-NO-N-NOB-[0-9]{6}$'
    OR length(a)<>21 OR length(b)<>21 OR right(a,6)::int >= right(b,6)::int
    OR NOT EXISTS (SELECT 1 FROM public.tw_leads WHERE reference_code=a AND campaign='reference-test')
  THEN RAISE EXCEPTION 'Invalid survey reference'; END IF;

  SELECT user_id INTO STRICT admin_id FROM public.tw_members WHERE role='admin' LIMIT 1;
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(public.tw_list_leads()) AS lead
    WHERE lead->>'referenceCode'=a
  ) THEN RAISE EXCEPTION 'Admin reference missing'; END IF;
END $$;
ROLLBACK;
