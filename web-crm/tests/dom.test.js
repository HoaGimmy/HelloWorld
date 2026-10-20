import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {webcrypto} from 'node:crypto';
import {JSDOM} from 'jsdom';
import * as core from '../core.js';
import {fields} from '../fields.js';
const html=fs.readFileSync(new URL('../index.html',import.meta.url),'utf8');
const script=fs.readFileSync(new URL('../app.js',import.meta.url),'utf8').replace(/^import .*;$/gm,'');
const settle=async()=>{for(let i=0;i<8;i++)await new Promise(r=>setImmediate(r))};
async function setup({allowed=true,seed=[],saveError=null}={}){
 const dom=new JSDOM(html,{url:'https://crm.example.test',runScripts:'outside-only'});const {window:w}=dom;const data=structuredClone(seed);const writes=[];
 w.HTMLDialogElement.prototype.showModal=function(){this.open=true};w.HTMLDialogElement.prototype.close=function(){this.open=false};
 const user={id:'owner',email:'owner@example.test'};
 const client={auth:{getUser:async()=>({data:{user}}),onAuthStateChange:()=>{},signOut:async()=>({}),signInWithOAuth:async()=>({})},
 rpc:async(name,args)=>{if(name==='crm_access')return {data:allowed};if(name==='crm_save'){if(saveError)return {error:{message:saveError}};const row=data.find(r=>r.id===args.p_id);row.payload=args.p_payload;row.revision++;return {data:[row]}}},
 from:()=>{let insert=null;const q={select:()=>q,eq:()=>q,order:()=>q,limit:()=>q,gt:()=>q,insert:r=>{insert=r;return q},then:resolve=>{if(insert){writes.push(insert);data.push({...insert,revision:1});return Promise.resolve(resolve({data:[insert]}))}return Promise.resolve(resolve({data:structuredClone(data)}))}};return q}};
 Object.assign(w,core,{fields,createClient:()=>client,structuredClone});Object.defineProperty(w,'crypto',{value:webcrypto});
 new vm.Script(script).runInContext(dom.getInternalVMContext());await settle();
 const click=async(text)=>{const b=[...w.document.querySelectorAll('button')].find(e=>e.textContent===text&&!e.closest('[hidden]'));assert.ok(b,'Button '+text);b.click();await settle()};
 const fill=(key,value)=>{const input=w.document.querySelector('[name="'+key+'"]');assert.ok(input,key);input.value=value};
 const submit=async()=>{w.document.getElementById('form').dispatchEvent(new w.Event('submit',{bubbles:true,cancelable:true}));await settle()};
 return {w,dom,data,writes,click,fill,submit};
}
const customer={id:'c1',entity_type:'customers',source_device_id:'iphone',source_local_id:'1',revision:1,payload:{id:1,name:'Khách <img src=x onerror=alert(1)>',phone:'0900123456',stage:'Khảo sát',created_at:'2026-10-01',updated_at:'2026-10-01'}};
test('non-owner cannot open app or create record',async()=>{const a=await setup({allowed:false});assert.equal(a.w.document.getElementById('app').hidden,true);assert.match(a.w.document.getElementById('status').textContent,/chưa được cấp quyền/);assert.equal(a.writes.length,0);a.dom.window.close()});
test('customer list safely renders HTML as text and search works',async()=>{const a=await setup({seed:[customer]});await a.click('Khách hàng');assert.equal(a.w.document.querySelectorAll('.record').length,1);assert.equal(a.w.document.querySelectorAll('.record img').length,0);const search=a.w.document.getElementById('search');search.value='không tồn tại';search.dispatchEvent(new a.w.Event('input'));assert.equal(a.w.document.querySelectorAll('.record').length,0);a.dom.window.close()});
test('new customer is saved to cloud with stable identity and correct values',async()=>{const a=await setup();await a.click('Khách hàng');await a.click('+ Thêm mới');a.fill('name','Lê Đình Hòa');a.fill('phone','0900123456');await a.submit();assert.equal(a.writes.length,1);assert.equal(a.writes[0].payload.name,'Lê Đình Hòa');assert.equal(a.writes[0].payload.phone,'0900123456');assert.equal(a.writes[0].owner_id,'owner');assert.equal(a.writes[0].id,a.writes[0].source_local_id);assert.equal(a.w.document.getElementById('editor').open,false);a.dom.window.close()});
test('stale save keeps dialog and draft for recovery',async()=>{const a=await setup({seed:[customer],saveError:'CONFLICT: stale'});await a.click('Khách hàng');await a.click('Sửa');a.fill('name','Nội dung đang nhập');await a.submit();assert.equal(a.w.document.getElementById('editor').open,true);assert.equal(a.w.document.querySelector('[name=name]').value,'Nội dung đang nhập');assert.match(a.w.document.getElementById('form-error').textContent,/thiết bị khác/);a.dom.window.close()});
test('payment cannot be saved against another customer contract',async()=>{const a=await setup({seed:[customer,{...customer,id:'c2',source_local_id:'2',payload:{name:'Khách khác'}},{id:'k1',entity_type:'contracts',source_device_id:'iphone',source_local_id:'1',revision:1,payload:{customer_id:1,code:'HĐ01'}}]});await a.click('Thu tiền');await a.click('+ Thêm mới');a.fill('customer_id','c2');a.fill('contract_id','k1');a.fill('amount','100000');a.fill('paid_at','2026-10-20');await a.submit();assert.equal(a.writes.length,0);assert.match(a.w.document.getElementById('form-error').textContent,/không khớp/);a.dom.window.close()});
