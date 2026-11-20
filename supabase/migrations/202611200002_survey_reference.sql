-- Issue a fixed-width, public reference for new customer survey submissions.
ALTER TABLE public.tw_leads ADD COLUMN reference_code text UNIQUE
  CHECK (reference_code ~ '^[A-Z]{3}-[HOF]-[A-Z]{2}-[DNA]-[A-Z]{3}-[0-9]{6}$');
CREATE SEQUENCE tw_private.survey_reference_number MINVALUE 1 MAXVALUE 999999 NO CYCLE;

CREATE FUNCTION public.tw_submit_customer_survey_with_reference(
  p_data jsonb, p_source text, p_campaign text, p_consent boolean
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  lead_id uuid;
  province_code text;
  issued_code text;
BEGIN
  lead_id := public.tw_submit_customer_survey(p_data, p_source, p_campaign, p_consent);

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
  WHERE p.name = lower(trim(p_data->>'province'));

  issued_code := concat_ws('-',
    coalesce(province_code, 'UNK'),
    CASE p_data->>'property' WHEN 'บ้านพักอาศัย' THEN 'H' WHEN 'สำนักงาน/ ออฟฟิศ' THEN 'O' ELSE 'F' END,
    CASE p_data->>'ev' WHEN 'มี' THEN 'EV' ELSE 'NO' END,
    CASE p_data->>'usage' WHEN 'ใช้ช่วงกลางคืนเป็นหลัก' THEN 'N' WHEN 'ตลอดเวลา' THEN 'A' ELSE 'D' END,
    CASE p_data->>'battery' WHEN 'ต้องการ' THEN 'BAT' WHEN 'ไม่ต้องการ' THEN 'NOB' ELSE 'ASK' END,
    lpad(nextval('tw_private.survey_reference_number')::text, 6, '0')
  );
  UPDATE public.tw_leads SET reference_code = issued_code
  WHERE id = lead_id;
  RETURN issued_code;
END;
$$;
REVOKE ALL ON FUNCTION public.tw_submit_customer_survey_with_reference(jsonb,text,text,boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tw_submit_customer_survey_with_reference(jsonb,text,text,boolean) TO anon, authenticated;

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
 'id',coalesce(a.id,l.id),'leadId',l.id,'referenceCode',l.reference_code,'assignmentId',a.id,'name',case when m.role='admin' or a.accepted_at is not null then l.name else 'ข้อมูลลูกค้าถูกปกปิด' end,
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
