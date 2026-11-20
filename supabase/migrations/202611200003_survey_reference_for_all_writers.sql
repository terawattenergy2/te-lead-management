-- Use one reference generator for all survey writers, including older browsers.
CREATE FUNCTION tw_private.issue_survey_reference(p_data jsonb, p_province text)
RETURNS text LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
  province_code text;
  issued_code text;
BEGIN
  IF nullif(trim(p_province), '') IS NULL
    OR coalesce(p_data->>'property','') NOT IN ('บ้านพักอาศัย','สำนักงาน/ ออฟฟิศ','โรงงาน')
    OR coalesce(p_data->>'ev','') NOT IN ('มี','ไม่มี')
    OR coalesce(p_data->>'usage','') NOT IN ('ใช้ช่วงกลางวันเป็นหลัก','ใช้ช่วงกลางวันมากกว่า','ใช้ช่วงกลางคืนเป็นหลัก','ตลอดเวลา')
    OR coalesce(p_data->>'battery','') NOT IN ('ต้องการ','ไม่ต้องการ','ขอคำแนะนำ')
  THEN RETURN NULL; END IF;

  SELECT p.code INTO province_code FROM (VALUES
    ('กรุงเทพมหานคร', 'BKK'),
    ('กระบี่', 'KBI'),
    ('กาญจนบุรี', 'KRI'),
    ('กาฬสินธุ์', 'KSN'),
    ('กำแพงเพชร', 'KPT'),
    ('ขอนแก่น', 'KKN'),
    ('จันทบุรี', 'CTI'),
    ('ฉะเชิงเทรา', 'CCO'),
    ('ชลบุรี', 'CBI'),
    ('ชัยนาท', 'CNT'),
    ('ชัยภูมิ', 'CPM'),
    ('ชุมพร', 'CPN'),
    ('เชียงราย', 'CRI'),
    ('เชียงใหม่', 'CMI'),
    ('ตรัง', 'TRG'),
    ('ตราด', 'TRT'),
    ('ตาก', 'TAK'),
    ('นครนายก', 'NYK'),
    ('นครปฐม', 'NPT'),
    ('นครพนม', 'NPM'),
    ('นครราชสีมา', 'NMA'),
    ('นครศรีธรรมราช', 'NST'),
    ('นครสวรรค์', 'NSN'),
    ('นนทบุรี', 'NBI'),
    ('นราธิวาส', 'NWT'),
    ('น่าน', 'NAN'),
    ('บึงกาฬ', 'BKN'),
    ('บุรีรัมย์', 'BRM'),
    ('ปทุมธานี', 'PTE'),
    ('ประจวบคีรีขันธ์', 'PKN'),
    ('ปราจีนบุรี', 'PRI'),
    ('ปัตตานี', 'PTN'),
    ('พระนครศรีอยุธยา', 'AYA'),
    ('พะเยา', 'PYO'),
    ('พังงา', 'PNA'),
    ('พัทลุง', 'PLG'),
    ('พิจิตร', 'PCT'),
    ('พิษณุโลก', 'PLK'),
    ('เพชรบุรี', 'PBI'),
    ('เพชรบูรณ์', 'PBN'),
    ('แพร่', 'PRE'),
    ('ภูเก็ต', 'PKT'),
    ('มหาสารคาม', 'MKM'),
    ('มุกดาหาร', 'MDH'),
    ('แม่ฮ่องสอน', 'MSN'),
    ('ยโสธร', 'YST'),
    ('ยะลา', 'YLA'),
    ('ร้อยเอ็ด', 'RET'),
    ('ระนอง', 'RNG'),
    ('ระยอง', 'RYG'),
    ('ราชบุรี', 'RBR'),
    ('ลพบุรี', 'LRI'),
    ('ลำปาง', 'LPG'),
    ('ลำพูน', 'LPN'),
    ('เลย', 'LEI'),
    ('ศรีสะเกษ', 'SSK'),
    ('สกลนคร', 'SNK'),
    ('สงขลา', 'SKA'),
    ('สตูล', 'STN'),
    ('สมุทรปราการ', 'SPK'),
    ('สมุทรสงคราม', 'SKM'),
    ('สมุทรสาคร', 'SKN'),
    ('สระแก้ว', 'SKW'),
    ('สระบุรี', 'SRI'),
    ('สิงห์บุรี', 'SBR'),
    ('สุโขทัย', 'STI'),
    ('สุพรรณบุรี', 'SPB'),
    ('สุราษฎร์ธานี', 'SNI'),
    ('สุรินทร์', 'SRN'),
    ('หนองคาย', 'NKI'),
    ('หนองบัวลำภู', 'NBP'),
    ('อ่างทอง', 'ATG'),
    ('อำนาจเจริญ', 'ACR'),
    ('อุดรธานี', 'UDN'),
    ('อุตรดิตถ์', 'UTD'),
    ('อุทัยธานี', 'UTI'),
    ('อุบลราชธานี', 'UBN'),
    ('กรุงเทพ', 'BKK'), ('กทม', 'BKK'), ('กทม.', 'BKK'), ('bangkok', 'BKK'), ('bkk', 'BKK')
  ) AS p(name, code)
  WHERE p.name = lower(trim(p_province));

  issued_code := concat_ws('-',
    coalesce(province_code, 'UNK'),
    CASE p_data->>'property' WHEN 'บ้านพักอาศัย' THEN 'H' WHEN 'สำนักงาน/ ออฟฟิศ' THEN 'O' ELSE 'F' END,
    CASE p_data->>'ev' WHEN 'มี' THEN 'EV' ELSE 'NO' END,
    CASE p_data->>'usage' WHEN 'ใช้ช่วงกลางคืนเป็นหลัก' THEN 'N' WHEN 'ตลอดเวลา' THEN 'A' ELSE 'D' END,
    CASE p_data->>'battery' WHEN 'ต้องการ' THEN 'BAT' WHEN 'ไม่ต้องการ' THEN 'NOB' ELSE 'ASK' END,
    lpad(nextval('tw_private.survey_reference_number')::text, 6, '0')
  );
  RETURN issued_code;
END;
$$;
REVOKE ALL ON FUNCTION tw_private.issue_survey_reference(jsonb,text) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION tw_private.set_survey_reference()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  NEW.reference_code := tw_private.issue_survey_reference(NEW.answers->'survey', NEW.province);
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION tw_private.set_survey_reference() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER tw_set_survey_reference
BEFORE INSERT ON public.tw_leads FOR EACH ROW
WHEN (NEW.reference_code IS NULL AND NEW.answers ? 'survey')
EXECUTE FUNCTION tw_private.set_survey_reference();

CREATE OR REPLACE FUNCTION public.tw_submit_customer_survey_with_reference(
  p_data jsonb, p_source text, p_campaign text, p_consent boolean
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  lead_id uuid;
  issued_code text;
BEGIN
  lead_id := public.tw_submit_customer_survey(p_data, p_source, p_campaign, p_consent);
  SELECT l.reference_code INTO STRICT issued_code FROM public.tw_leads l WHERE l.id = lead_id;
  IF issued_code IS NULL THEN RAISE EXCEPTION 'ไม่สามารถออกเลขอ้างอิงได้'; END IF;
  RETURN issued_code;
END;
$$;

-- Keep already-issued references and derive legacy references only from usable answers.
UPDATE public.tw_leads
SET reference_code = tw_private.issue_survey_reference(answers->'survey', province)
WHERE reference_code IS NULL AND deleted_at IS NULL
  AND answers->'survey' ?& ARRAY['property','ev','usage','battery'];
