BEGIN;
DO $$
DECLARE
  form jsonb := '{"name":"Contact QA","phone":"0800000000","line":"qa_only","email":"qa@example.invalid","gps":"13.25,100.25","province":"กรุงเทพมหานคร","property":"บ้านพักอาศัย","billAmount":"3500","ev":"มี","usage":"ใช้ช่วงกลางวันเป็นหลัก","battery":"ต้องการ"}';
  field text;
BEGIN
  FOREACH field IN ARRAY ARRAY['phone','line','email'] LOOP
    BEGIN
      PERFORM public.tw_submit_customer_survey_with_reference(form - field,'QA','contact-test',true);
      RAISE EXCEPTION 'Missing field accepted: %', field USING ERRCODE = 'check_violation';
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
  END LOOP;
  BEGIN
    PERFORM public.tw_submit_customer_survey_with_reference(form || '{"phone":"123456789"}','QA','contact-test',true);
    RAISE EXCEPTION 'Short phone accepted' USING ERRCODE = 'check_violation';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;
  IF public.tw_submit_customer_survey_with_reference(form,'QA','contact-test',true) !~ '^BKK-H-EV-D-BAT-[0-9]{6}$' THEN
    RAISE EXCEPTION 'Complete contact submission did not return a reference';
  END IF;
END;
$$;
ROLLBACK;
