export const entities={customers:'Khách hàng',activities:'Chăm sóc',tasks:'Công việc',appointments:'Lịch hẹn',projects:'Công trình',quotes:'Báo giá',contracts:'Hợp đồng',payments:'Thu tiền'};
export const stages=['Khách mới','Đã liên hệ','Đang tư vấn','Khảo sát','Báo giá','Đàm phán','Chốt hợp đồng','Thi công','Hoàn thành','Chăm sóc sau bán','Không thành công / Mất khách'];
export const relations={customer_id:'customers',project_id:'projects',contract_id:'contracts'};
export const money=n=>new Intl.NumberFormat('vi-VN',{style:'currency',currency:'VND',maximumFractionDigits:0}).format(Number(n)||0);
export function validateBackup(s){
 if(s?.format!=='mpwindows-crm-backup'||s.version!==1||!s.tables||typeof s.tables!=='object')throw Error('Không đúng định dạng sao lưu MPWindows v1.');
 const result=[];const ids={};
 for(const t of Object.keys(entities)){
  const rows=s.tables[t]??[];if(!Array.isArray(rows))throw Error('Bảng không hợp lệ: '+t);
  ids[t]=new Set();
  for(const row of rows){
   if(!row||typeof row!=='object'||Array.isArray(row)||!Number.isSafeInteger(row.id)||row.id<1||ids[t].has(row.id))throw Error('ID thiếu hoặc trùng: '+t);
   ids[t].add(row.id);result.push({entity_type:t,source_local_id:String(row.id),payload:structuredClone(row)});
  }
 }
 if(result.length>10000)throw Error('Tối đa 10.000 bản ghi mỗi lần nhập.');
 for(const r of result)for(const [k,t] of Object.entries(relations))if(r.payload[k]!=null&&!ids[t].has(r.payload[k]))throw Error('Thiếu liên kết '+k+' ở '+r.entity_type+' #'+r.source_local_id);
 return result;
}
export function related(records,record,key){
 const value=record.payload[key];if(value==null||value==='')return null;
 return records.find(r=>r.entity_type===relations[key]&&(r.id===value||(r.source_device_id===record.source_device_id&&r.source_local_id===String(value))))??null;
}
export function exportBackup(records){
 const live=records.filter(r=>!r.deleted_at&&entities[r.entity_type]);const maps={};const tables={};
 for(const t of Object.keys(entities)){
  tables[t]=[];maps[t]=new Map(live.filter(r=>r.entity_type===t).map((r,i)=>[r.id,i+1]));
 }
 for(const r of live){const p={...r.payload,id:maps[r.entity_type].get(r.id)};
  for(const k of Object.keys(relations))if(p[k]!=null&&p[k]!==''){
   const target=related(live,r,k);if(!target)throw Error('Thiếu liên kết: '+k);p[k]=maps[relations[k]].get(target.id);
  }
  tables[r.entity_type].push(p);
 }
 tables.app_settings=[];return {format:'mpwindows-crm-backup',version:1,databaseVersion:10,createdAt:new Date().toISOString(),tables};
}
export function finance(records){
 const contracts=records.filter(r=>r.entity_type==='contracts'&&!r.deleted_at);
 const payments=records.filter(r=>r.entity_type==='payments'&&!r.deleted_at);
 const value=contracts.reduce((s,r)=>s+(Number(r.payload.value)||0),0);
 const paid=payments.reduce((s,r)=>s+(Number(r.payload.amount)||0),0);
 const commission=contracts.reduce((s,r)=>{const p=r.payload;return s+(Number(p.value)||0)*Math.max(0,(Number(p.profit_percent)||0)-(Number(p.company_cost_percent)||0))/100*(Number(p.commission_share_percent)||0)/100},0);
 return {value,paid,remaining:value-paid,commission};
}

export function withTimestamps(type,payload,now=new Date().toISOString()) {
 const p={...payload};
 if(['customers','projects'].includes(type))p.updated_at=now;
 if(['customers','projects','activities','quotes','contracts'].includes(type)&&!p.created_at)p.created_at=now;
 return p;
}
