-- REFTOOLS-MODULE-V1.0.0
-- Revision 1.2.0 | Setup-first and pointer-availability based editing; remote path unchanged.
-- Finds and validates runtime pointers before offering stat edits.
local V='1.2.0'
local SIG='-1992893169D;-1946824447D;-268807205D;1873603068D::13'
local SVAL={-1992893169,-1946824447,-268807205,1873603068}
local F={{'health',0x76EA10,128},{'healthLimit',0x76EA14,132},{'spirit',0x76EA18,136},
         {'injury',0x76EA1C,140},{'bank',0x76EBD4,56},{'cStar',0x770FBC,32}}
local C={Progress=0x02000015,Characters=0x020000AB,Character=0x02000008}
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
         lamp(S.health~=nil)..' Character  '..lamp(S.bank~=nil)..' bank pointer'
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
local function menu()
  while true do
    local n=gg.choice({
      '⚙ SETUP / RE-SCAN — Verify 4 Xa DWORDs + 6 offsets',
      lamp(canEdit('health'))..' EDIT Health (Float)',
      lamp(canEdit('healthLimit'))..' EDIT Max health (Float)',
      lamp(canEdit('spirit'))..' EDIT Spirit (Float)',
      lamp(canEdit('injury'))..' EDIT Injury (Dword)',
      lamp(canEdit('bank'))..' EDIT Bank (Dword)',
      '🛈 Read current values + addresses',
      '🛈 Detailed setup / status',
      '🔴 Strength / reputation (stat array indices not mapped)',
      '🔴 Item / NPC / vehicle spawning (functions not mapped)',
      '↻ EXTENDED re-scan (include O, slower)',
      '✕ Exit'
    },nil,'Reference Tools '..V..'\n'..status()..
          '\nGreen = address available for editing, not yet verified in gameplay')
    if not n then return true end
    if n==1 then
      bind(false)
      setupReport()
    elseif n==2 then edit('health')
    elseif n==3 then edit('healthLimit')
    elseif n==4 then edit('spirit')
    elseif n==5 then edit('injury')
    elseif n==6 then edit('bank')
    elseif n==7 then
      local choices={'health','healthLimit','spirit','injury','bank'}
      local labels={}
      for i,k in ipairs(choices) do
        labels[i]=lamp(canEdit(k))..' '..k
      end
      local x=gg.choice(labels,nil,'Select value to read')
      if x then readDisplay(choices[x]) end
    elseif n==8 then setupReport()
    elseif n==9 then gg.alert('🔴 Character.stat (+0x70) is an array reference. Strength/reputation array indices and live binding are not yet verified.')
    elseif n==10 then spawnInfo()
    elseif n==11 then
      bind(true)
      setupReport()
    else return false end
  end
end
if type(gg)~='table' or type(gg.searchNumber)~='function' then error('GG environment required') end
bind(false);gg.setVisible(false)
gg.toast('Reference Tools '..V..': '..status())
if not menu() then return end
while true do
  if gg.isVisible() then gg.setVisible(false);if not menu() then break end end
  gg.sleep(200)
end
