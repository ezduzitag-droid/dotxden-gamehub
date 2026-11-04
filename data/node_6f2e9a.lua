-- REFTOOLS-MODULE-V1.0.0
-- Revision 1.4.0 | Verified actor health +0xB4; canonical stat-array controls; money preserved.
-- Finds and validates runtime pointers before offering stat edits.
local V='1.4.0'
local SIG='-1992893169D;-1946824447D;-268807205D;1873603068D::13'
local SVAL={-1992893169,-1946824447,-268807205,1873603068}
local F={{'health',0x76EA10,128},{'healthLimit',0x76EA14,132},{'spirit',0x76EA18,136},
         {'injury',0x76EA1C,140},{'bank',0x76EBD4,56},{'cStar',0x770FBC,32}}
local C={Progress=0x02000015,Characters=0x020000AB,Character=0x02000008,LOCECKLDEDA=0x02000058,EFPJKAPKGOB=0x02000032}
local S={anchor=nil,base=nil,fields=0,classes={},health=nil,bank=nil,star=nil,
         healthOK=false,bankOK=false,issues={}}
local function hx(n) return n and string.format('0x%X',n) or 'none' end
local function lamp(n) return n and '🟢' or '🔴' end
local function issue(s) S.issues[#S.issues+1]=s end
local function batch(r)
  local ok,v=pcall(gg.getValues,r)
  if not ok or type(v)~='table' or #v~=#r then return nil end
  for _,x in ipairs(v) do if tonumber(x.value)==nil then return nil end end
  return v
end
local function read(a,t)
  if not a or a<0x10000 then return nil end
  local v=batch({{address=a,flags=t}})
  return v and tonumber(v[1].value) or nil
end
local function Q(a) return read(a,gg.TYPE_QWORD) end
local function D(a) return read(a,gg.TYPE_DWORD) end
local function R(a) return read(a,gg.TYPE_FLOAT) end
local function nameAt(p,s)
  if not p or p<0x10000 then return false end
  local b={}
  for i=1,#s+1 do b[i]={address=p+i-1,flags=gg.TYPE_BYTE} end
  local v=batch(b);if not v then return false end
  for i=1,#s do if v[i].value~=s:byte(i) then return false end end
  return v[#s+1].value==0
end
local function xa()
  gg.clearResults();gg.setRanges(gg.REGION_CODE_APP)
  gg.searchNumber(SIG,gg.TYPE_DWORD)
  local n=gg.getResultsCount()
  if n~=4 then issue('Xa returned '..n..' DWORD results (expected 4)');gg.clearResults();return false end
  local h=gg.getResults(4);gg.clearResults()
  table.sort(h,function(a,b)return a.address<b.address end)
  for i=1,4 do
    if tonumber(h[i].value)~=SVAL[i] or (i>1 and h[i].address~=h[1].address+4*(i-1)) then
      issue('Xa signature is not an ordered single group');return false
    end
  end
  S.anchor=h[1].address;S.base=S.anchor-0x318
  local req={}
  for i,f in ipairs(F) do req[i]={address=S.anchor+f[2],flags=gg.TYPE_DWORD} end
  local vals=batch(req)
  if not vals then issue('Cannot read field-offset table');return false end
  for i,f in ipairs(F) do
    if vals[i].value==f[3] then S.fields=S.fields+1 else issue(f[1]..' table entry mismatch') end
  end
  return S.fields==6
end
-- Native exports prove the IL2CPP runtime class offsets:
-- name +0x10; static_fields +0xB8; type token +0x11C.
local function klass(name,slow)
  local regions=gg.REGION_ANONYMOUS|gg.REGION_C_ALLOC|gg.REGION_C_HEAP|
                gg.REGION_C_DATA|gg.REGION_C_BSS|(slow and gg.REGION_OTHER or 0)
  gg.clearResults();gg.setRanges(regions)
  gg.searchNumber(tostring(C[name]),gg.TYPE_DWORD,false,gg.SIGN_EQUAL,0,-1,2048)
  local n=gg.getResultsCount()
  if n==0 or n>2048 then gg.clearResults();issue(name..': token candidates='..n);return end
  local hits=gg.getResults(n);gg.clearResults()
  local matches,visited={},{}
  for _,h in ipairs(hits) do
    local p=h.address-0x11C
    if p>0x10000 and not visited[p] then
      visited[p]=true
      local v=batch({{address=p+0x10,flags=gg.TYPE_QWORD},
                     {address=p+0xB8,flags=gg.TYPE_QWORD},
                     {address=p+0x11C,flags=gg.TYPE_DWORD}})
      if v and v[3].value==C[name] and nameAt(v[1].value,name) then
        matches[#matches+1]={address=p,storage=v[2].value,token=C[name]}
      end
    end
  end
  if #matches==1 then return matches[1] end
  local initialized={}
  for _,m in ipairs(matches) do if m.storage>0x10000 then initialized[#initialized+1]=m end end
  if #initialized==1 then return initialized[1] end
  issue(name..': found '..#matches..' classes; no unique initialized class')
end
local function bind(slow)
  local old=gg.getRanges()
  S={anchor=nil,base=nil,fields=0,classes={},health=nil,bank=nil,star=nil,
     healthOK=false,bankOK=false,issues={}}
  local ok,err=pcall(function()
    if not xa() then return end
    S.classes.Progress=klass('Progress',slow)
    S.classes.Characters=klass('Characters',slow)
    local p=S.classes.Progress
    if p and p.storage>0x10000 and D(p.storage+0x38)~=nil then S.bank=p.storage+0x38
    else issue('Progress.bank not mapped or initialized') end
    local cs=S.classes.Characters
    if not cs or cs.storage<0x10000 then issue('Characters static block not ready');return end
    local obj=Q(cs.storage+0x20)
    if not obj or obj<0x10000 then issue('cStar null');return end
    local cc=Q(obj)
    local nm=cc and Q(cc+0x10)
    if cc and D(cc+0x11C)==C.Character and nameAt(nm,'Character') then
      local h,limit=R(obj+0x80),R(obj+0x84)
      if h and limit and h==h and limit>=0 and limit<1000000 and h>-1000000 and h<1000000 then
        S.star=obj;S.health=obj+0x80
      else issue('Character floats implausible') end
    else issue('cStar does not point to a validated Character object') end
  end)
  pcall(gg.clearResults);pcall(gg.setRanges,old)
  if not ok then issue('Runtime resolver error: '..tostring(err)) end
end
local function status()
  return lamp(S.anchor~=nil)..' Xa  '..lamp(S.fields==6)..' fields  '..
         lamp(S.bank~=nil)..' money'
end
local function info()
  local lines={'Reference Tools '..V,'Loaded from the existing fixed GitHub raw path','',status(),
    'IL2CPP base: '..hx(S.base),'Character record: '..hx(S.star),
    'Health address: '..hx(S.health),'Bank address: '..hx(S.bank),
    lamp(S.healthOK)..' HUD health match',lamp(S.bankOK)..' HUD bank match',
    '🔴 Spawning not mapped','',
    'Validated memory pointers are not yet proven live gameplay controls.'}
  for _,s in ipairs(S.issues) do lines[#lines+1]='- '..s end
  gg.alert(table.concat(lines,'\n'))
end
-- Availability means a validated, readable runtime address. It does NOT prove HUD effects.
local function addrFor(kind)
  if kind=='bank' then return S.bank,gg.TYPE_DWORD end
  local offsets={health=0,healthLimit=4,spirit=8,injury=12}
  if not S.health or offsets[kind]==nil then return nil,nil end
  return S.health+offsets[kind], kind=='injury' and gg.TYPE_DWORD or gg.TYPE_FLOAT
end

local function canEdit(kind)
  if kind~='bank' then return false end -- Character data was NOT the live controller in tests.
  local addr,kindFlag=addrFor(kind)
  if not addr or not S.anchor or S.fields~=6 then return false end
  if (kind=='bank' and not S.classes.Progress) or
     (kind~='bank' and not S.classes.Characters) then return false end
  local value=read(addr,kindFlag)
  return value~=nil and value==value
end

local function verifyPointer(kind)
  local p=S.classes[kind=='bank' and 'Progress' or 'Characters']
  if not p or not S.anchor or S.fields~=6 then return false,'Setup has not passed all checks' end
  if D(S.anchor)~=SVAL[1] or D(p.address+0x11C)~=p.token or
     Q(p.address+0xB8)~=p.storage then
    return false,'Module/class pointer changed'
  end
  if kind=='bank' then
    if not S.bank or S.bank~=p.storage+0x38 then return false,'Bank field pointer changed' end
  else
    if not S.star or not S.health or Q(p.storage+0x20)~=S.star then
      return false,'Active character pointer changed'
    end
    local cl=Q(S.star)
    if not cl or D(cl+0x11C)~=C.Character then
      return false,'Character class pointer changed'
    end
  end
  return true
end

local function readDisplay(kind)
  local addr,flag=addrFor(kind)
  if not addr then gg.alert('🔴 Unavailable. Select Setup / Re-scan first.');return end
  local val=read(addr,flag)
  gg.alert((val~=nil and '🟢 ' or '🔴 ')..kind..
          '\nCurrent candidate: '..tostring(val)..'\nAddress: '..hx(addr)..
          '\nType: '..(flag==gg.TYPE_DWORD and 'Dword' or 'Float')..
          '\nThis value is from the resolved runtime object. Confirm it in the game.')
end

local function edit(kind)
  if kind~='bank' then gg.alert('🔴 Stored Character health is not live. Use the active actor probe.');return end
  if not canEdit(kind) then gg.alert('🔴 '..kind..' is unavailable. Run Setup / Re-scan.');return end
  local valid,reason=verifyPointer(kind)
  if not valid then
    if kind=='bank' then S.bank=nil else S.health=nil;S.star=nil end
    gg.alert('🔴 Binding changed: '..tostring(reason)..'\nRun Setup / Re-scan.')
    return
  end
  local addr,flag=addrFor(kind)
  local current=read(addr,flag)
  if current==nil then gg.alert('🔴 Runtime value unreadable. Re-scan.');return end
  local prompt=gg.prompt({'New '..kind..' value'}, {[1]=tostring(current)}, {[1]='number'})
  if not prompt then return end
  local nextValue=tonumber(prompt[1])
  if not nextValue or nextValue~=nextValue or nextValue==math.huge or nextValue==-math.huge then
    gg.alert('Invalid number. No change made.');return
  end
  if kind=='health' then
    local lim=R(S.health+4)
    if not lim or nextValue<0 or nextValue>math.min(lim,1000000) then
      gg.alert('Health must be between 0 and the current health limit ('..tostring(lim)..').')
      return
    end
  elseif kind=='healthLimit' then
    local h=R(S.health)
    if nextValue<1 or nextValue>1000000 or (h and nextValue<h) then
      gg.alert('Maximum health must be at least current health and at most 1,000,000.');return
    end
  elseif kind=='spirit' then
    if nextValue<0 or nextValue>1000000 then
      gg.alert('Spirit must be between 0 and 1,000,000.');return
    end
  elseif kind=='injury' then
    if nextValue~=math.floor(nextValue) or nextValue<0 or nextValue>1000000 then
      gg.alert('Injury must be an integer between 0 and 1,000,000.');return
    end
  elseif kind=='bank' then
    if nextValue~=math.floor(nextValue) or nextValue<0 or nextValue>2000000000 then
      gg.alert('Bank must be an integer between 0 and 2,000,000,000.');return
    end
  end
  local ok,result=pcall(gg.setValues,{{address=addr,flags=flag,value=tostring(nextValue)}})
  if not ok or result==false then
    gg.alert('Write failed: '..tostring(result));return
  end
  local after=read(addr,flag)
  local matches=after and math.abs(after-nextValue)<(flag==gg.TYPE_FLOAT and 0.01 or 0.1)
  gg.alert((matches and '🟢 Write readback matched' or '🔴 Readback mismatch')..
           '\nField: '..kind..
           '\nBefore: '..tostring(current)..'\nRequested: '..tostring(nextValue)..
           '\nReadback: '..tostring(after)..'\nAddress: '..hx(addr)..
           '\nNow verify the HUD/gameplay. A write readback is not proof of game effect.')
end

local function setupReport()
  local lines={'SETUP / Xa + runtime pointers','',
    '4 Xa DWORDs: '..(S.anchor and 'PASS' or 'FAIL'),
    'Compiled field offsets: '..tostring(S.fields)..'/6',
    'First Xa signature address: '..hx(S.anchor),
    'IL2CPP module base: '..hx(S.base),'',
    'GROUP READBACK:'}
  if S.anchor then
    for i,v in ipairs(SVAL) do
      lines[#lines+1] = hx(S.anchor+4*(i-1))..' = '..tostring(D(S.anchor+4*(i-1)))..' (expected '..v..')'
    end
  else
    lines[#lines+1]='Signature missing'
  end
  lines[#lines+1]=''
  lines[#lines+1]='LIVE BINDINGS:'
  for _,kind in ipairs({'health','healthLimit','spirit','injury','bank'}) do
    local addr,flag=addrFor(kind)
    lines[#lines+1]=lamp(canEdit(kind))..' '..kind..'  '..hx(addr)..'  = '..tostring(addr and read(addr,flag) or 'not found')
  end
  lines[#lines+1]=''
  lines[#lines+1]='Green = readable, validated candidate address; gameplay effect unconfirmed.'
  for _,e in ipairs(S.issues) do lines[#lines+1]='- '..e end
  gg.alert(table.concat(lines,'\n'))
end
local function fieldInfo()
  if not S.anchor then gg.alert('Xa unavailable');return end
  local lines={'Verified compiled offsets (not live stats):'}
  for _,f in ipairs(F) do
    lines[#lines+1]=f[1]..' '..hx(S.anchor+f[2])..' => '..f[3]
  end
  gg.alert(table.concat(lines,'\n'))
end
local function spawnInfo()
  gg.alert('🔴 Spawning not bound.\nStock fields: id +0x10, type +0x14, variant +0x18, location +0x2C, xyz +0x30/+0x34/+0x38.\nSaveData.stockFurniture +0x1A8, stockWeapons +0x1B0.\nThese are data layouts, NOT verified spawn calls. GameGuardian Lua cannot directly invoke an ARM64 IL2CPP function.')
end

-- Binary-derived actor discovery, class EFPJKAPKGOB (0x02000032).
-- Manager LOCECKLDEDA (0x02000058) stores an actor[] at static +0x20.
-- Actor has a Character reference at +0x20; this is NOT its health offset.
local FLOAT_OFF={
  0x38,0x44,0x48,0x4C,0x50,0x54,0x58,0x5C,0x60,0x78,0x7C,0x80,0x84,0x88,0x8C,0x90,0x94,
  0xB4,0xB8,0xBC,0xC0,0xC4,0xC8,0xCC,0xD0,0xD4,0xF0,0xF4,0x110,0x130,0x134,
  0x150,0x154,0x158,0x15C,0x160,0x164,0x168,0x16C,0x170,0x188,0x18C,0x194,0x198,
  0x1DC,0x1E4,0x1E8,0x1EC,0x1F0,0x1F4,0x210,0x220,0x224,0x228,0x244,0x25C,0x260,
  0x280,0x28C,0x290,0x294,0x298,0x2A4,0x2A8,0x2D4,0x2D8,0x2DC,0x2E8,
  0x2FC,0x300,0x304,0x318,0x328,0x32C,0x330,0x334,0x338,0x33C,0x35C,0x368,0x378,
  0x3C8,0x3CC,0x3F0,0x3F4,0x3F8,0x3FC,0x400,0x404,0x408,0x40C,0x410,
  0x414,0x418,0x41C,0x420,0x424,0x440,0x444,0x448,0x458,
  0x460,0x464,0x468,0x470,0x474,0x478,0x47C,0x4A8,0x4AC,
  0x4E0,0x4E4,0x4E8,0x4EC,0x4F0,0x4F4,0x504,0x50C,0x518,0x51C,0x520,
  0x524,0x528,0x52C,0x530,0x558,0x55C,0x568,0x56C
}
local function actorOk()
  if not S.actor or not S.star or Q(S.actor+0x20)~=S.star then return false end
  local c=Q(S.actor)
  return c~=nil and D(c+0x11C)==C.EFPJKAPKGOB
end
local function actorScan(slow)
  S.actor=nil;S.actorIndex=nil;S.baseline=nil;S.diff=nil
  S.selected=nil;S.pending=nil;S.liveHealthOffset=nil;S.liveHealthConfirmed=false
  S.actorIssue=nil
  if not S.star then S.actorIssue='Character.cStar not initialized';return false end
  local manager=klass('LOCECKLDEDA',slow)
  if not manager or not manager.storage or manager.storage<0x10000 then
    S.actorIssue='Player array manager not found';return false end
  local array=Q(manager.storage+0x20)
  local n=array and Q(array+0x18) or nil
  if not n or n<1 or n>512 or math.floor(n)~=n then
    S.actorIssue='No valid runtime player array. Enter gameplay.';return false end
  local req={}
  for i=0,math.min(n,256)-1 do req[#req+1]={address=array+0x20+i*8,flags=gg.TYPE_QWORD} end
  local list=batch(req)
  if not list then S.actorIssue='Player pointer array unreadable';return false end
  local ptrReq,indices={},{}
  for i,v in ipairs(list) do
    if v.value and v.value>0x10000 then
      ptrReq[#ptrReq+1]={address=v.value+0x20,flags=gg.TYPE_QWORD}
      indices[#indices+1]=i-1
    end
  end
  if #ptrReq==0 then S.actorIssue='Empty player array';return false end
  local chars=batch(ptrReq)
  if not chars then S.actorIssue='Player Character references unreadable';return false end
  local found={}
  for i,v in ipairs(chars) do
    if v.value==S.star then
      local obj=ptrReq[i].address-0x20
      local cl=Q(obj)
      if cl and D(cl+0x11C)==C.EFPJKAPKGOB then
        found[#found+1]={obj=obj,index=indices[i]}
      end
    end
  end
  if #found~=1 then
    S.actorIssue='Matching active actor instances: '..#found..' (expected 1)'
    return false
  end
  S.actor=found[1].obj;S.actorIndex=found[1].index
  -- The field-offset table at libil2cpp +0x76F65C defines actor Float +0xB4.
  -- Live health at that offset was verified by the tester in two game sessions.
  if S.anchor and D(S.anchor+0x76F344)==0xB4 and actorOk() then
    S.liveHealthOffset=0xB4
    S.liveHealthConfirmed=true
  else
    S.actorIssue='Actor field-offset entry 0xB4 did not pass verification'
  end
  return true
end
local function floats()
  if not actorOk() then return nil end
  local req={}
  for i,o in ipairs(FLOAT_OFF) do req[i]={address=S.actor+o,flags=gg.TYPE_FLOAT} end
  local got=batch(req)
  if not got then return nil end
  local result={}
  for i,o in ipairs(FLOAT_OFF) do result[o]=got[i].value end
  return result
end
local function snap()
  local f=floats()
  if not f then gg.alert('🔴 No active actor found. Use SETUP while playing.');return end
  S.baseline={actor=S.actor,vals=f,dataHealth=R(S.star+0x80)}
  S.diff=nil;S.selected=nil
  gg.alert('Captured '..#FLOAT_OFF..' REAL actor Float fields.\n\nClose GG, take a little damage, then reopen GG and select COMPARE AFTER DAMAGE.\n\nNo memory was modified.')
end
local function compare()
  if not S.baseline or not actorOk() or S.baseline.actor~=S.actor then
    gg.alert('🔴 Baseline missing or player changed. Capture baseline again.');return end
  local now=floats()
  if not now then gg.alert('Cannot read live actor Floats');return end
  local reference=R(S.star+0x80)
  local delta=(reference and S.baseline.dataHealth) and reference-S.baseline.dataHealth or nil
  local changed={}
  for _,off in ipairs(FLOAT_OFF) do
    local old,new=S.baseline.vals[off],now[off]
    if old and new and old==old and new==new and old>0 and old<1000000 and new>=0 and new<1000000
       and new<old-0.01 and old-new<100000 then
      changed[#changed+1]={off=off,old=old,new=new,diff=new-old}
    end
  end
  table.sort(changed,function(a,b)
    if delta and delta<0 then
      local x,y=math.abs(a.diff-delta),math.abs(b.diff-delta)
      if x~=y then return x<y end
    end
    return math.abs(a.diff)>math.abs(b.diff)
  end)
  S.diff=changed
  if #changed==0 then gg.alert('No actor Float values decreased. Try taking damage and compare again.');return end
  local picks={}
  for i=1,math.min(#changed,30) do
    local v=changed[i]
    picks[i]=hx(v.off)..' | '..string.format('%.2f -> %.2f (%.2f)',v.old,v.new,v.diff)
  end
  local choice=gg.choice(picks,nil,'Actor Float decreases: '..#changed..
    '\nStored Character health delta: '..tostring(delta)..'\nPick one candidate to test')
  if choice then S.selected=changed[choice]
    gg.alert('Selected actor Float +'..hx(S.selected.off)..'.\nNot yet verified as live health.')
  end
end
local function testSelected()
  if not actorOk() or not S.selected then gg.alert('🔴 Compare actor Floats first.');return false end
  if S.pending then gg.alert('Resolve pending test first.');return false end
  local address=S.actor+S.selected.off
  local old=R(address)
  if not old then return false end
  local q=gg.prompt({'Test value: actor +'..hx(S.selected.off)}, {[1]=tostring(old)}, {[1]='number'})
  if not q then return false end
  local val=tonumber(q[1])
  if not val or val~=val or val<0 or val>1000000 or math.abs(val-old)<0.05 then
    gg.alert('Enter a different finite Float from 0 to 1,000,000.');return false end
  local ok,err=pcall(gg.setValues,{{address=address,flags=gg.TYPE_FLOAT,value=tostring(val)}})
  if not ok or err==false then gg.alert('Write failed: '..tostring(err));return false end
  S.pending={actor=S.actor,off=S.selected.off,old=old}
  gg.alert('Test value written to actor +'..hx(S.selected.off)..
     '.\nClose GG, check the HEALTH METER in-game, then reopen GG and choose CONFIRM / RESTORE.')
  return true
end
local function confirmTest()
  local t=S.pending
  if not t then gg.alert('No pending test.');return end
  if not actorOk() or S.actor~=t.actor then
    S.pending=nil;gg.alert('Actor changed; original address cannot be safely restored.');return end
  local choice=gg.choice({'YES — live health meter changed','NO — restore original value','UNSURE — restore original value'},
    nil,'Did modifying actor +'..hx(t.off)..' change the HEALTH METER?')
  if not choice then return end
  if choice==1 then
    S.liveHealthOffset=t.off;S.liveHealthConfirmed=true
    S.pending=nil
    gg.alert('🟢 Live health offset accepted for this session: +'..hx(t.off)..
      '\nReport this hex offset so it can be reviewed and made permanent.')
  else
    local ok,e=pcall(gg.setValues,{{address=S.actor+t.off,flags=gg.TYPE_FLOAT,value=tostring(t.old)}})
    S.pending=nil
    gg.alert(ok and e~=false and 'Original Float restored.' or 'Restore failed: '..tostring(e))
  end
end
local function editLive()
  if not S.liveHealthConfirmed or not actorOk() then
    gg.alert('🔴 Live health not confirmed. Use snapshot and candidate test.');return end
  local addr=S.actor+S.liveHealthOffset
  local old=R(addr)
  if not old then gg.alert('Health address unreadable.');return end
  local q=gg.prompt({'Live health Float'}, {[1]=tostring(old)}, {[1]='number'})
  if not q then return end
  local val=tonumber(q[1])
  if not val or val~=val or val<0 or val>1000000 then gg.alert('Invalid Float.');return end
  local ok,e=pcall(gg.setValues,{{address=addr,flags=gg.TYPE_FLOAT,value=tostring(val)}})
  if not ok or e==false then gg.alert('Write failed: '..tostring(e))
  else gg.alert('Actor +'..hx(S.liveHealthOffset)..' now reads '..tostring(R(addr))..'\nVerify in-game.') end
end

-- Derived from Character.stat at +0x70 (Float array). Published PC mod uses
-- ChangeStat(1..6): Reputation, Strength, Skill, Agility, Stamina, Attitude.
-- Individual Android edits have not yet been confirmed by in-game testing.
local STATS={
  {name='Reputation',index=1},{name='Strength',index=2},
  {name='Skill',index=3},{name='Agility',index=4},
  {name='Stamina',index=5},{name='Attitude',index=6}
}
local function statArray()
  if not actorOk() or not S.star then return nil,nil,'No validated active actor' end
  local a=Q(S.star+0x70)
  if not a or a<0x10000 or a%8~=0 then return nil,nil,'Character.stat array pointer unavailable' end
  local len=Q(a+0x18)
  if not len or len<7 or len>64 or math.floor(len)~=len then
    return nil,nil,'Invalid stat array length: '..tostring(len)
  end
  local req={}
  for i=1,6 do req[i]={address=a+0x20+i*4,flags=gg.TYPE_FLOAT} end
  local vals=batch(req)
  if not vals then return nil,nil,'Stat array cannot be read' end
  for _,v in ipairs(vals) do
    local x=tonumber(v.value)
    if not x or x~=x or x<0 or x>1000 then
      return nil,nil,'One or more stat values failed sanity check'
    end
  end
  return a,vals,nil
end

local function statMenu()
  while true do
    local arr,values,problem=statArray()
    if not arr then gg.alert('🔴 Attribute pointer unresolved:\n'..tostring(problem));return end
    local labels={}
    for i,st in ipairs(STATS) do
      labels[i]='🟢 '..st.name..' ['..i..'] = '..string.format('%.1f',values[i].value)
    end
    labels[7]='↩ Back'
    local selected=gg.choice(labels,nil,
      'Six Character.stat Float entries\nGreen = verified pointer, HUD/gameplay effect still to test')
    if not selected or selected==7 then return end
    local st=STATS[selected]
    local addr=arr+0x20+st.index*4
    local old=R(addr)
    local okPointer=verifyPointer('health')
    if not okPointer or Q(S.star+0x70)~=arr then
      gg.alert('Active character or stat array changed. Run Setup again.');return
    end
    local prompt=gg.prompt({'New '..st.name..' (1-99)'},{[1]=tostring(old)},{[1]='number'})
    if prompt then
      local v=tonumber(prompt[1])
      if not v or v~=v or v<1 or v>99 then
        gg.alert('Enter an attribute value from 1 to 99.')
      else
        local ok,res=pcall(gg.setValues,{{address=addr,flags=gg.TYPE_FLOAT,value=tostring(v)}})
        if not ok or res==false then
          gg.alert('Write failed: '..tostring(res))
        else
          gg.alert(st.name..'\nPrevious: '..tostring(old)..'\nReadback: '..tostring(R(addr))..
            '\nAddress: '..hx(addr)..'\n\nCheck the character profile in-game. The memory address is verified; the gameplay effect still needs testing.')
        end
      end
    end
  end
end

-- Progress offsets come from the v1.1.8 compiled field-offset table.
-- Sentence is modified directly by the public PC cheat; direct Android write still needs HUD validation.
local function progressExtras()
  while true do
    local p=S.classes.Progress
    if not p or not p.storage or p.storage<0x10000 or
       D(p.address+0x11C)~=C.Progress or Q(p.address+0xB8)~=p.storage then
      gg.alert('🔴 Progress static-data block not validated. Run Setup.');return
    end
    local base=p.storage
    local sentence=D(base+0x4C)
    local day=D(base+0x14)
    local hours=D(base+0x0C)
    local minutes=D(base+0x08)
    local pick=gg.choice({
      '🟡 Edit sentence days = '..tostring(sentence),
      '🛈 Inspect day / clock: day '..tostring(day)..', '..tostring(hours)..':'..tostring(minutes),
      '🛈 Inspect allowance = '..tostring(D(base+0x48)),
      '↩ Back'
    },nil,'Progress values (same live static block as confirmed bank)')
    if not pick or pick==4 then return end
    if pick==1 then
      local q=gg.prompt({'New sentence days (0-36525)'},{[1]=tostring(sentence or '')},{[1]='number'})
      if q then
        local v=tonumber(q[1])
        if not v or v~=math.floor(v) or v<0 or v>36525 then
          gg.alert('Enter an integer from 0 to 36525.')
        elseif D(p.address+0x11C)~=C.Progress or Q(p.address+0xB8)~=base then
          gg.alert('Progress pointer changed; setup must be repeated.');return
        else
          local ok,e=pcall(gg.setValues,{{address=base+0x4C,flags=gg.TYPE_DWORD,value=tostring(v)}})
          if not ok or e==false then gg.alert('Write failed: '..tostring(e))
          else gg.alert('Sentence readback: '..tostring(D(base+0x4C))..
            '\nCheck your sentence in the game. UI/game effect is not yet confirmed.') end
        end
      end
    elseif pick==2 then
      gg.alert('Progress static values (Dword):\nDay +0x14 = '..tostring(day)..
        '\nHours +0x0C = '..tostring(hours)..'\nMinutes +0x08 = '..tostring(minutes)..
        '\nThese values are read-only for now; time is updated continuously.')
    else
      gg.alert('Allowance, Progress static +0x48 = '..tostring(D(base+0x48))..
        '\nRead only; gameplay effect not established.')
    end
  end
end

local function nearbyActor()
  if not actorOk() then gg.alert('No live actor. Run Setup during gameplay.');return end
  local lines={'Live actor: '..hx(S.actor),'',
    '🟢 +0xB4 health = '..tostring(R(S.actor+0xB4)),
    'Nearby Float fields; meanings NOT verified:'}
  for _,off in ipairs({0xB8,0xBC,0xC0,0xC4,0xC8,0xCC,0xD0,0xD4}) do
    lines[#lines+1]='🔴 +'..hx(off)..' = '..tostring(R(S.actor+off))
  end
  lines[#lines+1]=''
  lines[#lines+1]='Do NOT equate the nearest floats with max health or spirit without observing actual gameplay changes.'
  gg.alert(table.concat(lines,'\n'))
end
local function liveReport()
  local arr,vals,statErr=statArray()
  local lines={
    'Reference Tools '..V,
    'Xa signature: '..lamp(S.anchor~=nil)..' '..hx(S.anchor),
    'Compiled 6/6: '..lamp(S.fields==6),
    'Active actor: '..lamp(actorOk())..' '..hx(S.actor),
    'Live health +0xB4: '..lamp(S.liveHealthConfirmed and actorOk())..
       ' '..tostring(actorOk() and R(S.actor+0xB4) or 'unavailable'),
    'Money Progress.bank: '..lamp(canEdit('bank'))..
       ' '..tostring(S.bank and D(S.bank) or 'unavailable'),
    'Attributes Float array: '..lamp(arr~=nil)..' '..hx(arr),
    'Sentence: '..tostring(S.classes.Progress and
       S.classes.Progress.storage and D(S.classes.Progress.storage+0x4C) or 'unavailable'),
    'Stats: '..tostring(arr and 'array index 1-6 mapped; HUD effects unconfirmed' or statErr),
    '',
    'The stored Character.health +0x80 is a separate record; editing it did NOT affect live gameplay.',
    'The 0xB8/0xBC neighboring actor fields are not identified as healthLimit/spirit.'
  }
  if S.actorIssue then lines[#lines+1]='Actor diagnostic: '..tostring(S.actorIssue) end
  gg.alert(table.concat(lines,'\n'))
end

local function menu()
  while true do
    local statPtr=statArray()
    local liveHealth=S.liveHealthConfirmed and actorOk()
    local n=gg.choice({
      '⚙ SETUP / RE-SCAN (Xa + live actor)',
      lamp(liveHealth)..' EDIT LIVE HEALTH — actor +0xB4',
      lamp(canEdit('bank'))..' EDIT MONEY — Progress.bank',
      lamp(statPtr~=nil)..' EDIT ATTRIBUTES — reputation, strength, skill, agility, stamina, attitude',
      '🟡 SENTENCE / CLOCK / ALLOWANCE — Progress static fields',
      '🛈 CHECK neighboring LIVE actor Floats (+0xB8 through +0xD4)',
      '🛈 STATUS — paths and live values',
      '🛈 Stored Character data (not live health)',
      '① Capture actor Float baseline (optional research)',
      '② Compare actor Floats after damage (optional research)',
      '🔴 Item spawning — not in this milestone',
      '↻ EXTENDED setup including O (slower)',
      '✕ Exit'
    },nil,'Reference Tools '..V..'\n'..status()..
       '\nGreen=address resolved. Player-stat HUD effects require testing.')
    if not n then return true end
    if n==1 or n==12 then
      bind(n==12);actorScan(n==12);liveReport()
    elseif n==2 then editLive()
    elseif n==3 then edit('bank')
    elseif n==4 then statMenu()
    elseif n==5 then progressExtras()
    elseif n==6 then nearbyActor()
    elseif n==7 then liveReport()
    elseif n==8 then gg.alert('Stored Character.health +0x80: '..tostring(S.health and R(S.health))..
      '\nStored Character.healthLimit +0x84: '..tostring(S.health and R(S.health+4))..
      '\nStored Character.spirit +0x88: '..tostring(S.health and R(S.health+8))..
      '\nThese are separate from confirmed live actor health at +0xB4.')
    elseif n==9 then snap()
    elseif n==10 then compare()
    elseif n==11 then gg.alert('Item spawning is excluded from this revision as requested.')
    else return false end
  end
end
if type(gg)~='table' or type(gg.searchNumber)~='function' then error('GG environment required') end
bind(false);actorScan(false);gg.setVisible(false)
gg.toast('Reference Tools '..V..': '..status())
if not menu() then return end
while true do
  if gg.isVisible() then gg.setVisible(false);if not menu() then break end end
  gg.sleep(200)
end
