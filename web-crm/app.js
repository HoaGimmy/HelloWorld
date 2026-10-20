import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.57.4';
import {entities,stages,relations,money,validateBackup,exportBackup,related,finance,withTimestamps} from './core.js';
import {fields} from './fields.js';
const client=createClient('https://iikppjjszfcqskkfeydk.supabase.co','sb_publishable_4lTJHWMvtXoatUcaJkEk_g_Wthu7m0g',{auth:{flowType:'pkce',persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
const $=id=>document.getElementById(id);
let user=null,records=[],view='dashboard',editing=null,pending=null,busy=false,authGeneration=0,loading=false;
const el=(tag,text,cls)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;return e};
function status(text){$('status').textContent=text}
function errorText(e){return e?.message||String(e)}
function button(text,fn,cls){const b=el('button',text,cls);b.type='button';b.onclick=fn;return b}
function clear(){records=[];pending=null;editing=null;user=null;$('list').replaceChildren();$('dashboard').replaceChildren();$('preview').textContent='';$('file').value='';$('form').reset();$('fields').replaceChildren();$('editor').close();$('app').hidden=true;$('login').hidden=false;$('logout').hidden=true}
async function authenticate(){
 const generation=++authGeneration;
 try{
  const {data,error}=await client.auth.getUser();if(generation!==authGeneration)return;
  if(error||!data.user){clear();status('Đăng nhập để sử dụng CRM.');return}
  const {data:allowed,error:accessError}=await client.rpc('crm_access');if(generation!==authGeneration)return;
  if(accessError||allowed!==true){clear();status(accessError?'Chưa kiểm tra được quyền máy chủ: '+accessError.message:'Tài khoản chưa được cấp quyền chủ sở hữu.');return}
  user=data.user;$('login').hidden=true;$('app').hidden=false;$('logout').hidden=false;$('identity').textContent=user.email;renderNav();await load();
 }catch(e){if(generation===authGeneration){clear();status('Không thể đăng nhập: '+errorText(e))}}
}
async function load(){
 if(!user||loading)return;loading=true;const uid=user.id;const generation=authGeneration;
 try{
  const next=[];let after=null;
  do{let q=client.from('crm_records').select('*').eq('owner_id',uid).order('id').limit(500);if(after)q=q.gt('id',after);
   const {data,error}=await q;if(error)throw error;next.push(...data);after=data.length===500?data.at(-1).id:null;
  }while(after);
  if(user?.id!==uid||generation!==authGeneration)return;
  records=next;render();status('Đã tải dữ liệu cloud · '+new Date().toLocaleTimeString('vi-VN')+' · iPhone: chuyển dữ liệu qua JSON');
 }catch(e){status('Chưa tải được dữ liệu. '+errorText(e))}finally{loading=false}
}
function renderNav(){
 $('nav').replaceChildren();for(const [key,label] of Object.entries({dashboard:'Tổng quan',...entities,backup:'Sao lưu & iPhone'}))$('nav').append(button(label,()=>{view=key;$('search').value='';$('period').value='';render()},key===view?'active':''));
}
function rows(t){return records.filter(r=>r.entity_type===t&&!r.deleted_at)}
function render(){renderNav();$('title').textContent=view==='dashboard'?'Tổng quan':view==='backup'?'Sao lưu & iPhone':entities[view];$('toolbar').hidden=!entities[view];$('backup').hidden=view!=='backup';$('dashboard').replaceChildren();$('list').replaceChildren();
 if(view==='dashboard'){const cards=el('div',undefined,'cards');
  for(const stage of [null,'Khảo sát','Báo giá','Đang tư vấn','Đàm phán','Chốt hợp đồng'])cards.append(button((stage||'Tổng khách hàng')+' · '+rows('customers').filter(r=>!stage||r.payload.stage===stage).length,()=>{view='customers';$('search').value=stage||'';render()},'card'));
  const f=finance(records);for(const [label,value] of [['Hợp đồng',f.value],['Đã thu',f.paid],['Còn phải thu',f.remaining],['Hoa hồng dự kiến',f.commission]]){const card=el('div',label,'card');card.append(el('b',money(value)));cards.append(card)}
  $('dashboard').append(cards,el('h2','Công việc cần theo dõi'));
  const today=new Date().toLocaleDateString('en-CA');const urgent=rows('tasks').filter(r=>!Number(r.payload.completed)&&String(r.payload.due_date)<=today);if(!urgent.length)$('list').append(el('p','Không có công việc đến hạn.','empty'));urgent.forEach(drawRecord);return;
 }
 if(!entities[view])return;
 const term=$('search').value.trim().toLocaleLowerCase('vi');const period=$('period').value;
 const filtered=rows(view).filter(r=>JSON.stringify(r.payload).toLocaleLowerCase('vi').includes(term)&&(!period||String(r.payload.created_at||r.payload.paid_at||r.payload.starts_at||r.payload.due_date||r.created_at).startsWith(period)));
 $('list').append(el('small',filtered.length+' bản ghi'));if(!filtered.length)$('list').append(el('p','Chưa có dữ liệu phù hợp. Thêm mới hoặc nhập bản sao lưu iPhone.','empty'));filtered.forEach(drawRecord);
}
function label(r){return r.payload.name||r.payload.title||r.payload.code||entities[r.entity_type]}
function drawRecord(r){const p=r.payload;const card=el('article',undefined,'record');const detail=el('div');detail.append(el('h3',label(r)));const parent=related(records,r,'customer_id');if(parent)detail.append(el('p',label(parent)));if(p.stage||p.status)detail.append(el('span',p.stage||p.status,'badge'));for(const key of ['phone','address','due_date','starts_at','install_date','note'])if(p[key])detail.append(el('p',String(p[key])));
 if(p.value!=null||p.amount!=null)detail.append(el('p',money(p.value??p.amount)));
 if(r.entity_type==='contracts'){const paid=rows('payments').filter(x=>related(records,x,'contract_id')?.id===r.id).reduce((s,x)=>s+(Number(x.payload.amount)||0),0);detail.append(el('p','Đã thu: '+money(paid)+' · Còn: '+money(Number(p.value)-paid)))}
 if(p.phone){const phone=String(p.phone).replace(/[^+\d]/g,'');if(phone){for(const [prefix,title] of [['tel:','Gọi'],['sms:','SMS']]){const a=el('a',title);a.href=prefix+phone;detail.append(a)}detail.append(button('Sao chép SĐT',async()=>{try{await navigator.clipboard.writeText(p.phone);status('Đã sao chép số điện thoại')}catch{status('Trình duyệt không cho phép sao chép.')}}))}}
 card.append(detail,button('Sửa',()=>openEditor(r)));$('list').append(card);
}
function openEditor(r=null){editing=r;const t=r?.entity_type||view;$('form-title').textContent=(r?'Sửa ':'Thêm ')+entities[t];$('form-error').textContent='';$('fields').replaceChildren();
 for(const [key,title,type='text',required=false] of fields[t]){const l=el('label',title);let input;let value=r?.payload[key]??'';
  if(entities[type]||type==='stage'||type==='boolean'){input=el('select');const opts=type==='stage'?stages.map(s=>[s,s]):type==='boolean'?[[0,'Chưa hoàn thành'],[1,'Đã hoàn thành']]:[['','— Chọn —'],...rows(type).map(x=>[x.id,label(x)])];
   if(entities[type]&&r&&value!=='')value=related(records,r,key)?.id??'';
   if(type==='stage'&&value&&!opts.some(([v])=>v===value))opts.push([value,value]);
   for(const [v,text] of opts){const option=el('option',text);option.value=v;input.append(option)}
  }else{input=el(type==='textarea'?'textarea':'input');if(type!=='textarea'){input.type=type==='percent'?'number':type;if(type==='number'||type==='percent'){input.min=0;input.step='any';if(type==='percent')input.max=100}}}
  input.name=key;input.required=required;input.value=String(value);if(r==null&&key==='stage')input.value='Khách mới';if(r==null&&key==='company_cost_percent')input.value='8';if(r==null&&key==='commission_share_percent')input.value='40';if(r==null&&key==='warranty_months')input.value='12';
  l.append(input);$('fields').append(l);
 }
 $('editor').showModal();
}
$('form').onsubmit=async event=>{event.preventDefault();if(busy||!user)return;busy=true;$('save').disabled=true;const uid=user.id;const generation=authGeneration;
 try{const t=editing?.entity_type||view;let p={...(editing?.payload||{})};const form=new FormData($('form'));
  // Convert all existing local relationships before moving a payload between devices.
  if(editing)for(const k of Object.keys(relations))if(p[k]!=null&&p[k]!==''){const target=related(records,editing,k);if(!target)throw Error('Thiếu liên kết '+k);p[k]=target.id}
  for(const [key,,type='text'] of fields[t]){const raw=String(form.get(key)||'').trim();p[key]=['number','percent','boolean'].includes(type)?Number(raw)||0:entities[type]?(raw||null):raw;if(['number','percent'].includes(type)&&(!Number.isFinite(p[key])||p[key]<0||(type==='percent'&&p[key]>100)))throw Error('Giá trị số không hợp lệ')}
  if(p.contract_id){const contract=records.find(r=>r.id===p.contract_id);if(related(records,contract,'customer_id')?.id!==p.customer_id)throw Error('Khách hàng không khớp với hợp đồng.')}
  if(p.project_id){const project=records.find(r=>r.id===p.project_id);if(related(records,project,'customer_id')?.id!==p.customer_id)throw Error('Khách hàng không khớp với công trình.')}
  p=withTimestamps(t,p);
  let result;if(editing){result=await client.rpc('crm_save',{p_id:editing.id,p_revision:editing.revision,p_payload:p})}else{const id=crypto.randomUUID();result=await client.from('crm_records').insert({id,owner_id:uid,entity_type:t,source_device_id:'web',source_local_id:id,payload:p}).select('id')}
  if(result.error)throw result.error;if(!result.data?.length)throw Error('Chưa xác nhận được dữ liệu đã lưu.');
  if(user?.id===uid&&generation===authGeneration){$('editor').close();await load();status('Đã lưu lên cloud. iPhone hiện tại chưa tự động đồng bộ.');}
 }catch(e){$('form-error').textContent=errorText(e).includes('CONFLICT')?'Dữ liệu đã thay đổi trên thiết bị khác. Nội dung anh nhập vẫn ở đây; hãy sao chép lại trước khi đóng và tải bản mới.':errorText(e)}finally{busy=false;$('save').disabled=false}
};
$('close').onclick=()=>{if(!busy)$('editor').close()};$('editor').addEventListener('cancel',e=>{if(busy)e.preventDefault()});
$('google').onclick=async()=>{try{const {error}=await client.auth.signInWithOAuth({provider:'google',options:{redirectTo:location.origin+location.pathname}});if(error)throw error}catch(e){status(errorText(e))}};
$('logout').onclick=async()=>{if(busy){status('Hãy đợi thao tác lưu hoàn tất trước khi đăng xuất.');return}++authGeneration;clear();const {error}=await client.auth.signOut();status(error?'Đăng xuất chưa thành công: '+error.message:'Đã đăng xuất.')};
$('refresh').onclick=load;$('search').oninput=render;$('period').onchange=render;$('add').onclick=()=>openEditor();
$('file').onchange=async()=>{pending=null;$('import').disabled=true;try{const file=$('file').files[0];if(!file)return;if(file.size>20*1024*1024)throw Error('File vượt quá 20 MB.');pending=validateBackup(JSON.parse(await file.text()));const counts={};pending.forEach(r=>counts[r.entity_type]=(counts[r.entity_type]||0)+1);$('preview').textContent=Object.entries(counts).map(([t,n])=>entities[t]+': '+n).join('\n')+'\nKhông nhập cài đặt Google, không xóa bản ghi cũ.';$('import').disabled=!pending.length}catch(e){$('preview').textContent=errorText(e)}};
$('import').onclick=async()=>{if(busy||!pending||!user)return;const device=$('device').value.trim();if(!/^[a-zA-Z0-9_-]{1,100}$/.test(device)){status('Tên nguồn chỉ gồm chữ không dấu, số, - và _.');return}busy=true;$('import').disabled=true;try{const {data,error}=await client.rpc('crm_import',{p_device:'ios-'+device,p_rows:pending});if(error)throw error;pending=null;$('file').value='';$('preview').textContent='Đã nhập '+data+' bản ghi mới. Bản giống hệt được bỏ qua.';await load()}catch(e){status('Chưa nhập dữ liệu: '+errorText(e))}finally{busy=false;$('import').disabled=!pending}};
$('export').onclick=()=>{try{const backup=exportBackup(records);const blob=new Blob([JSON.stringify(backup,null,2)],{type:'application/json'});const url=URL.createObjectURL(blob);const a=el('a');a.href=url;a.download='MPWindows_Web_Backup_'+new Date().toISOString().slice(0,10)+'.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);status('Đã xuất JSON. Sao lưu iPhone trước khi nhập gộp; không nhập lặp cùng file.')}catch(e){status(errorText(e))}};
client.auth.onAuthStateChange(event=>{if(event==='SIGNED_OUT'){++authGeneration;clear();status('Đã đăng xuất.')}else if(event!=='TOKEN_REFRESHED')setTimeout(authenticate,0)});
window.addEventListener('online',()=>{status('Đã có mạng. Bấm Làm mới để tải dữ liệu mới nhất.')});window.addEventListener('offline',()=>status('Mất mạng. Nội dung đang nhập vẫn giữ trong cửa sổ; chưa được lưu lên cloud.'));
window.addEventListener('beforeunload',e=>{if(busy||$('editor').open){e.preventDefault();e.returnValue=''}});
authenticate();
