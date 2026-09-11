-- Exercise the real snapshot reader, correction and update wrapper across startup.
local source=assert(arg[1])
local ffi=require('ffi')
local patch=assert(loadfile(source..'/spawn_data.lua'))()
local game,exe,pm,mode,entity,rm,pos,entities,used,hash,coordinates=
    0x10000000,0x20000000,0x30000000,0x40000000,0x50000000,0x60000000,
    0x70000000,0x71000000,0x72000000,0x73000000,0x74000000
local regions={}
local function region(address,size)
    local data=ffi.new('uint8_t[?]',size)
    regions[#regions+1]={address=address,size=size,data=data}
    return data
end
local globals={}
for _,rva in ipairs({0x276C190,0x276C3D0,0x276C6E8,0x276C838}) do
    globals[rva]=region(game+rva,8)
end
local p,m,e,r,q=region(pm,0x440),region(mode,0x44),region(entity,24),region(rm,0x58),region(pos,0x60)
local es,us,hs,xyz=region(entities,8),region(used,4),region(hash,64),region(coordinates,12)
local function set(data,offset,ctype,value) ffi.copy(data+offset,ffi.new(ctype..'[1]',value),ffi.sizeof(ctype)) end
local function pointer(data,offset,value) set(data,offset,'uint64_t',value) end
local function integer(data,offset,value) set(data,offset,'uint32_t',value) end
local function number(data,offset,value) set(data,offset,'float',value) end
local function locate(address,size)
    for _,row in ipairs(regions) do
        if address>=row.address and address+size<=row.address+row.size then return row.data+address-row.address end
    end
    error('Unbounded fixture read '..string.format('%x',address))
end
local writes,unreadable=0,false
local api={module=function(name)return name and game or exe end,module_hash=function(module)return tostring(module) end}
api.read=function(address,size)
    if unreadable and address==pm then return nil end
    return ffi.string(locate(address,size),size)
end
api.pointer=function(bytes,offset)
    if not bytes then return nil end
    local v=ffi.new('uint64_t[1]');ffi.copy(v,bytes:sub((offset or 0)+1),8)
    local n=tonumber(v[0]);if n<0x10000 or n>=0x800000000000 then return nil end
    return n
end
api.writable_data=function(address,size)return address>=pm and address+size<=pm+0x440 end
api.write=function(address,bytes)
    assert(address==pm+0x10c and #bytes==8,'Only the pending XY may be changed')
    writes=writes+1;ffi.copy(locate(address,8),bytes,8);return true
end
local env=setmetatable({print=function()end,os={getenv=function()end},CowboyBingusModLoader={api=1},
    update=function(...)return ... end},{__index=_G});env._G=env
local install=setfenv(assert(loadfile(source..'/archive_loader.lua'))(),env)
install(function()return api end,patch,{revision='startup-test',game_sha256=tostring(game),exe_sha256=tostring(exe)})
local function update()
    local a,b,c=env.update(0.1,nil,'sentinel')
    assert(a==0.1 and b==nil and c=='sentinel','Original update results changed')
end
update();update()
assert(env.ReinforcementBeaconFixData.status:find('waiting_for_game_data',1,true),
    'Null startup pointer became a permanent failure: '..env.ReinforcementBeaconFixData.status)
assert(writes==0)
pointer(globals[0x276C190],0,pm)
integer(p,0x84,2);integer(p,0x88,2);integer(p,0x2e0,3);integer(p,0x3a8,0x7fff)
number(p,0x12c,5);number(p,0x114,321)
update();assert(writes==0)
pointer(globals[0x276C3D0],0,mode)
update() -- Ship/mission mode has not initialized.
integer(m,8,1);integer(m,0x40,1)
update() -- Player entity has not initialized.
pointer(p,0xe8,entity);integer(e,8,5);e[20]=1
update() -- Reinforcement manager has not initialized.
pointer(globals[0x276C6E8],0,rm);pointer(globals[0x276C838],0,pos)
update();assert(writes==0)
unreadable=true;update();assert(writes==0);unreadable=false
update() -- An unreadable transition must also recover.
pointer(r,0x38,entities);pointer(r,0x48,used);pointer(es,0,entity)
integer(e,8,77);integer(p,0x2e0,1);integer(r,8,1);integer(r,12,1)
pointer(q,0x28,hash);integer(q,0x30,8);integer(q,0x34,0xffffffff);integer(q,0x38,1)
integer(q,8,1);pointer(q,0x50,coordinates)
for i=0,7 do integer(hs,8*i,0xffffffff) end
integer(hs,8*5,77);integer(hs,8*5+4,0)
number(xyz,0,11);number(xyz,4,22);number(xyz,8,33)
number(p,0x10c,50);number(p,0x110,60)
update() -- Capture the unused beacon and the new local identity.
integer(p,0x2e0,2);integer(us,0,1)
update()
assert(writes==1 and env.ReinforcementBeaconFixData.corrections==1,'Did not recover and correct reinforcement')
assert(ffi.cast('float*',p+0x10c)[0]==11 and ffi.cast('float*',p+0x110)[0]==22)
assert(ffi.cast('float*',p+0x114)[0]==321 and ffi.cast('float*',p+0x12c)[0]==5)
-- Teardown/reload must discard cached associations, including a previously centered spawn.
pointer(globals[0x276C190],0,0);update()
pointer(globals[0x276C190],0,pm);update();assert(writes==1)
integer(p,0x2e0,3);update()
integer(p,0x2e0,1);integer(us,0,0);update()
integer(p,0x2e0,2);integer(us,0,1);number(p,0x10c,50);number(p,0x110,60);update()
assert(writes==2)
-- Real reader + wrapper: a remote beacon may appear in the queue-commit frame
-- with only its owner's bit set (2), while the local player's bit remains 0.
local remote_address=0x51000000
local remote=region(remote_address,24);integer(remote,8,77)
pointer(es,0,remote_address)
integer(p,0x2e0,3);integer(r,12,0);update()
integer(p,0x2e0,1);update()
integer(r,12,1);integer(us,0,2);integer(p,0x2e0,2)
number(p,0x10c,50);number(p,0x110,60);update()
assert(writes==3 and env.ReinforcementBeaconFixData.last.association=='unmarked_remote')
assert(ffi.cast('float*',p+0x10c)[0]==11 and ffi.cast('float*',p+0x110)[0]==22)
assert(ffi.cast('uint32_t*',us)[0]==2 and remote[20]==0,'Beacon ownership/use flags changed')
assert(ffi.cast('float*',p+0x114)[0]==321 and ffi.cast('float*',p+0x12c)[0]==5)
-- A non-null invalid layout remains fatal; retries apply only to unavailable data.
integer(p,0x84,99);update()
assert(env.ReinforcementBeaconFixData.status:find('Unsupported player layout',1,true))
integer(p,0x84,2);integer(p,0x2e0,1);integer(us,0,0);update()
integer(p,0x2e0,2);integer(us,0,1);update();assert(writes==3)
pointer(globals[0x276C190],0,1)
local ok,message=pcall(patch.snapshot,api,game,exe)
assert(not ok and tostring(message):find('Invalid spawn data pointer',1,true),'Invalid non-null pointer treated as startup')
print('PASS: null startup, staged initialization, unreadable transition, correction, mission reload and fatal-layout protection')
