import test from 'node:test';import assert from 'node:assert/strict';
import {validateBackup,exportBackup,related,finance} from '../core.js';
const snapshot={format:'mpwindows-crm-backup',version:1,tables:{customers:[{id:1,name:'Hòa',phone:'0900123456'}],projects:[{id:2,customer_id:1,name:'Cửa nhôm'}],contracts:[{id:3,project_id:2,customer_id:1,value:100000000,profit_percent:18,company_cost_percent:8,commission_share_percent:40}],payments:[{id:4,contract_id:3,customer_id:1,amount:20000000}],app_settings:[{setting_key:'secret',setting_value:'do-not-upload'}]}};
function records(device='iphone-a'){return validateBackup(snapshot).map((r,i)=>({...r,id:device+'-'+i,source_device_id:device}))}
test('backup validation preserves Vietnamese and excludes device settings',()=>{const r=validateBackup(snapshot);assert.equal(r.length,4);assert.equal(r[0].payload.name,'Hòa');assert.equal(r[0].payload.phone,'0900123456');assert.equal(snapshot.tables.customers[0].id,1)});
test('rejects malformed format, missing parent and duplicate ids before writes',()=>{for(const change of [s=>s.version=2,s=>s.tables.customers=[],s=>s.tables.customers.push({...s.tables.customers[0]})]){const s=structuredClone(snapshot);change(s);assert.throws(()=>validateBackup(s))}});
test('device namespaces disambiguate identical local integer ids',()=>{const all=[...records(),...records('iphone-b')];assert.equal(related(all,all[7],'customer_id').id,'iphone-b-0')});
test('export remaps relationships to iOS integer IDs across devices',()=>{const all=[...records(),...records('iphone-b')];const out=exportBackup(all);assert.equal(out.tables.payments[1].customer_id,2);assert.equal(out.tables.payments[1].contract_id,2);assert.equal(out.tables.contracts[1].project_id,2);assert.deepEqual(out.tables.app_settings,[]);assert.equal(validateBackup(out).length,8)});
test('export supports UUID relations written by web and rejects dangling links',()=>{const all=records();all[3].payload.contract_id=all[2].id;assert.equal(exportBackup(all).tables.payments[0].contract_id,1);all[2].deleted_at='2026-01-01';assert.throws(()=>exportBackup(all))});
test('contract commission and receivable follow company formula',()=>{assert.deepEqual(finance(records()),{value:100000000,paid:20000000,remaining:80000000,commission:4000000})});

import {withTimestamps} from '../core.js';
test('new web records only receive timestamp columns supported by iPhone SQLite',()=>{
 for(const t of ['tasks','appointments','payments'])assert.deepEqual(withTimestamps(t,{title:'Mẫu'}),{title:'Mẫu'});
 for(const t of ['contracts','quotes','activities']){const p=withTimestamps(t,{},'2026-10-20');assert.equal(p.created_at,'2026-10-20');assert.equal(p.updated_at,undefined)}
 assert.deepEqual(withTimestamps('customers',{created_at:'old'},'new'),{created_at:'old',updated_at:'new'});
});
