return function(create_api,patch,build)
    if rawget(_G,'ReinforcementBeaconFixData') then return end
    local state={revision=build.revision,active=false,corrections=0}
    rawset(_G,'ReinforcementBeaconFixData',state)
    local function report(status,active)
        state.active=active
        if state.status==status then return end
        state.status=status
        print('[ReinforcementBeaconsFixed] '..build.revision..': '..status)
        pcall(function()
            local directory=os.getenv('LOCALAPPDATA')
            if not directory then return end
            local file=io.open(directory..'/ReinforcementBeaconsFixed.log','w')
            if not file then return end
            file:write(build.revision..'\n'..status..'\ncorrections='..state.corrections..'\n')
            if state.last then
                file:write(string.format('%s beacon=%d from=%.6f,%.6f to=%.6f,%.6f association=%s\n',
                    state.last.kind,state.last.beacon,state.last.from[1],state.last.from[2],
                    state.last.to[1],state.last.to[2],state.last.association or 'used'))
            end
            file:close()
        end)
    end
    local ok,api,game,exe=pcall(function()
        local loader=rawget(_G,'CowboyBingusModLoader')
        assert(loader and loader.api==1,'Bingus Shared Loader API 1 is required')
        local api=create_api()
        local game,exe=api.module('game.dll'),api.module(nil)
        assert(game and exe,'Required modules unavailable')
        assert(api.module_hash(game)==build.game_sha256,'Unsupported game module')
        assert(api.module_hash(exe)==build.exe_sha256,'Unsupported executable')
        assert(type(update)=='function','Game update unavailable')
        return api,game,exe
    end)
    if not ok then report(tostring(api),false);return end
    report('waiting_for_reinforcement',false)
    local previous,stopped=update,false
    local function check()
        if stopped then return end
        local called,accepted,reason,active=pcall(patch.apply,api,game,exe,state)
        if not called then stopped=true;report(tostring(accepted),false);return end
        if not accepted then stopped=true end
        report(tostring(reason),active==true)
    end
    local function after(...)
        check()
        return ...
    end
    update=function(...)
        check()
        return after(previous(...))
    end
end
