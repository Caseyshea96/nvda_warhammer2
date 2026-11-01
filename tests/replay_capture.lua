-- Replay a recorded campaign screen through the reader, offline.
-- Usage: lua5.1 tests/replay_capture.lua <native-ui-campaign-discovery.jsonl> [run]
-- Without a run number it lists the runs. With one it rebuilds that run's UI
-- tree from the "node"/"skip"/"excluded" lines (text, tooltip, state, child
-- count, as the game reported them), starts the reader in player mode and
-- prints every item exactly as it would be spoken (F2 through the list).
-- With a second run number it then swaps the screen to that run (same element
-- objects, as when a panel opens) and prints what the re-read announces.
-- Stock Lua, not the game engine: a pass here is not live proof.
local source,wanted,after=arg[1],tonumber(arg[2] or ''),tonumber(arg[3] or '')
assert(source,'usage: replay_capture.lua <discovery.jsonl> [run]')

local function decode(line)
    -- Flat JSON objects only (the discovery log's shape).
    local out,i={},2
    local function skip() while line:sub(i,i):match('[%s,]') do i=i+1 end end
    local function str()
        i=i+1; local buf={}
        while true do
            local c=line:sub(i,i)
            if c=='"' then i=i+1; return table.concat(buf) end
            if c=='\\' then
                local e=line:sub(i+1,i+1)
                if e=='n' then buf[#buf+1]='\n' elseif e=='t' then buf[#buf+1]='\t' elseif e=='r' then buf[#buf+1]='\r'
                elseif e=='u' then
                    local code=tonumber(line:sub(i+2,i+5),16) or 63
                    if code<128 then buf[#buf+1]=string.char(code)
                    elseif code<2048 then buf[#buf+1]=string.char(192+math.floor(code/64),128+code%64)
                    else buf[#buf+1]=string.char(224+math.floor(code/4096),128+math.floor(code/64)%64,128+code%64) end
                    i=i+4
                else buf[#buf+1]=e end
                i=i+2
            elseif c=='' then return table.concat(buf)
            else buf[#buf+1]=c; i=i+1 end
        end
    end
    while i<=#line do
        skip(); if line:sub(i,i)=='}' or line:sub(i,i)=='' then break end
        local key=str(); skip(); i=i+1; skip()   -- the colon
        local c=line:sub(i,i)
        if c=='"' then out[key]=str()
        else
            local raw=line:match('^[^,}]+',i); i=i+#raw
            if raw=='true' then out[key]=true elseif raw=='false' then out[key]=false
            elseif raw=='null' then out[key]=nil else out[key]=tonumber(raw) or raw end
        end
    end
    return out
end

local runs,order={},{}
for line in io.lines(source) do
    if line:sub(1,3)=='\239\187\191' then line=line:sub(4) end
    if line:sub(1,1)=='{' then
        local r=decode(line)
        if r.run and (r.kind=='node' or r.kind=='skip' or r.kind=='excluded') then
            if not runs[r.run] then runs[r.run]={}; order[#order+1]=r.run end
            local t=runs[r.run]; t[#t+1]=r
        end
    end
end
if not wanted then
    for _,run in ipairs(order) do
        local t,title=runs[run],''
        for _,r in ipairs(t) do
            if r.kind=='node' and (r.id=='dy_title' or r.id=='tx_title' or r.id=='dy_province') and (r.text or '')~='' then title=title .. ' / ' .. r.text end
        end
        print(('run %d: %d lines%s'):format(run,#t,title))
    end
    return
end
local records=assert(runs[wanted],'no such run')

local prefix=(os.getenv('LOCALAPPDATA') or '') .. '/WarhammerAccess/'
local files,listeners,pending={}, {}, false
local nodes={}
local function node(path)
    if nodes[path] then return nodes[path] end
    local item={path=path,id='',count=0,text='',tip='',state='active',visible=true,address=newproxy()}
    function item:Visible() return self.visible end
    function item:Id() return self.id end
    function item:ChildCount() return self.count end
    function item:GetStateText() return self.text end
    function item:GetTooltipText() return self.tip end
    function item:CurrentState() return self.state end
    function item:IsInteractive() return true end
    function item:Address() return self.address end
    function item:Find(index)
        local child=nodes[self.path .. '.child' .. index]
        if not child then child=node(self.path .. '.child' .. index); child.visible=false; child.id='unrecorded' end
        return child
    end
    function item:SimulateLClick() end
    nodes[path]=item; return item
end
local function load(list)
    for _,item in pairs(nodes) do item.visible=false end
    for _,r in ipairs(list) do
        local item=node(r.path); item.visible=true
        if r.kind=='node' then
            item.id=r.id or ''; item.text=r.text or ''; item.tip=r.tooltip or ''; item.state=r.state or ''
            item.count=tonumber(r.children) or 0
        elseif r.kind=='skip' then item.visible=false; item.id=r.id or 'hidden'
        else item.id=r.id or ''; item.count=0 end
    end
end
load(records)
assert(nodes.tree,'run has no root')
local timer='warhammer_campaign_readonly_tick'
core={is_campaign=function() return true end,is_battle=function() return false end,
    is_ui_created=function() return true end,get_ui_root=function() return nodes.tree end,
    add_listener=function(_,name,event,condition,callback,persist) listeners[name]={event,condition,callback,persist} end,
    remove_listener=function(_,name) listeners[name]=nil end,
    add_ui_destroyed_callback=function() end}
cm=setmetatable({},{__index=function() error('cm must not be used') end})
real_timer={register_singleshot=function(name) if name==timer then pending=true end end,unregister=function() end}
UIComponent=function(value) return value end
effect={get_localised_string=function() return '' end}
local real_io=io
io={open=function(path,mode)
    assert(path:sub(1,#prefix)==prefix,'replay opened an unexpected path: ' .. tostring(path))
    if mode=='r' then if not files[path] then return nil end
        return {read=function(_,limit) local v=files[path]; return type(v)=='string' and v:sub(1,limit) or v end,close=function() return true end} end
    if mode=='w' then files[path]='' end
    return {write=function(self,text) files[path]=(files[path] or '') .. text; return self end,close=function() return true end}
end}
local function fire(event,value)
    local names={}; for name in pairs(listeners) do names[#names+1]=name end
    for _,name in ipairs(names) do
        local l=listeners[name]
        if l and l[1]==event and (l[2]==true or l[2](value)) then
            if l[4]==false then listeners[name]=nil end
            l[3](value)
        end
    end
end
dofile('diagnostics/campaign_readonly.lua')
fire('FirstTickAfterWorldCreated',{})
for n=1,400 do if not pending then break end; pending=false; fire('RealTimeTrigger',{string=timer}) end
local function spoken() return files[prefix .. 'bridge.jsonl'] or '' end
local function last()
    local text
    for line in spoken():gmatch('[^\n]+') do local r=decode(line); if r.text then text=r.text end end
    return text
end
-- io stays stubbed: the reader must never touch the real %LOCALAPPDATA% files.
local first=last() or ''
print('arrival: ' .. first)
local total=tonumber(spoken():match('(%d+) items%.') or first:match(' of (%d+)') or 0) or 0
fire('ShortcutTriggered',{string='script_F2'})
local start=last()
-- Home: step back until the position says 1.
for n=1,total do
    local here=last() or ''
    if here:match(', 1 of %d+') then break end
    fire('ShortcutTriggered',{string='script_F3'})
end
local seen=0
for n=1,total do
    print(last())
    seen=seen+1
    fire('ShortcutTriggered',{string='script_F2'})
end
print(('%d items'):format(seen))
if after then
    local before=#spoken()
    load(assert(runs[after],'no such run'))
    for n=1,600 do if not pending then break end; pending=false; fire('RealTimeTrigger',{string=timer}) end
    print('-- after the screen changed to run ' .. after .. ':')
    for line in spoken():sub(before+1):gmatch('[^\n]+') do local r=decode(line); if r.text then print(r.text) end end
end
