-- Synthetic equivalents of three solo reinforcement transitions; no live data.
local rows={}
for event=1,3 do
    local source={event*100,event*20,2}
    local anchor={source[1]+30,source[2]-25,3}
    local queued={anchor[1]+20,anchor[2]+15,2}
    local function row(state,position,automatic,beacons,time,moving_source)
        return {identity='synthetic-mission',id=1,owned=true,count=1,mode=1,
            state=state,use_bit=0,countdown=time or 5,position=position,
            source=moving_source or source,beacons=beacons or {},automatic=automatic or {}}
    end
    local automatic={{key='synthetic-anchor-'..event,position=anchor}}
    rows[#rows+1]=row(3,{0,0,0})
    rows[#rows+1]=row(1,{0,0,0},automatic)
    rows[#rows+1]=row(2,queued,automatic,{{id=event+10,owned=true,used=1,position=anchor}},4.9,
        {source[1]+0.1,source[2]+0.1,source[3]})
    rows[#rows+1]=row(2,queued,automatic,{},2,{source[1]+5,source[2]-5,source[3]})
    rows[#rows+1]=row(3,{0,0,0},automatic)
end
return rows
