-- REFTOOLS-MODULE-V1.0.0
-- Revision 1.1.0 | Binary-derived runtime class resolver.
-- Finds and validates runtime pointers before offering stat edits.
local V='1.1.0'
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
  local lines={'Reference Tools '..V,'',status(),
    'IL2CPP base: '..hx(S.base),'Character record: '..hx(S.star),
    'Health address: '..hx(S.health),'Bank address: '..hx(S.bank),
    lamp(S.healthOK)..' HUD health match',lamp(S.bankOK)..' HUD bank match',
    '🔴 Spawning not mapped','',
    'Validated memory pointers are not yet proven live gameplay controls.'}
  for _,s in ipairs(S.issues) do lines[#lines+1]='- '..s end
  gg.alert(table.concat(lines,'\n'))
end
local function compare(kind)
  local addr=(kind=='health') and S.health or S.bank
  if not addr then gg.alert('🔴 No runtime address. Recheck while gameplay is active.');return end
  local val=(kind=='health') and R(addr) or D(addr)
  if val==nil then gg.alert('Address unreadable. Recheck runtime bindings.');return end
  local q=gg.prompt({'Type the '..kind..' value currently shown in the game (do NOT leave blank)'},{[1]=''},{[1]='number'})
  if not q then return end
  local typed=tonumber(q[1])
  local match=typed and math.abs(typed-val)<=((kind=='health') and 0.51 or 0)
  if kind=='health' then S.healthOK=match and true or false else S.bankOK=match and true or false end
  gg.alert(lamp(match)..' '..kind..' HUD comparison\nMemory: '..tostring(val)..'\nEntered: '..tostring(q[1])..
           '\nAddress: '..hx(addr)..'\nA matching number is provisional; verify game behavior.')
end
local function edit(kind)
  local addr=(kind=='health') and S.health or S.bank
  local enabled=(kind=='health') and S.healthOK or S.bankOK
  if not addr or not enabled then gg.alert('🔴 Locked. Resolve pointer and confirm the on-screen value first.');return end
  local p=S.classes[kind=='health' and 'Characters' or 'Progress']
  if not p or D(p.address+0x11C)~=p.token or
     Q(p.address+0xB8)~=p.storage or D(S.anchor)~=SVAL[1] then
    S.healthOK=false;S.bankOK=false
    gg.alert('Runtime pointer or module changed. Run resolver again.');return
  end
  if kind=='health' then
    if not S.star or Q(p.storage+0x20)~=S.star or
       not Q(S.star) or D(Q(S.star)+0x11C)~=C.Character then
      S.healthOK=false;gg.alert('Character pointer changed; rescan.');return
    end
  end
  local current=(kind=='health') and R(addr) or D(addr)
  if current==nil then return end
  local q=gg.prompt({'New '..kind..' amount'}, {[1]=tostring(current)}, {[1]='number'})
  if not q then return end
  local value=tonumber(q[1])
  if not value or value~=value then return end
  if kind=='health' then
    local max=R(addr+4)
    if not max or value<0 or value>math.min(max,100000) then
      gg.alert('Health must be between 0 and healthLimit.');return
    end
  else
    if value~=math.floor(value) or value<0 or value>2000000000 then
      gg.alert('Bank must be an integer between 0 and 2 billion.');return
    end
  end
  local t=(kind=='health') and gg.TYPE_FLOAT or gg.TYPE_DWORD
  local ok,r=pcall(gg.setValues,{{address=addr,flags=t,value=tostring(value)}})
  if not ok or r==false then gg.alert('Write rejected: '..tostring(r));return end
  gg.alert('Wrote candidate '..kind..'\nReadback: '..tostring((kind=='health') and R(addr) or D(addr))..
           '\nCheck the actual game HUD and gameplay; immediate readback alone is not proof.')
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
    local n=gg.choice({status(),
      lamp(S.health~=nil)..' Read health',lamp(S.bank~=nil)..' Read bank',
      lamp(S.healthOK)..' Compare health with HUD',lamp(S.bankOK)..' Compare bank with HUD',
      lamp(S.healthOK)..' Edit health',lamp(S.bankOK)..' Edit bank',
      '🔴 Item and NPC spawner', '🛈 Compiled offset table',
      '↻ Rebind runtime (A/Ca/Ch/Cd/Cb)',
      '↻ Rebind including O (slow)', '✕ Exit'},nil,'Reference Tools '..V..' | runtime probe')
    if not n then return true end
    if n==1 then info()
    elseif n==2 then
      gg.alert(S.health and ('Health: '..tostring(R(S.health))..' / '..tostring(R(S.health+4))..
               '\nSpirit: '..tostring(R(S.health+8))..'\nAddress: '..hx(S.health)) or 'Character not bound')
    elseif n==3 then gg.alert(S.bank and ('Bank: '..tostring(D(S.bank))..'\nAddress: '..hx(S.bank)) or 'Bank not bound')
    elseif n==4 then compare('health')
    elseif n==5 then compare('bank')
    elseif n==6 then edit('health')
    elseif n==7 then edit('bank')
    elseif n==8 then spawnInfo()
    elseif n==9 then fieldInfo()
    elseif n==10 or n==11 then bind(n==11);gg.toast(status())
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
