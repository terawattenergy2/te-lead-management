-- New customer survey API, writes only Lead Hub records.
create or replace function public.tw_submit_customer_survey(p_data jsonb,p_source text,p_campaign text,p_consent boolean) returns uuid language plpgsql security definer set search_path='' as $$
declare k text;v_id uuid;v_answers jsonb;v_bill numeric;
begin
 if p_consent is distinct from true then raise exception 'Consent required';end if;
 if jsonb_typeof(p_data) is distinct from 'object' or length(p_data::text)>10000 then raise exception 'Invalid form';end if;
 foreach k in array array['name','gps','province','property','billAmount','ev','usage','battery'] loop
 if coalesce(trim(p_data->>k),'')='' then raise exception 'กรุณากรอกข้อมูลให้ครบ';end if;
 end loop;
 if length(p_data->>'name')>150 or length(p_data->>'province')>100 or length(p_data->>'gps')>1000 or length(coalesce(p_data->>'line',''))>100 then raise exception 'ข้อมูลยาวเกินกำหนด';end if;
 if coalesce(trim(p_data->>'phone'),'')='' and coalesce(trim(p_data->>'line'),'')='' then raise exception 'กรุณากรอกเบอร์โทรหรือ Line ID';end if;
 if coalesce(p_data->>'phone','')<>'' and (p_data->>'phone') !~ '^[0-9+ ()-]{9,16}$' then raise exception 'กรุณาตรวจสอบเบอร์โทร';end if;
 if coalesce(p_data->>'email','')<>'' and (length(p_data->>'email')>254 or (p_data->>'email') !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') then raise exception 'กรุณาตรวจสอบอีเมล';end if;
 if coalesce(p_data->>'service','')<>'' and p_data->>'service' not in ('ติดตั้งโซลาร์เซลล์ Sigenergy (บ้าน/ธุรกิจ)','ซื้อสินค้า (EPC / Installer)','ขอคำปรึกษา') or p_data->>'property' not in ('บ้านพักอาศัย','สำนักงาน/ ออฟฟิศ','โรงงาน') or p_data->>'ev' not in ('มี','ไม่มี') or p_data->>'usage' not in ('ใช้ช่วงกลางวันเป็นหลัก','ใช้ช่วงกลางคืนเป็นหลัก','ตลอดเวลา') or coalesce(p_data->>'system','')<>'' and p_data->>'system' not in ('โซลาร์เซลล์ Sigenergy อย่างเดียว','โซลาร์ + แบตเตอรี่ (Sigenergy)','EV Charger') or p_data->>'battery' not in ('ต้องการ','ไม่ต้องการ','ขอคำแนะนำ') or coalesce(p_data->>'timeline','')<>'' and p_data->>'timeline' not in ('ด่วน (ภายใน 1 เดือน)','1 - 3 เดือน','กำลังศึกษา') or coalesce(p_data->>'contact','')<>'' and p_data->>'contact' not in ('ติดต่อด่วน','ในเวลาทำการ','ส่งใบเสนอราคา','นัดสำรวจหน้างาน') then raise exception 'กรุณาเลือกคำตอบที่กำหนด';end if;
 v_bill:=(p_data->>'billAmount')::numeric;if v_bill<=0 or v_bill>100000000 then raise exception 'กรุณาตรวจสอบค่าไฟ';end if;
 v_answers:=jsonb_build_object('property',p_data->>'property','bill',v_bill::text||' บาท / เดือน','ownership','ไม่ได้สอบถาม','timeline',p_data->>'timeline','survey',p_data,
 'imported',jsonb_build_object('Requirement',concat_ws(' · ',nullif(p_data->>'service',''),nullif(p_data->>'system',''),p_data->>'usage'),'GPS',p_data->>'gps','Line ID',p_data->>'line','Service',p_data->>'service','EV',p_data->>'ev','Battery',p_data->>'battery','Preferred Contact',p_data->>'contact'));
 insert into public.tw_leads(name,phone,email,province,answers,source,campaign,consent_at) values(trim(p_data->>'name'),coalesce(p_data->>'phone',''),coalesce(p_data->>'email',''),trim(p_data->>'province'),v_answers,left(coalesce(p_source,'website'),150),left(coalesce(p_campaign,''),200),now()) returning id into v_id;
 insert into public.tw_events(lead_id,message) values(v_id,'ลูกค้าส่งแบบสอบถาม Sigenergy และให้ความยินยอม');return v_id;
end $$;
revoke all on function public.tw_submit_customer_survey(jsonb,text,text,boolean) from public;
grant execute on function public.tw_submit_customer_survey(jsonb,text,text,boolean) to anon,authenticated;
