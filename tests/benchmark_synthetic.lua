-- Offline benchmark of the actual reader, planner, wrapper and Windows adapter.
-- Run from the workspace root:
-- tools/src/LuaJIT/src/luajit.exe ReinforcementBeaconsFixed/tests/benchmark_synthetic.lua ReinforcementBeaconsFixed/src [jit|off] [log-path]
-- Only this process's fixture memory is read/written. No game process is opened.
-- Timings have GC enabled and NO read counters. Counters and held-GC allocation
-- measurements run in separate windows. Counts include BOTH checks per update.
local source, mode, log_path = assert(arg[1]), arg[2] or 'jit', arg[3]
local ffi, bit = require('ffi'), require('bit')
if mode == 'off' then jit.off(); jit.flush() end
ffi.cdef('int QueryPerformanceCounter(void *); int QueryPerformanceFrequency(void *); void *malloc(size_t); void free(void *);')
local kernel = ffi.load('kernel32')
local counter, frequency = ffi.new('int64_t[1]'), ffi.new('int64_t[1]')
assert(kernel.QueryPerformanceFrequency(frequency) ~= 0)
local hz = tonumber(frequency[0])
local function clock()
    assert(kernel.QueryPerformanceCounter(counter) ~= 0)
    return tonumber(counter[0]) / hz
end
local patch = dofile(source .. '/spawn_data.lua')
local production = dofile(source .. '/windows_api.lua')()
local function integer(p, at, v) ffi.cast('uint32_t *', p + at)[0] = v end
local function number(p, at, v) ffi.cast('float *', p + at)[0] = v end
local function pointer(p, at, v) ffi.cast('uint8_t **', p + at)[0] = v end
local function address(p) return tonumber(ffi.cast('uintptr_t', p)) end

-- Full-sized synthetic module/manager images preserve the actual RVA math.
-- Build once; reset small data structures outside every measurement window.
local owners, regions = {}, {}
local function alloc(size, name)
    -- Native-owned fixture storage must not inflate the Lua GC threshold by
    -- ~80 MB: in the game, these module/manager images are also outside Lua.
    local raw = ffi.C.malloc(size)
    assert(raw ~= nil,'Fixture allocation failed')
    local p = ffi.gc(ffi.cast('uint8_t *',raw),ffi.C.free)
    ffi.fill(p,size)
    owners[#owners + 1] = p
    regions[#regions + 1] = {first=address(p), last=address(p)+size, name=name}
    return ffi.cast('uint8_t *', p)
end
local game = alloc(0x2770700, 'game_globals')
local exe = alloc(0x1A14100, 'exe_globals')
local pm, mission = alloc(0x440, 'player_manager'), alloc(0x44, 'mission_mode')
local player = alloc(24, 'local_entity')
local rm, posm = alloc(0x58, 'reinforcement_manager'), alloc(0x60, 'position_manager')
local entities, beacon_entities = alloc(128*8, 'beacon_pointers'), alloc(128*24, 'beacon_entities')
local used, positions = alloc(128*4, 'beacon_use_bits'), alloc(128*12, 'beacon_positions')
local lookup = alloc(65536*8, 'position_lookup')
local sm, rows = alloc(0x80, 'stratagem_manager'), alloc(512*64, 'stratagem_rows')
local em, entity_hash = alloc(15937304+24, 'source_entity_manager'), alloc(8*8, 'source_lookup')
local fallback = alloc(0x48, 'source_fallback')
local registry, generations = alloc(0xA8, 'source_registry'), alloc(4, 'source_generations')
local objects, object = alloc(4*8, 'source_objects'), alloc(0x90, 'source_object')
local vtable, scene = alloc(0xF0, 'source_vtable'), alloc(0x3C, 'source_scene')
local function configure(c)
    for _, pair in ipairs({{pm,0x440},{mission,0x44},{player,24},{rm,0x58},{posm,0x60},
        {entities,128*8},{beacon_entities,128*24},{used,128*4},{positions,128*12},
        {sm,0x80},{rows,512*64}}) do ffi.fill(pair[1],pair[2]) end
    pointer(game,0x3326468,pm)
    if c.missing then pointer(game,0x3326468,nil) end
    pointer(game,0x33266a0,mission); pointer(game,0x33269c0,rm)
    pointer(game,0x3326b20,posm); pointer(game,0x33266b0,sm)
    pointer(game,0x346bf98,em); pointer(game,0x346d560,fallback)
    integer(pm,0x84,c.players or 4); integer(pm,0x88,c.players or 4)
    pointer(pm,0xE8,player); integer(player,8,7); player[20]=1
    integer(mission,8,1); integer(mission,0x40,c.ship and 0 or 1)
    integer(pm,0x2E0,c.state or 3); integer(pm,0x3A8,c.full_source and 11 or 0x7fff)
    number(pm,0x10C,50); number(pm,0x110,60); number(pm,0x114,321); number(pm,0x12C,5)
    local beacons, probes = c.beacons or 0, c.probes or 1
    integer(rm,8,128); integer(rm,12,beacons)
    pointer(rm,0x38,entities); pointer(rm,0x48,used)
    integer(posm,8,beacons); pointer(posm,0x28,lookup)
    integer(posm,0x30,65536); integer(posm,0x34,0xffffffff); integer(posm,0x38,1)
    pointer(posm,0x50,positions); ffi.fill(lookup,65536*8,255)
    for i=0,beacons-1 do
        local id = (i+1)*256
        pointer(entities,8*i,beacon_entities+24*i)
        integer(beacon_entities,24*i+8,id); beacon_entities[24*i+20]=1
        if c.used then integer(used,4*i,1) end
        number(positions,12*i,11+i); number(positions,12*i+4,22+i); number(positions,12*i+8,33)
        for j=0,probes-2 do integer(lookup,8*(id+j),0x100000+j) end
        integer(lookup,8*(id+probes-1),id); integer(lookup,8*(id+probes-1)+4,i)
    end
    integer(sm,0x34,c.stratagems or 0); pointer(sm,0x78,rows)
    for i=0,(c.stratagems or 0)-1 do
        integer(rows,64*i+12,c.anchors and 0x7A or 0x55)
        number(rows,64*i+16,11+i); number(rows,64*i+20,22+i); number(rows,64*i+24,33)
    end
    number(fallback,0x3C,1); number(fallback,0x40,2); number(fallback,0x44,3)
    pointer(em,15871688,entity_hash); integer(em,15871688+8,8)
    integer(em,15871688+12,0xffffffff); integer(em,15871688+16,1)
    ffi.fill(entity_hash,64,255); integer(entity_hash,3*8,11); integer(entity_hash,3*8+4,0)
    integer(em,15937304+12,bit.bor(bit.lshift(1,22),3))
    pointer(exe,0x1a100f0,registry); integer(registry,0x98,4)
    pointer(registry,0xA0,generations); generations[3]=1
    pointer(registry,0x88,objects); pointer(objects,24,object)
    pointer(object,0,vtable); pointer(vtable,0xE8,exe+0x2bd870)
    pointer(object,0x88,scene); number(scene,0x30,1); number(scene,0x34,2); number(scene,0x38,3)
end
local function region_name(p,n)
    local at=address(p)
    for _,r in ipairs(regions) do
        if at>=r.first and at+n<=r.last then return r.name end
    end
    error('Read outside synthetic regions')
end
local function api_for(kind, counts)
    local api={}
    for k,v in pairs(production) do api[k]=v end
    -- The hashes/module lookup are startup-only. No actual game files are needed.
    api.module=function(name) return name and game or exe end
    api.module_hash=function() return 'synthetic' end
    if kind=='direct' then api.read=function(p,n) return ffi.string(p,n) end end
    if counts then
        api.read=function(p,n)
            local name=region_name(p,n)
            local row=counts.regions[name] or {reads=0,bytes=0}
            counts.regions[name]=row; row.reads=row.reads+1; row.bytes=row.bytes+n
            counts.reads=counts.reads+1; counts.bytes=counts.bytes+n
            return production.read(p,n)
        end
        api.pointer=function(...)
            counts.pointers=counts.pointers+1; return production.pointer(...)
        end
        api.writable_data=function(...)
            counts.queries=counts.queries+1; return production.writable_data(...)
        end
        api.write=function(p,bytes)
            assert(p==pm+0x10C and #bytes==8,'Write escaped pending XY')
            counts.writes=counts.writes+1
            -- production.write closes over production.writable_data.
            counts.queries=counts.queries+1
            return production.write(p,bytes)
        end
    end
    return api
end
local function new_counts()
    return {reads=0,bytes=0,pointers=0,queries=0,writes=0,logs=0,prints=0,regions={}}
end
local function install(c,kind,counts)
    local api=api_for(kind,counts)
    local env=setmetatable({}, {__index=_G}); env._G=env
    env.print=function() if counts then counts.prints=counts.prints+1 end end
    env.CowboyBingusModLoader={api=1,open_log=function()
        if counts then counts.logs=counts.logs+1 end
        if c.disk_log then return assert(io.open(assert(log_path,'Pass a workspace log path'),'w')) end
    end}
    env.update=function(...)
        if c.event then integer(pm,0x2E0,2); integer(used,0,1) end
        if c.flap then pointer(game,0x3326468,pm) end
        return ...
    end
    setfenv(assert(loadfile(source..'/archive_loader.lua'))(),env)(function() return api end,patch,
        {revision='synthetic-profile',game_sha256='synthetic',exe_sha256='synthetic'})
    local state=env.ReinforcementBeaconFixData
    if c.centered then
        state.previous=assert(patch.snapshot(api,game,exe))
        state.pending={synthetic=true}
    end
    local function prepare()
        if c.event then
            integer(pm,0x2E0,1); integer(used,0,0)
            number(pm,0x10C,50); number(pm,0x110,60)
            state.pending=nil; state.anchor=nil; state.previous=nil
        end
        if c.flap then pointer(game,0x3326468,nil) end
    end
    local function frame()
        prepare() -- Only event/flap scenarios have fixture-driving overhead.
        local a,b,z=env.update(1/60,nil,'sentinel')
        assert(a==1/60 and b==nil and z=='sentinel','Update return values changed')
    end
    return frame,state,api
end
local function timed(fn)
    collectgarbage('restart'); collectgarbage('collect')
    for i=1,64 do fn() end
    local t=clock(); for i=1,16 do fn() end
    local per=(clock()-t)/16
    local batch=math.max(2,math.min(1024,math.floor(0.02/math.max(per,0.0000001))))
    local samples={}
    for round=1,9 do
        local start=clock(); for i=1,batch do fn() end
        samples[round]=(clock()-start)*1000/batch
    end
    table.sort(samples)
    return samples[5],samples[1],samples[9],batch
end
local scenarios={
    {name='startup_null',missing=true},
    {name='ship',ship=true},
    {name='mp_alive_b0'},
    {name='mp_alive_b4',beacons=4},
    {name='mp_alive_b16',beacons=16},
    {name='mp_alive_b64_stress',beacons=64},
    {name='mp_alive_b128_limit',beacons=128},
    {name='mp_pending_b4',beacons=4,state=2},
    {name='mp_centered_b4',beacons=4,state=2,centered=true},
    {name='mp_pending_used_b128_limit',beacons=128,state=2,used=true},
    {name='mp_b4_probe16_stress',beacons=4,probes=16},
    {name='mp_b16_probe128_limit',beacons=16,probes=128},
    {name='solo_alive_s0',players=1},
    {name='solo_alive_s32',players=1,stratagems=32},
    {name='solo_alive_s128',players=1,stratagems=128},
    {name='solo_alive_s512_limit',players=1,stratagems=512},
    {name='solo_alive_s128_full_source',players=1,stratagems=128,full_source=true},
    {name='solo_alive_s128_b4',players=1,stratagems=128,beacons=4},
    {name='solo_dead_a32_stress',players=1,stratagems=32,anchors=true,state=1},
    {name='solo_dead_a128_stress',players=1,stratagems=128,anchors=true,state=1},
    {name='solo_dead_a512_limit',players=1,stratagems=512,anchors=true,state=1},
    {name='mp_correction',beacons=1,state=1,event=true},
    {name='transition_flap',flap=true},
}
if log_path then
    scenarios[#scenarios+1]={name='mp_correction_disk',beacons=1,state=1,event=true,disk_log=true}
    scenarios[#scenarios+1]={name='transition_flap_disk',flap=true,disk_log=true}
end
print('# LuaJIT='..jit.version..' mode='..mode..' GC64='..tostring(ffi.abi('gc64')))
print('# Synthetic populations; stress/limit scenarios are NOT observed gameplay populations.')
print('# med/min/max are nine batch-average milliseconds per full update; GC enabled.')
print('# direct_ms substitutes ffi.string for ReadProcessMemory only; NOT an optimization proposal.')
print('scenario,mode,median_ms,min_ms,max_ms,batch,direct_ms,snapshot_twice_ms,plan_twice_ms,reads,bytes,pointers,queries,writes,logs,lua_heap_bytes_per_frame')
for _,c in ipairs(scenarios) do
    configure(c)
    -- Prove the raw fixture agrees with the selected scenario before measuring.
    local s,waiting=patch.snapshot(production,game,exe)
    if c.missing then assert(not s and waiting=='waiting_for_game_data:player_manager')
    else
        assert(s.count==(c.players or 4))
        assert(#s.beacons==(c.ship and 0 or c.beacons or 0))
        assert(#s.automatic==(c.anchors and c.stratagems or 0))
        if c.players==1 then assert(s.source[1]==1 and s.source[2]==2) end
        for i,b in ipairs(s.beacons) do assert(b.position[1]==10+i) end
    end
    local counts=new_counts()
    local diagnostic,state=install(c,'native',counts)
    diagnostic(); diagnostic()
    for k,v in pairs(counts) do if type(v)=='number' then counts[k]=0 end end
    counts.regions={}; diagnostic()
    if c.event then
        assert(counts.writes==1 and counts.reads==43 and counts.queries==5)
        assert(ffi.cast('float *',pm+0x10C)[0]==11 and ffi.cast('float *',pm+0x110)[0]==22)
        assert(ffi.cast('float *',pm+0x114)[0]==321 and ffi.cast('float *',pm+0x12C)[0]==5)
    else assert(counts.writes==0) end
    if not c.event and not c.flap and not c.missing and not c.ship then
        local expected=18+2*(c.beacons or 0)*(4+(c.probes or 1))
        if c.players==1 then expected=expected+2*(5+(c.stratagems or 0)+(c.full_source and 9 or 0)) end
        assert(counts.reads==expected,c.name..': read count '..counts.reads..' vs '..expected)
        assert(counts.logs==0,'Steady state unexpectedly logs')
    end
    for name,row in pairs(counts.regions) do
        print(string.format('# region,%s,%s,%d,%d',c.name,name,row.reads,row.bytes))
    end
    configure(c)
    local frame,native_state=install(c,'native')
    local median,minimum,maximum,batch=timed(frame)
    local expected_status=c.missing and 'waiting_for_game_data:player_manager'
        or c.event and 'beacon_spawn_centered'
        or c.centered and 'reinforcement_already_centered'
        or c.state==2 and 'beacon_association_unavailable'
        or 'waiting_for_reinforcement'
    assert(native_state.status==expected_status,native_state.status)
    -- Held-GC heap growth is separate from timing and has no counter wrappers.
    collectgarbage('collect'); collectgarbage('stop')
    local before=collectgarbage('count')
    for i=1,32 do frame() end
    local allocation=(collectgarbage('count')-before)*1024/32
    collectgarbage('restart'); collectgarbage('collect')
    configure(c)
    local direct,direct_state=install(c,'direct')
    local direct_ms=timed(direct)
    assert(direct_state.status==expected_status,direct_state.status)
    configure(c)
    local snapshot_ms,plan_ms=0,0
    if not c.event and not c.flap then
        snapshot_ms=2*timed(function() patch.snapshot(production,game,exe) end)
        local snapshot=patch.snapshot(production,game,exe)
        if snapshot then
            local tracker={}; patch.plan(snapshot,tracker)
            if c.centered then tracker.pending={synthetic=true} end
            plan_ms=2*timed(function() patch.plan(snapshot,tracker) end)
        end
    end
    print(string.format('%s,%s,%.6f,%.6f,%.6f,%d,%.6f,%.6f,%.6f,%d,%d,%d,%d,%d,%d,%.1f',
        c.name,mode,median,minimum,maximum,batch,direct_ms,snapshot_ms,plan_ms,
        counts.reads,counts.bytes,counts.pointers,counts.queries,counts.writes,counts.logs,allocation))
    io.stdout:flush()
end
print('# PASS: fixture layouts, exact read counts, steady-state log suppression, correction XY/write boundary, and wrapper returns')
assert(#owners>0) -- retain every native allocation through the last measurement
