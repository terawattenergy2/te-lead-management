export function parseLeadCSV(text){
 const rows=[];let row=[],cell='',quoted=false;
 text=text.replace(/^\uFEFF/,'');
 for(let i=0;i<text.length;i++){const c=text[i];if(c==='"'){if(quoted&&text[i+1]==='"'){cell+='"';i++}else quoted=!quoted}else if(c===','&&!quoted){row.push(cell);cell=''}else if((c==='\n'||c==='\r')&&!quoted){if(c==='\r'&&text[i+1]==='\n')i++;row.push(cell);if(row.some(x=>x.trim()))rows.push(row);row=[];cell=''}else cell+=c}
 if(quoted)throw Error('เครื่องหมายคำพูดในไฟล์ไม่ครบ');row.push(cell);if(row.some(x=>x.trim()))rows.push(row);
 const headers=rows.shift()?.map(x=>x.trim())||[];
 for(const h of ['Customer Name','Phone','Province'])if(!headers.includes(h))throw Error('ไม่พบคอลัมน์ '+h+' กรุณาเลือกชีต Leads');
 if(rows.length>500)throw Error('นำเข้าได้สูงสุดครั้งละ 500 แถว');
 const seen=new Set();return rows.map((r,i)=>{const data=Object.fromEntries(headers.map((h,j)=>[h,(r[j]||'').trim()]).filter(([h])=>h&&h!=='Token'));let phone=(data.Phone||'').replace(/[ ()-]/g,'');if(/^[689]\d{8}$/.test(phone))phone='0'+phone;data.Phone=phone;const issues=[];if(!data['Customer Name']||data['Customer Name'].length>150)issues.push('ตรวจชื่อ');if(!/^(?:0\d{8,9}|\+\d{9,15})$/.test(phone))issues.push('ตรวจเบอร์โทร');if(!data.Province||data.Province.length>100)issues.push('ตรวจจังหวัด');if(data.Email&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.Email))issues.push('ตรวจอีเมล');const key=data['Lead ID']?JSON.stringify([data['Lead ID'],data['Created At']||'',data['Partner ID']||data['Partner Company']||'']):JSON.stringify(Object.entries(data).sort(([a],[b])=>a.localeCompare(b)));if(seen.has(key))issues.push('ซ้ำในไฟล์');seen.add(key);return {row:i+2,data,issues}})
}
