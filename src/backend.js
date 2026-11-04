import { createClient } from '@supabase/supabase-js';
const url=import.meta.env.VITE_SUPABASE_URL;
const key=import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
if(key&&(key.startsWith('sb_secret_')||(()=>{try{return JSON.parse(atob(key.split('.')[1])).role==='service_role'}catch{return false}})()))throw new Error('Secret/service_role keys must never be used in the browser');
export const configured=Boolean(url&&key);
export const supabase=configured?createClient(url,key):null;
export async function rpc(name,args){if(!supabase)throw new Error('ยังไม่ได้ตั้งค่า Supabase');const{data,error}=await supabase.rpc(name,args);if(error)throw error;return data}
export function submitLead(lead){return rpc('tw_submit_lead',{p_name:lead.name,p_phone:lead.phone,p_email:lead.email,p_province:lead.province,p_answers:lead.answers,p_consent:true,p_source:lead.source,p_campaign:lead.campaign})}
export async function gmailRequest(action,body){const{data:{session}}=await supabase.auth.getSession();if(!session)throw new Error('กรุณาเข้าสู่ระบบ Admin');const response=await fetch(url+'/functions/v1/tw-gmail/'+action,{method:body===undefined?'GET':'POST',headers:{Authorization:'Bearer '+session.access_token,apikey:key,...(body===undefined?{}:{'Content-Type':'application/json'})},...(body===undefined?{}:{body:JSON.stringify(body)})});let result;try{result=await response.json()}catch{throw new Error('ติดต่อระบบ Gmail ไม่สำเร็จ กรุณาตรวจว่า deploy tw-gmail แล้ว')}if(!response.ok)throw new Error(result.error||result.message||'ระบบ Gmail ไม่พร้อมใช้งาน');return result}
export async function epcRequest(action,body,token){
 const attempts=action==='accept'||action==='leads'?2:1;
 for(let attempt=0;attempt<attempts;attempt++){
  let response;
  try{response=await fetch(url+'/functions/v1/tw-epc/'+action,{method:body===undefined?'GET':'POST',headers:{apikey:key,...(token?{Authorization:'Bearer '+token}:{}),...(body===undefined?{}:{'Content-Type':'application/json'})},...(body===undefined?{}:{body:JSON.stringify(body)}),signal:AbortSignal.timeout(20000)})}
  catch{if(attempt+1<attempts)continue;throw new Error('เชื่อมต่อระบบ EPC ไม่สำเร็จชั่วคราว กรุณากดรีเฟรชข้อมูลเพื่อตรวจสถานะ แล้วลองอีกครั้ง')}
  if([502,503,504].includes(response.status)&&attempt+1<attempts)continue;
  let result;try{result=await response.json()}catch{throw new Error('ระบบ EPC ตอบกลับไม่สมบูรณ์ กรุณารีเฟรชข้อมูลแล้วลองอีกครั้ง')}
  if(!response.ok){const e=new Error(result.error||'ระบบ EPC ไม่พร้อมใช้งานชั่วคราว กรุณาลองอีกครั้ง');e.status=response.status;throw e}return result
 }
}
