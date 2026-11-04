-- REFTOOLS-MODULE-V1.0.0
-- Revision 2.1.0 | Clean developer controls: live health, spirit, injury, money, attributes, progress.
-- Finds and validates runtime pointers before offering stat edits.
local V='2.1.0'
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

local function actorOk()
  if not S.actor or not S.star or Q(S.actor+0x20)~=S.star then return false end
  local c=Q(S.actor)
  return c~=nil and D(c+0x11C)==C.EFPJKAPKGOB
end
local function actorScan(slow)
  S.actor=nil;S.actorIndex=nil;S.liveHealthOffset=nil;S.liveHealthConfirmed=false
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
  if S.anchor and D(S.anchor+0x76F344)==0xB4 and D(S.anchor+0x76F348)==0xB8 and actorOk() then
    S.liveHealthOffset=0xB4
    S.liveHealthConfirmed=true
  else
    S.actorIssue='Actor health/health-limit table entries (+0xB4/+0xB8) failed verification'
  end
  return true
end
local function editLive()
  if not S.liveHealthConfirmed or not actorOk() then
    gg.alert('🔴 Live health unavailable. Run SETUP / RE-SCAN.');return end
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
-- Verified in gameplay: Reputation, Strength, Skill, Agility, Stamina, Attitude.
local STATS={
  {name='Reputation',index=1},{name='Strength',index=2},
  {name='Skill',index=3},{name='Agility',index=4},
  {name='Stamina',index=5},{name='Attitude',index=6}
}
local function statArray()
  if not S.anchor or D(S.anchor+0x76EA08)~=0x70 then return nil,nil,'Character.stat field-table entry did not match +0x70' end
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

local function progressExtras()
  if not S.anchor or D(S.anchor+0x76EBE8)~=0x4C then
    gg.alert('Progress.sentence offset check failed. Run SETUP.');return end
  local fields={
    {name='Sentence days',off=0x4C,kind=gg.TYPE_DWORD,min=0,max=36525,entry=0x76EBE8},
    {name='Day',off=0x14,kind=gg.TYPE_DWORD,min=0,max=100000},
    {name='Hours',off=0x0C,kind=gg.TYPE_DWORD,min=0,max=23},
    {name='Minutes',off=0x08,kind=gg.TYPE_DWORD,min=0,max=59},
    {name='Allowance',off=0x48,kind=gg.TYPE_DWORD,min=0,max=2000000000}
  }
  while true do
    local p=S.classes.Progress
    if not p or not p.storage or p.storage<0x10000 or
      D(p.address+0x11C)~=C.Progress or Q(p.address+0xB8)~=p.storage then
      gg.alert('Progress class/static block not validated. Re-scan.');return end
    local labels={}
    for i,f in ipairs(fields) do
      labels[i]='EDIT '..f.name..' + '..hx(f.off)..' = '..tostring(D(p.storage+f.off))
    end
    labels[#labels+1]='Back'
    local pick=gg.choice(labels,nil,
      'Progress fields: edit with immediate readback. Clock values may be overwritten by simulation.\nRuntime gameplay effects require checking.')
    if not pick or pick>#fields then return end
    local f=fields[pick]
    if f.entry and D(S.anchor+f.entry)~=f.off then
      gg.alert(f.name..' field-offset table mismatch.');return end
    local old=D(p.storage+f.off)
    if old==nil then gg.alert('Unreadable value.');return end
    local q=gg.prompt({'New '..f.name..' ('..f.min..'–'..f.max..')'},{[1]=tostring(old)},{[1]='number'})
    if q then
      local v=tonumber(q[1])
      if not v or v~=math.floor(v) or v<f.min or v>f.max then
        gg.alert('Invalid integer range ('..f.min..'–'..f.max..').')
      elseif D(p.address+0x11C)~=C.Progress or Q(p.address+0xB8)~=p.storage then
        gg.alert('Progress pointer changed; re-scan.');return
      else
        local addr=p.storage+f.off
        local ok,e=pcall(gg.setValues,{{address=addr,flags=gg.TYPE_DWORD,value=tostring(v)}})
        if not ok or e==false then gg.alert('Write failed: '..tostring(e))
        else gg.alert(f.name..' old='..tostring(old)..' readback='..tostring(D(addr))..
          '\nCheck gameplay now. Clock fields can be updated immediately by the game.') end
      end
    end
  end
end

local LIVE_STATE={
  {name='Spirit',offset=0xD0,tableEntry=0x76F360,flags=gg.TYPE_FLOAT,
    sourceOffset=0x88,sourceFlag=gg.TYPE_FLOAT,scale=10,min=0,max=100},
  {name='Injury',offset=0x248,tableEntry=0x76F484,flags=gg.TYPE_DWORD,
    sourceOffset=0x8C,sourceFlag=gg.TYPE_DWORD,scale=1,min=0,max=1000}
}
local function liveStateMenu()
  if not actorOk() or not S.anchor then
    gg.alert('No valid player. Run SETUP / RE-SCAN.');return end
  local items={}
  for _,f in ipairs(LIVE_STATE) do
    if D(S.anchor+f.tableEntry)~=f.offset then
      gg.alert('Game build does not match '..f.name..' mapping.');return end
    local raw=read(S.actor+f.offset,f.flags)
    items[#items+1]='EDIT '..f.name..' = '..tostring(raw and raw/f.scale or 'unavailable')
  end
  items[#items+1]='Back'
  local choice=gg.choice(items,nil,'Player state — live actor')
  if not choice or choice>#LIVE_STATE then return end
  local f=LIVE_STATE[choice]
  if not actorOk() or D(S.anchor+f.tableEntry)~=f.offset then
    gg.alert('Player changed. Run SETUP / RE-SCAN.');return end
  local addr=S.actor+f.offset
  local old=read(addr,f.flags)
  if old==nil or old~=old then gg.alert('Current value unavailable.');return end
  local q=gg.prompt({'New '..f.name..' ('..f.min..'-'..f.max..')'},
    {[1]=tostring(old/f.scale)},{[1]='number'})
  if not q then return end
  local v=tonumber(q[1])
  if not v or v~=v or v==math.huge or v==-math.huge or
     v<f.min or v>f.max or (f.flags==gg.TYPE_DWORD and v~=math.floor(v)) then
    gg.alert('Invalid value.');return end
  if not actorOk() or D(S.anchor+f.tableEntry)~=f.offset then
    gg.alert('Player pointer changed. Re-scan.');return end
  local raw=v*f.scale
  local ok,result=pcall(gg.setValues,{{address=addr,flags=f.flags,value=tostring(raw)}})
  if not ok or result==false then gg.alert('Write failed.');return end
  local actual=read(addr,f.flags)
  if actual==nil or math.abs(actual-raw)>0.03 then
    gg.alert('Readback mismatch; value not confirmed.');return end
  gg.toast(f.name..' = '..tostring(v))
end

local function refresh()
  bind(false)
  actorScan(false)
  return actorOk() and S.anchor~=nil and S.fields==6
end
local function menu()
  while true do
    local n=gg.choice({
      'SETUP / RE-SCAN',
      'EDIT HEALTH',
      'EDIT SPIRIT / INJURY',
      'EDIT ATTRIBUTES',
      'EDIT MONEY',
      'EDIT SENTENCE / DAY / CLOCK / ALLOWANCE',
      'EXIT'
    },nil,'Hard Time III — Developer Controls v'..V)
    if not n or n==7 then return false end
    if n==1 then
      gg.toast(refresh() and 'Player linked' or 'Player not ready; enter gameplay and re-scan')
    elseif n==2 then editLive()
    elseif n==3 then liveStateMenu()
    elseif n==4 then statMenu()
    elseif n==5 then edit('bank')
    elseif n==6 then progressExtras()
    end
  end
end
if type(gg)~='table' or type(gg.searchNumber)~='function' then
  error('GameGuardian environment required')
end
refresh()
gg.setVisible(false)
gg.toast('Hard Time III Developer Controls v'..V)
if not menu() then return end
while true do
  if gg.isVisible() then
    gg.setVisible(false)
    if not menu() then break end
  end
  gg.sleep(200)
end
