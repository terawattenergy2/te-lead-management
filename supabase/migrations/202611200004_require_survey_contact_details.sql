DO $$
DECLARE
  definition text := pg_get_functiondef('public.tw_submit_customer_survey(jsonb,text,text,boolean)'::regprocedure);
  old_rules text := $old$ if coalesce(trim(p_data->>'phone'),'')='' and coalesce(trim(p_data->>'line'),'')='' then raise exception 'กรุณากรอกเบอร์โทรหรือ Line ID';end if;
 if coalesce(p_data->>'phone','')<>'' and (p_data->>'phone') !~ '^[0-9+ ()-]{9,16}$' then raise exception 'กรุณาตรวจสอบเบอร์โทร';end if;
 if coalesce(p_data->>'email','')<>'' and (length(p_data->>'email')>254 or (p_data->>'email') !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') then raise exception 'กรุณาตรวจสอบอีเมล';end if;$old$;
  new_rules text := $new$ if coalesce(p_data->>'phone','') !~ '^[0-9]{10}$' then raise exception 'กรุณากรอกเบอร์โทรให้ครบ 10 หลัก';end if;
 if coalesce(trim(p_data->>'line'),'')='' then raise exception 'กรุณากรอก LINE ID';end if;
 if coalesce(p_data->>'email','')='' then raise exception 'กรุณากรอกอีเมล';end if;
 if length(p_data->>'email')>254 or (p_data->>'email') !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'กรุณาตรวจสอบอีเมล';end if;$new$;
BEGIN
  IF strpos(definition, old_rules) = 0 THEN
    RAISE EXCEPTION 'Expected survey contact validation was not found';
  END IF;
  EXECUTE replace(definition, old_rules, new_rules);
END;
$$;
