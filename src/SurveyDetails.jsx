import React from 'react';
import './survey-details.css';
const labels={service:'บริการที่สนใจ',name:'ชื่อ-นามสกุล',phone:'เบอร์โทร',line:'Line ID',email:'อีเมล',gps:'สถานที่ติดตั้ง (GPS / Google Maps)',province:'จังหวัด',property:'ประเภทสถานที่',billAmount:'ค่าไฟต่อเดือน',ev:'รถยนต์ไฟฟ้า (EV)',usage:'ช่วงเวลาที่ใช้โซลาร์เซลล์',system:'ระบบที่สนใจ',battery:'ต้องการ Battery',timeline:'ระยะเวลาติดตั้ง / ระดับความพร้อม',contact:'ต้องการให้ทีมงาน',requirement:'รายละเอียดความต้องการ',systemSize:'ขนาดระบบ'};
export function surveyValues(lead={},data){const a=lead.answers||{},old=a.imported||{},s=data||a.survey||{};const pick=(...v)=>v.find(x=>x!==undefined&&x!==null&&String(x).trim()!==''&&x!=='ไม่ระบุ'&&x!=='ไม่ได้สอบถาม');return {service:pick(s.service,old.Service),name:pick(s.name,lead.name,old['Customer Name']),phone:pick(s.phone,lead.phone,old.Phone),line:pick(s.line,old['Line ID']),email:pick(s.email,lead.email,old.Email),gps:pick(s.gps,old.GPS),province:pick(s.province,lead.province,old.Province),property:pick(s.property,a.property,old['Project Type']),billAmount:pick(s.billAmount?`${s.billAmount} บาท / เดือน`:null,a.bill,old['Monthly Bill']),ev:pick(s.ev,old.EV),usage:pick(s.usage,old.Usage),system:pick(s.system,old.System),battery:pick(s.battery,old.Battery),timeline:pick(s.timeline,a.timeline),contact:pick(s.contact,old['Preferred Contact']),requirement:pick(old.Requirement),systemSize:pick(old['System Size'])}}
const groups = [
  ['ข้อมูลติดต่อ', ['name','phone','line','email']],
  ['สถานที่ติดตั้ง', ['gps','province','property']],
  ['ความต้องการใช้พลังงาน', ['service','billAmount','ev','usage','system','battery','timeline','contact','requirement','systemSize']],
];
const hasValue = value => value !== undefined && value !== null && !['','—','-','ไม่ระบุ','ไม่ได้ระบุ','ไม่ได้สอบถาม'].includes(String(value).trim());
export default function SurveyDetails({data,lead,hideContact=false}) {
  const values=surveyValues(lead,data);
  return <div className="survey-details">{groups.map(([title,keys])=>{
    const fields=keys.filter(k=>hasValue(values[k])&&(!hideContact||!['name','phone','email','line','gps'].includes(k)));
    if(!fields.length)return null;
    return <section className="task survey-detail-section" key={title}><h3>{title}</h3><dl className="survey-detail-grid">{fields.map(k=><div className={'survey-detail-item'+(k==='gps'?' survey-detail-wide':'')} key={k}><dt>{labels[k]}</dt><dd>{String(values[k])}{k==='gps'&&<a className="survey-map-link" href={'https://www.google.com/maps/search/?api=1&query='+encodeURIComponent(values[k])} target="_blank" rel="noreferrer">เปิดแผนที่ ↗</a>}</dd></div>)}</dl></section>
  })}</div>
}
