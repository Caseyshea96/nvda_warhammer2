local saved_io,saved_date=io,os.date
local scenarios=0
local watchdog_pending
local nodes,files,listeners,pending,ui_ready,destroyed,dispatches,clock,clicked
local prefix=(os.getenv('LOCALAPPDATA') or '') .. '/WarhammerAccess/'
local owner=string.rep('a',32)
local valid='WH2CAM1\t' .. owner .. '\t2026-10-29T18:30:00Z\tverify\n'
local timer='warhammer_campaign_readonly_tick'
local function start(context,flag,count)
    scenarios=scenarios+1;nodes={};files={};listeners={};pending=false;ui_ready=true;dispatches=0;clock='2026-10-29T18:00:00Z'
    files[prefix .. 'campaign-discovery.tsv']=flag
    local function node(path,id,children,label,visible)
        local item={path=path,id=id,count=children,label=label or '',visible=visible~=false,address=newproxy(),faults={}}
        local function value(self,method,fallback)
            if self.faults[method]=='throw' then error('Synthetic native failure') end
            if self.faults[method]=='function' then return function() end end
            if self.faults[method]=='nil' then return nil end
            if self.faults[method]=='number' then return 9 end
            return fallback
        end
        function item:Visible() return value(self,'Visible',self.visible) end
        function item:Id() return value(self,'Id',self.id) end
        function item:ChildCount() return value(self,'ChildCount',self.count) end
        function item:GetStateText() return value(self,'GetStateText',self.label) end
        function item:GetTooltipText() return value(self,'GetTooltipText','') end
        function item:CurrentState() return value(self,'CurrentState','active') end
        function item:IsInteractive() return value(self,'IsInteractive',true) end
        function item:Address() return self.address end
        function item:Find(index) return nodes[self.path .. '.child' .. index] end
        function item:SimulateLClick() dispatches=dispatches+1;clicked=self.path end
        nodes[path]=item;return item
    end
    node('tree','root',4)
    node('tree.child0','layout',count or 3)
    for index=0,(count or 3)-1 do node('tree.child0.child' .. index,'control_' .. index,0,'Item ' .. index) end
    node('tree.child1','cinematic_bars',0,'',false)
    node('tree.child2','advice_interface',0,'Advice')
    node('tree.child3','watermark_square',0,'',false)
    core={is_campaign=function() return context=='campaign' end,is_battle=function() return context=='battle' end,
        is_ui_created=function() return ui_ready end,get_ui_root=function() return nodes.tree end,
        add_listener=function(_,name,event,condition,callback,persist) listeners[name]={event,condition,callback,persist} end,
        remove_listener=function(_,name) listeners[name]=nil end,
        add_ui_destroyed_callback=function(_,callback) destroyed=callback end}
    cm=setmetatable({},{__index=function() error('Model-timer/query path must not be used') end})
    real_timer={register_singleshot=function(name,delay)
            if name=='warhammer_campaign_readonly_watchdog' then assert(delay==3000);watchdog_pending=true;return end
            assert(name==timer and (delay==1000 or delay==100));pending=true end,
        unregister=function(name) if name==timer then pending=false else assert(name=='warhammer_campaign_readonly_watchdog');watchdog_pending=false end end}
    UIComponent=function(value) assert(type(value)=='table');return value end
    os.date=function(format) assert(format=='!%Y-%m-%dT%H:%M:%SZ');return clock end
    io={open=function(path,mode)
        if mode=='r' then if not files[path] then return nil end;return {read=function(_,limit) local v=files[path];return type(v)=='string' and v:sub(1,limit) or v end,close=function() return true end} end
        if mode=='w' then files[path]='' end
        return {write=function(self,text) files[path]=(files[path] or '') .. text;return self end,close=function() return true end}
    end}
    dofile('diagnostics/campaign_readonly.lua')
    return node
end
local function fire(event,value)
    local names={};for name in pairs(listeners) do names[#names+1]=name end
    for _,name in ipairs(names) do
        local listener=listeners[name]
        if listener and listener[1]==event and (listener[2]==true or listener[2](value)) then
            if listener[4]==false then listeners[name]=nil end
            listener[3](value)
        end
    end
end
local function begin() fire('FirstTickAfterWorldCreated',{}) end
local function tick(count)
    for n=1,count do
        -- One tick is one second of game time: with HUD reading on, the player
        -- reader runs every 100 ms (slow work every tenth run).
        local state=files[prefix .. 'reader-state.tsv']
        local fast=type(state)=='string' and state:find('\t1\tcampaign',1,true) and (files[prefix .. 'campaign-discovery-status.json'] or '')==''
        for k=1,fast and 10 or 1 do
            if not pending then return end
            pending=false;fire('RealTimeTrigger',{string=timer})
        end
    end
end
local function contents(name) return files[prefix .. name] or '' end
local function status() return contents('campaign-discovery-status.json') end
local function finish()
    for n=1,40 do
        tick(1)
        if status():find('"phase":"ready"',1,true) or status():find('"phase":"limited"',1,true) then return end
    end
    error('Capture failed to reach a bounded terminal state: '..status())
end
local function capture_request(token,which_owner,which_session,generation,expires)
    local session=which_session or status():match('"session":"([^"]+)"')
    local wanted=generation or status():match('"generation":(%d+)')
    files[prefix .. 'campaign-discovery-request.tsv']='WH2CAMCAP1\t' .. (which_owner or owner) .. '\t' .. session .. '\t' .. wanted .. '\t' .. token .. '\t' .. (expires or '2026-10-29T18:00:05Z') .. '\n'
end
for _,context in ipairs({'frontend','battle'}) do start(context,valid);assert(next(listeners)==nil and contents('bridge.jsonl')=='') end
for _,flag in ipairs({'','bad',valid:gsub('18:30:00','17:59:59'),valid:gsub('\n$',''),valid:gsub('verify','activate')}) do
    start('campaign',flag);assert(next(listeners)~=nil,'Without a valid flag the player reader starts')
    begin();tick(6);assert(status()=='','Player mode publishes no diagnostic status')
end
start('campaign',valid);begin();finish()
assert(status():find('"complete":true',1,true));assert(status():find('"count":4',1,true))
assert(contents('native-ui-campaign-discovery.jsonl'):find('"physical_keys_verified":false',1,true))
fire('ShortcutTriggered',{string='script_F3'});assert(contents('bridge.jsonl'):find('Advice, 4 of 4',1,true),contents('bridge.jsonl'))
fire('ShortcutTriggered',{string='script_F4'});assert(dispatches==0)
tick(2);assert(contents('reader-state.tsv'):find('\t1\tcampaign\n',1,true),'Verify mode turns HUD reading on for live key tests')
-- The exact early-scan regression: no text getters while HUD is hidden or bars visible.
start('campaign',valid);nodes['tree.child0'].visible=false;nodes['tree.child1'].visible=true
nodes['tree.child2'].faults.GetStateText='throw';begin();tick(8)
assert(not contents('native-ui-campaign-discovery.jsonl'):find('"kind":"node"',1,true))
assert(contents('bridge.jsonl')=='')
nodes['tree.child0'].visible=true;nodes['tree.child2'].faults.GetStateText=nil;tick(3)
assert(not contents('native-ui-campaign-discovery.jsonl'):find('"kind":"node"',1,true),'Visible cinematic still blocks capture')
nodes['tree.child1'].visible=false;finish();assert(status():find('"complete":true',1,true))
start('campaign',valid);nodes['tree.child0'].visible=false;begin();tick(182)
assert(status():find('"phase":"waiting-timeout"',1,true));assert(not contents('native-ui-campaign-discovery.jsonl'):find('"kind":"node"',1,true))
nodes['tree.child0'].visible=true;capture_request(string.rep('b',32));finish();assert(status():find('"complete":true',1,true))
-- Excluded world-space nodes are labelled, never interrogated for text or children.
local make=start('campaign',valid);nodes.tree.count=5
local world=make('tree.child4','3d_ui_parent',10000,'World text must not be read')
for _,method in ipairs({'GetStateText','GetTooltipText','CurrentState','ChildCount'}) do world.faults[method]='throw' end
begin();finish();assert(status():find('"complete":true',1,true))
assert(contents('native-ui-campaign-discovery.jsonl'):find('"reason":"world-space"',1,true))
assert(not contents('native-ui-campaign-discovery.jsonl'):find('World text must',1,true))
-- Native success and type are independently recorded; no double-counted issue.
for _,fault in ipairs({'nil','function','number','throw'}) do
    start('campaign',valid);nodes['tree.child0.child0'].faults.GetStateText=fault;begin();finish()
    assert(status():find('"errors":1',1,true),status())
    local log=contents('native-ui-campaign-discovery.jsonl')
    assert(log:find('"method":"GetStateText"',1,true))
    assert(log:find('"value_type":"' .. (fault=='throw' and 'nil' or fault) .. '"',1,true))
    assert(log:find('"ok":' .. (fault=='throw' and 'false' or 'true'),1,true))
    assert(not log:find('reader-verification',1,true))
end
start('campaign',valid,80);begin();tick(3);files[prefix .. 'campaign-discovery.tsv']=nil;tick(1)
assert(not pending and status():find('lease-ended',1,true));assert(not listeners[timer])
local before=contents('bridge.jsonl');fire('ShortcutTriggered',{string='script_F2'});assert(contents('bridge.jsonl')==before)
start('campaign',valid,80);begin();tick(3);nodes.tree.address=newproxy();tick(1)
assert(status():find('"phase":"cancelled"',1,true))
start('campaign',valid,80);begin();tick(3);nodes['tree.child0'].address=newproxy();tick(1)
assert(status():find('"phase":"cancelled"',1,true))
start('campaign',valid);nodes['tree.child0.child1'].visible=false;begin();finish()
assert(not contents('native-ui-campaign-discovery.jsonl'):find('Item 1',1,true))
start('campaign',valid,257);begin();finish();assert(status():find('"phase":"limited"',1,true))
start('campaign',valid,80);begin();tick(3);destroyed();tick(1)
assert(status():find('"phase":"cancelled"',1,true));assert(status():find('"count":0',1,true))
-- 0.6.73: a torn-down campaign UI (quit, load, exit) says 'loading', also on
-- later ticks, so the companion does not call the stopped heartbeat busy.
assert(contents('reader-state.tsv'):find('\tloading\n',1,true),'UI teardown marks loading: ' .. contents('reader-state.tsv'))
start('campaign',valid);begin();tick(12)
assert(contents('reader-state.tsv'):find('\tcampaign\n',1,true),'The map says campaign: ' .. contents('reader-state.tsv'))
destroyed();tick(12)
assert(contents('reader-state.tsv'):find('\tloading\n',1,true),'Loading stays after teardown: ' .. contents('reader-state.tsv'))
start('campaign',valid);ui_ready=false;begin();tick(4);assert(contents('bridge.jsonl')=='')
-- Fresh explicit capture sees changed fields; repeated tokens cannot reread.
start('campaign',valid);begin();finish();nodes['tree.child0.child0'].label='Updated HUD value'
capture_request(string.rep('b',32));finish()
assert(status():find('"attempts":2',1,true));fire('ShortcutTriggered',{string='script_F2'});assert(contents('bridge.jsonl'):find('Updated HUD value',1,true))
local old=status():match('"generation":(%d+)');tick(2)
assert(status():match('"generation":(%d+)')==old,'Same request must not repeat')
capture_request(string.rep('c',32));finish();capture_request(string.rep('d',32));tick(1)
assert(status():find('"result":"capture-limit"',1,true));assert(status():find('"attempts":3',1,true))
for _,bad in ipairs({'owner','session','generation','expired','late-expiry','framing'}) do
    start('campaign',valid);begin();finish()
    if bad=='owner' then capture_request(string.rep('b',32),string.rep('c',32))
    elseif bad=='session' then capture_request(string.rep('b',32),nil,'old-session')
    elseif bad=='generation' then capture_request(string.rep('b',32),nil,nil,'0')
    elseif bad=='expired' then capture_request(string.rep('b',32),nil,nil,nil,'2026-10-29T17:59:59Z')
    elseif bad=='late-expiry' then capture_request(string.rep('b',32),nil,nil,nil,'2026-10-29T18:31:00Z')
    else capture_request(string.rep('b',32));files[prefix .. 'campaign-discovery-request.tsv']=files[prefix .. 'campaign-discovery-request.tsv'] .. 'activate\n' end
    tick(1);assert(status():find('"attempts":1',1,true),'Invalid capture request cannot start a run')
    assert(dispatches==0)
end
start('campaign',valid);real_timer=nil;begin();assert(status():find('"phase":"error"',1,true))
start('campaign',valid);begin();finish();tick(1801);assert(not pending and status():find('lease-ended',1,true),'Independent lifetime bound')
-- 0.6.32: NVDA-style campaign items; values labelled by their tooltips;
-- the hover tooltip layer is left out; long descriptions are not "limited".
local make=start('campaign',valid)
local treasury=nodes['tree.child0.child0']; treasury.id='dy_treasury'; treasury.label='6000'
function treasury:GetTooltipText() return 'Treasury||This is the total amount of money' end
local menu=nodes['tree.child0.child1']; menu.id='button_menu'; menu.label=''
function menu:GetTooltipText() return 'Menu [[col:yellow]] <Esc>[[/col]]' end
local tab=nodes['tree.child0.child2']; tab.id='tab_events'; tab.label=''
function tab:GetTooltipText() return 'Events' end
nodes['tree.child2'].label=string.rep('x',3000)
make('tree.child4','Tooltip',0,'Province: Somewhere'); nodes.tree.count=5
begin();finish()
assert(status():find('"complete":true',1,true) and status():find('"count":4',1,true),status())
for n=1,4 do fire('ShortcutTriggered',{string='script_F2'}) end
local spoken=contents('bridge.jsonl')
assert(spoken:find('Treasury, 6000, 1 of 4, This is the total amount of money',1,true),spoken)
assert(spoken:find('Menu, button, 2 of 4',1,true) and spoken:find('Events, tab, 3 of 4',1,true),spoken)
assert(not spoken:find('Province: Somewhere',1,true) and not spoken:find(', text,',1,true),'Hover tooltip excluded; no "text" role')
assert(contents('native-ui-campaign-discovery.jsonl'):find('"reason":"hover-tooltip"',1,true))
fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==0 and contents('bridge.jsonl'):find('Not supported yet.',1,true),'F4 on text does nothing')
fire('ShortcutTriggered',{string='script_F3'}); fire('ShortcutTriggered',{string='script_F3'}); fire('ShortcutTriggered',{string='script_F4'})
assert(dispatches==1 and clicked=='tree.child0.child2' and contents('bridge.jsonl'):find('Events activated.',1,true),'Enter/F4 activates the Events tab')
-- 0.6.33: income without brackets, End Turn named, bare counts joined to
-- the item before them, panel titles as headings.
start('campaign',valid,7)
local function set(index,id,label,tip)
    local item=nodes['tree.child0.child' .. index]; item.id=id; item.label=label
    function item:GetTooltipText() return tip or '' end
end
set(0,'tx_(','('); set(1,'dy_income','1901'); set(2,'tx_)',')')
set(3,'button_end_turn','','[[col:red]]Dismiss all advice and related events before ending turn.[[/col]]')
set(4,'dy_title','Missions'); set(5,'child_count','1'); set(6,'counter','2')
begin();finish()
for n=1,8 do fire('ShortcutTriggered',{string='script_F2'}) end
local heard=contents('bridge.jsonl')
assert(heard:find('Income, 1901, ',1,true),heard)
assert(heard:find('End turn, button, ',1,true) and heard:find('Dismiss all advice and related events before ending turn.',1,true),heard)
assert(heard:find('Missions, heading, 1, ',1,true) and heard:find('Unresolved events, 2, ',1,true),heard)
assert(not heard:find('"(, ',1,true) and not heard:find('"text":"(',1,true) and not heard:find('"text":")',1,true),'No bracket items')
assert(status():find('"count":5',1,true),status())
-- 0.6.34: player reader (no flag) and HUD reading mode with companion keys.
start('campaign',nil)
begin()
for n=1,12 do tick(1) end
local heard=contents('bridge.jsonl')
assert(heard:find('Campaign map, 4 items.',1,true),heard)
assert(status()=='' and contents('campaign-discovery-request.tsv')=='','No diagnostic channel for players')
-- 0.6.60: HUD reading is on once the map is read; Shift+F2 switches it off and on.
assert(contents('reader-state.tsv'):find('\t1\tcampaign\n',1,true),'Players start with HUD reading on: ' .. contents('reader-state.tsv'))
fire('ShortcutTriggered',{string='script_shift_F2'})
assert(contents('reader-state.tsv'):find('\t0\tcampaign\n',1,true) and contents('bridge.jsonl'):find('Map controls.',1,true))
for n=1,15 do tick(1) end
assert(contents('reader-state.tsv'):find('\t0\tcampaign\n',1,true),'A player who switched it off keeps it off')
fire('ShortcutTriggered',{string='script_shift_F2'})
assert(contents('reader-state.tsv'):find('\t1\tcampaign\n',1,true),contents('reader-state.tsv'))
assert(contents('bridge.jsonl'):find('Reading HUD.',1,true))
local session=contents('reader-state.tsv'):match('^WH2READER1\t([^\t]+)\t')
local seq=0
local function keys(owner_id,actions)
    local lines={'WH2KEYS1\t' .. owner_id .. '\t' .. session .. '\t1'}
    for _,action in ipairs(actions) do seq=seq+1; lines[#lines+1]=seq .. '\t' .. action end
    files[prefix .. 'keys.tsv']=table.concat(lines,'\n') .. '\n'
    tick(1)
end
local function last_text() return (contents('bridge.jsonl'):match('"text":"([^"]*)"}\n$')) end
keys('companion',{'next'}); local before=last_text()
keys('companion',{'next'}); assert(last_text():find(', 2 of 4',1,true),last_text())
keys('companion',{'last'}); assert(last_text():find(', 4 of 4',1,true),last_text())
keys('companion',{'first'}); assert(last_text():find(', 1 of 4',1,true),last_text())
keys('companion',{'letter:i'}); assert(last_text():find('Item ',1,true)==1,last_text())
keys('companion',{'activate'}); assert(last_text()=='Not supported yet.' and dispatches==0)
keys('companion',{'next'},'other-session')
fire('ShortcutTriggered',{string='script_shift_F2'})
assert(contents('reader-state.tsv'):find('\t0\tcampaign\n',1,true) and last_text()=='Map controls.')
local quiet=contents('bridge.jsonl')
keys('companion',{'next','next'}); assert(contents('bridge.jsonl')==quiet,'Keys are ignored while HUD reading is off')
fire('ShortcutTriggered',{string='script_shift_F3'}); for n=1,10 do tick(1) end
assert(select(2,contents('bridge.jsonl'):gsub('Campaign map, 4 items.',''))==2,'Shift+F3 reads the screen again')
assert(dispatches==0)
-- 0.6.36: a newly shown panel is read automatically, starting at its first
-- new item; a moving hover tooltip never triggers a re-read.
local make=start('campaign',nil)
begin(); for n=1,12 do tick(1) end
assert(contents('bridge.jsonl'):find('Campaign map, 4 items.',1,true))
local panel=make('tree.child4','technology_panel',1,'',true); nodes.tree.count=6
make('tree.child4.child0','tx_title',0,'Technology')
local hover=make('tree.child5','Tooltip',0,'Province: Somewhere',false)
hover.visible=true; tick(4); hover.visible=false; tick(1)
local function updates() return select(2,contents('bridge.jsonl'):gsub('Screen updated%.','')) end
for n=1,12 do tick(1) end
assert(updates()==1,contents('bridge.jsonl'))
assert(contents('bridge.jsonl'):find('Technology, heading, ',1,true),'Starts at the new panel')
local quiet=contents('bridge.jsonl')
hover.visible=true; for n=1,6 do tick(1) end; hover.visible=false; for n=1,6 do tick(1) end
assert(contents('bridge.jsonl')==quiet,'Hover tooltip does not trigger a re-read')
panel.visible=false; for n=1,12 do tick(1) end
assert(updates()==2,'Closing the panel re-reads too')
assert(dispatches==0)
-- 0.6.37: a panel swapped deeper inside the HUD is noticed; blinking is not.
local make=start('campaign',nil)
begin(); for n=1,12 do tick(1) end
local first=nodes['tree.child0.child0']; first.visible=false
local swapped=make('tree.child0.child3','mission_issued',0,'Mission Issued!'); nodes['tree.child0'].count=4
for n=1,14 do tick(1) end
assert(select(2,contents('bridge.jsonl'):gsub('Screen updated%.',''))==1,contents('bridge.jsonl'))
assert(contents('bridge.jsonl'):find('Mission Issued!, ',1,true),'Starts at the swapped-in panel')
local quiet=contents('bridge.jsonl')
for n=1,20 do swapped.visible=(n%2==0); tick(1) end
swapped.visible=true; tick(1)
assert(select(2,contents('bridge.jsonl'):gsub('Screen updated%.',''))<=2,'Blinking does not cause repeated re-reads')
assert(dispatches==0)
-- 0.6.38: HUD buttons and tabs activate after re-verification; End Turn asks;
-- text, toggles, unavailable and changed targets never click.
start('campaign',nil,5)
local function set(index,id,label,tip,state,interactive)
    local item=nodes['tree.child0.child' .. index]; item.id=id; item.label=label or ''
    function item:GetTooltipText() return tip or '' end
    if state then function item:CurrentState() return state end end
    if interactive==false then function item:IsInteractive() return false end else function item:IsInteractive() return true end end
end
set(0,'button_diplomacy','','Diplomacy||Negotiate'); set(1,'button_end_turn','','End turn warning')
set(2,'button_rituals','','Rites||Perform rites','inactive'); set(3,'toggle_interrupt_button','','Interventions'); set(4,'dy_title','Missions')
begin(); for n=1,12 do tick(1) end
local function press(times) for n=1,times do fire('ShortcutTriggered',{string='script_F2'}) end end
local function said() return contents('bridge.jsonl'):match('"text":"([^"]*)"}\n$') end
-- Document order, titles first: Missions, Diplomacy, End turn, Rites, Interventions, Advice.
fire('ShortcutTriggered',{string='script_F4'}); assert(said()=='Not supported yet.' and dispatches==0,'Text is not actionable')
press(1); fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==1 and clicked=='tree.child0.child0' and said()=='Diplomacy activated.',said())
press(1); fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==1 and said()=='End turn? Press Enter again to confirm.',said())
fire('ShortcutTriggered',{string='script_F3'}); fire('ShortcutTriggered',{string='script_F2'})
fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==1,'Moving away cancelled the confirmation')
fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==2 and clicked=='tree.child0.child1' and said()=='End turn activated.',said())
press(1); fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==2 and said()=='Rites is unavailable.',said())
press(1); fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==2 and said()=='Not supported yet.','Toggles stay read only')
press(1); fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==2,'Headings are not actionable')
-- A replaced target is re-read, never clicked.
start('campaign',nil,2)
set(0,'button_diplomacy','','Diplomacy')
begin(); for n=1,12 do tick(1) end
nodes['tree.child0.child0'].id='button_other'
fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==0 and said()=='The screen changed. Reading it again.',said())
assert(contents('native-ui-campaign-discovery.jsonl'):find('"kind":"activation-blocked","reason":"identity"',1,true))
-- 0.6.40: a new dialog starts at its title/text; advisor text is announced live.
local make=start('campaign',nil,2)
local advisor=nodes['tree.child0.child0']; advisor.id='Text'; advisor.label='First advice.'
begin(); for n=1,12 do tick(1) end
advisor.label='Second advice.'; tick(1)
assert(contents('bridge.jsonl'):find('Advisor: Second advice.',1,true),contents('bridge.jsonl'))
local quiet=contents('bridge.jsonl'); tick(3); assert(contents('bridge.jsonl')==quiet,'Unchanged text is not repeated')
local dialog=make('tree.child4','mission_dialog',3,'',true); nodes.tree.count=5
make('tree.child4.child0','button_next',0,'Next')
make('tree.child4.child1','dy_title',0,'Mission Issued!')
make('tree.child4.child2','description',0,'Research a technology.')
for n=1,14 do tick(1) end
local after=contents('bridge.jsonl'):match('Screen updated%.".-"text":"([^"]*)"')
assert(after and after:find("Mission Issued!, heading",1,true)==1,contents("bridge.jsonl"):sub(-700))
assert(dispatches==0)
-- 0.6.41: unlabelled buttons get names from their IDs (advisor Close).
local make=start('campaign',nil,1)
local advice=make('tree.child4','advice_interface',1,'',true); nodes.tree.count=5
make('tree.child4.child0','button_close',0,'',true)
make('tree.child0.child0','button_overlay_test',0,'',true)
begin(); for n=1,12 do tick(1) end
for n=1,4 do fire('ShortcutTriggered',{string='script_F2'}) end
local heard=contents('bridge.jsonl')
assert(heard:find('Close advice, button, ',1,true),heard)
assert(not heard:find('Overlay test',1,true),'Test buttons stay hidden')
fire('ShortcutTriggered',{string='script_F3'})
for n=1,4 do if contents('bridge.jsonl'):match('"text":"([^"]*)"}\n$'):find('Close advice',1,true)==1 then break end; fire('ShortcutTriggered',{string='script_F2'}) end
fire('ShortcutTriggered',{string='script_F4'}); assert(clicked=='tree.child4.child0','Close advice can be pressed')
-- 0.6.42: button_* containers in NewState are not listed; Accept is.
local make=start('campaign',nil,1)
local holder=make('tree.child4','button_set',1,'',true); nodes.tree.count=5
function holder:CurrentState() return 'NewState' end
make('tree.child4.child0','button_accept',0,'',true)
begin(); for n=1,12 do tick(1) end
for n=1,4 do fire('ShortcutTriggered',{string='script_F2'}) end
local heard=contents('bridge.jsonl')
assert(heard:find('Accept, button, ',1,true) and not heard:find('Set, button',1,true),heard)
-- 0.6.43: province rows are list items; buildings are named from the game's
-- text; starting a construction and abandoning ask first; a click re-reads.
local loc={building_culture_variants_name_wh2_main_hef_barracks_1='Militia Camp',
    building_culture_variants_name_wh2_main_special_settlement_lothern_2='Lothern (Elven Village)'}
effect={get_localised_string=function(key) return loc[key] or '' end}
local make
local function starts(value,prefix) return value:sub(1,#prefix)==prefix end
local function el(path,id,children,label,tip,state)
    local item=make(path,id,children,label or '',true)
    if tip then function item:GetTooltipText() return tip end end
    if state then function item:CurrentState() return state end end
    return item
end
local function go(name)
    for n=1,30 do
        local now=said() or ''
        if now:sub(1,#name)==name then return now end
        fire('ShortcutTriggered',{string='script_F2'})
    end
    error('Not found: ' .. name .. ' in ' .. contents('bridge.jsonl'):sub(-600))
end
local function count_updates() return select(2,contents('bridge.jsonl'):gsub('Screen updated%.','')) end
make=start('campaign',nil,1); nodes.tree.count=5
el('tree.child4','provinces',2)
el('tree.child4.child0','tx_list_title',0,'Your Provinces')
el('tree.child4.child1','list_box',1)
el('tree.child4.child1.child0','row_entry_wh2_main_vor_straits_of_lothern',5,'','Left-click to zoom to province','unselected')
el('tree.child4.child1.child0.child0','region_name',0,'Straits of Lothern','[[col:red]](Contested province)[[/col]]','contested')
el('tree.child4.child1.child0.child1','icon_public_order',0,'','Public Order: Neutral','neutral')
el('tree.child4.child1.child0.child2','income',1,'520','Income')
el('tree.child4.child1.child0.child2.child0','coin',0)
el('tree.child4.child1.child0.child3','mon',0,'','[[col:red]](Contested province)[[/col]]','contested')
el('tree.child4.child1.child0.child4','upgradable',1,'','Building upgrades available')
el('tree.child4.child1.child0.child4.child0','glow',0,'','Building upgrades available')
begin(); for n=1,12 do tick(1) end
assert(contents('bridge.jsonl'):find('Campaign map, 4 items.',1,true),contents('bridge.jsonl'))
assert(go('Your Provinces')=='Your Provinces, heading, 3 of 4',said())
local row=go('Straits of Lothern')
assert(row=='Straits of Lothern, list item, 520, Contested province, Public Order: Neutral, Building upgrades available, 4 of 4',row)
assert(not contents('bridge.jsonl'):find('Left-click to zoom',1,true),'Row hint and parts are folded into the row')
fire('ShortcutTriggered',{string='script_F4'})
assert(dispatches==1 and clicked=='tree.child4.child1.child0' and said()=='Straits of Lothern activated.',said())
-- The settlement panel opens as a new root panel: read from its title.
el('tree.child5','settlement_panel',2); nodes.tree.count=6
el('tree.child5.child0','header',1)
el('tree.child5.child0.child0','dy_txt',0,'Straits of Lothern')
el('tree.child5.child1','settlement',2)
el('tree.child5.child1.child0','settlement_capital',2,'','','player')
el('tree.child5.child1.child0.child0','building_slot_1',1,'','','NewState')
el('tree.child5.child1.child0.child0.child0','wh2_main_hef_barracks_1',1,'','','built_panel')
el('tree.child5.child1.child0.child0.child0.child0','units_list',1)
el('tree.child5.child1.child0.child0.child0.child0.child0','wh2_main_hef_inf_spearmen_0',0,'','Spearmen')
el('tree.child5.child1.child0.child1','building_slot_2',1,'','','NewState')
el('tree.child5.child1.child0.child1.child0','Slot2_Construction_Site',1,'','','normal')
el('tree.child5.child1.child0.child1.child0.child0','button_expand_slot',0,'','','locked')
el('tree.child5.child1.child1','button_zoom',1,'','','selected')
el('tree.child5.child1.child1.child0','dy_province',0,'Lothern','Zoom to province capital','owned')
for n=1,14 do tick(1) end
assert(count_updates()==1,contents('bridge.jsonl'):sub(-800))
assert(starts(said(),'Straits of Lothern, heading,'),said())
assert(go('Lothern, heading'),'Settlement name is a heading')
local barracks=go('Militia Camp')
assert(starts(barracks,'Militia Camp, button, Lothern') and barracks:sub(-15)=='Units: Spearmen',barracks)
local slot=go('Construction slot')
assert(starts(slot,'Construction slot, button, Lothern, locked, '),slot)
go('Militia Camp'); fire('ShortcutTriggered',{string='script_F4'})
assert(dispatches==2 and clicked=='tree.child5.child1.child0.child0.child0' and said()=='Militia Camp activated.','A built building opens its upgrade options')
-- Nothing changed after the click: the re-read stays quiet and keeps the place.
local before=contents('bridge.jsonl')
for n=1,10 do tick(1) end
assert(contents('bridge.jsonl')==before,'Unchanged re-read is quiet: ' .. contents('bridge.jsonl'):sub(#before+1))
assert(contents('native-ui-campaign-discovery.jsonl'):find('"kind":"refresh-unchanged"',1,true))
fire('ShortcutTriggered',{string='script_F2'}); assert(starts(said(),'Construction slot'),said())
-- Construction popup: upgrades with costs; building asks first; locked refuses.
make=start('campaign',nil,1); nodes.tree.count=5
el('tree.child4','construction_popup',2)
el('tree.child4.child0','slot_parent',3)
el('tree.child4.child0.child0','0',1)
el('tree.child4.child0.child0.child0','wh2_main_special_settlement_lothern_1',0,'','','built')
el('tree.child4.child0.child1','1',1)
el('tree.child4.child0.child1.child0','wh2_main_special_settlement_lothern_2',1,'','','normal')
el('tree.child4.child0.child1.child0.child0','dev_points',1)
el('tree.child4.child0.child1.child0.child0.child0','dy_num_points_required',0,'1','Population Surplus cost||This is the amount','normal')
el('tree.child4.child0.child2','2',1)
el('tree.child4.child0.child2.child0','wh2_main_special_settlement_lothern_3',1,'','','locked')
el('tree.child4.child0.child2.child0.child0','dev_points',1)
el('tree.child4.child0.child2.child0.child0.child0','dy_num_points_required',0,'2','Population Surplus cost||This is the amount','red')
el('tree.child4.child1','button_abandon',0,'','Click to abandon this settlement on the next turn.')
begin(); for n=1,12 do tick(1) end
local built=go('wh2 main special settlement lothern 1')
assert(starts(built,'wh2 main special settlement lothern 1, button, built,'),built)
local upgrade=go('Lothern (Elven Village)')
assert(starts(upgrade,'Lothern (Elven Village), button, Population surplus cost 1, '),upgrade)
fire('ShortcutTriggered',{string='script_F4'})
assert(dispatches==0 and said()=='Build Lothern (Elven Village)? Press Enter again to confirm.',said())
fire('ShortcutTriggered',{string='script_F4'})
assert(dispatches==1 and clicked=='tree.child4.child0.child1.child0' and said()=='Lothern (Elven Village) activated.',said())
local locked=go('wh2 main special settlement lothern 3')
assert(locked:find('locked, Population surplus cost 2, not enough',1,true),locked)
fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==1 and said():sub(-15)=='is unavailable.',said())
go('Click to abandon'); fire('ShortcutTriggered',{string='script_F4'})
assert(dispatches==1 and said():sub(-29)=='Press Enter again to confirm.',said())
-- Missing game text falls back to the building ID; no effect library at all is safe.
effect=nil
make=start('campaign',nil,1); nodes.tree.count=5
el('tree.child4','building_slot_1',1)
el('tree.child4.child0','wh2_main_hef_barracks_1',0,'','','built_panel')
begin(); for n=1,12 do tick(1) end
assert(go('wh2 main hef barracks 1, button'),'Fallback name')
assert(dispatches==0)
-- 0.6.44: buildings follow their settlement's name; minimap icons go last;
-- a popup opened by a click starts at its first building, not Abandon;
-- construction turns are read; recruit buttons ask first.
effect={get_localised_string=function(key) return loc[key] or '' end}
make=start('campaign',nil,1); nodes.tree.count=6
el('tree.child4','settlement_panel',2)
el('tree.child4.child0','settlement',2)
el('tree.child4.child0.child0','settlement_capital',1,'','','player')
el('tree.child4.child0.child0.child0','building_slot_1',1,'','','NewState')
el('tree.child4.child0.child0.child0.child0','wh2_main_special_settlement_lothern_2',1,'','','built_panel')
el('tree.child4.child0.child0.child0.child0.child0','turns_center',0,'3','Construction turns left||You are currently building this item.','construct')
el('tree.child4.child0.child1','button_zoom',1,'','','active')
el('tree.child4.child0.child1.child0','dy_province',0,'Lothern','Zoom to province capital','owned')
el('tree.child4.child1','info',1)
el('tree.child4.child1.child0','dy_txt',0,'Later text')
el('tree.child5','radar',1)
el('tree.child5.child0','main_icon',0,'','Settlement: Lothern')
el('tree.child0.child0','button_agents',0,'','Recruit Hero||Heroes can be embedded into armies')
begin(); for n=1,12 do tick(1) end
go('Lothern, heading'); fire('ShortcutTriggered',{string='script_F2'})
assert(starts(said(),'Lothern (Elven Village), button, Lothern, under construction, 3 turns left, '),said())
assert(starts(go('Settlement: Lothern'),'Settlement: Lothern, 7 of 7'),'Minimap icons are read last: ' .. said())
go('Recruit Hero'); fire('ShortcutTriggered',{string='script_F4'})
assert(dispatches==1 and said()=='Recruit Hero activated.','Opening the hero panel needs no confirmation')
-- A popup with Abandon and buildings: start at the first building.
el('tree.child6','construction_popup',2); nodes.tree.count=7
el('tree.child6.child0','button_abandon',0,'','Click to abandon this settlement on the next turn.')
el('tree.child6.child1','slot_parent',1)
el('tree.child6.child1.child0','1',1)
el('tree.child6.child1.child0.child0','wh2_main_hef_barracks_1',0,'','','normal')
for n=1,16 do tick(1) end
assert(said()=='Militia Camp, button, ' .. said():match('(%d+ of %d+)$'),contents('bridge.jsonl'):sub(-500))
-- 0.6.45: a lost timer event is recovered by the watchdog.
make=start('campaign',nil,1); begin(); for n=1,12 do tick(1) end
assert(contents('bridge.jsonl'):find('Campaign map, ',1,true))
pending=false -- the game dropped the reader's next timer event
local function fire_watchdog() assert(watchdog_pending,'Watchdog armed'); watchdog_pending=false; fire('RealTimeTrigger',{string='warhammer_campaign_readonly_watchdog'}) end
fire_watchdog(); assert(not pending,'First watchdog run only records the tick count')
fire_watchdog(); assert(pending,'Second run with no ticks re-arms the reader')
assert(contents('native-ui-campaign-discovery.jsonl'):find('"kind":"timer-rearmed"',1,true))
tick(1); fire_watchdog(); assert(watchdog_pending)
-- 0.6.46: the upgrade popup closes when the pointer is not over it, so its
-- options are read at the moment of the click and built in one step.
effect={get_localised_string=function(key) return loc[key] or '' end}
loc.building_culture_variants_name_wh2_main_special_settlement_lothern_1='Lothern (Elven Hamlet)'
make=start('campaign',nil,1); nodes.tree.count=5
el('tree.child4','settlement',2)
el('tree.child4.child0','settlement_capital',1,'','','player')
el('tree.child4.child0.child0','building_slot_1',1,'','','NewState')
local slot_building=el('tree.child4.child0.child0.child0','wh2_main_special_settlement_lothern_1',0,'','','built_panel')
el('tree.child4.child1','button_zoom',1,'','','active')
el('tree.child4.child1.child0','dy_province',0,'Lothern','Zoom to province capital','owned')
local built_key
local function open_popup()
    nodes.tree.count=6
    el('tree.child5','construction_popup',1)
    el('tree.child5.child0','list_holder',1)
    el('tree.child5.child0.child0','building_tree',1)
    el('tree.child5.child0.child0.child0','slot_parent',2)
    el('tree.child5.child0.child0.child0.child0','0',1)
    el('tree.child5.child0.child0.child0.child0.child0','wh2_main_special_settlement_lothern_1',0,'','','built')
    el('tree.child5.child0.child0.child0.child1','1',1)
    local upgrade=el('tree.child5.child0.child0.child0.child1.child0','wh2_main_special_settlement_lothern_2',1,'','','normal')
    el('tree.child5.child0.child0.child0.child1.child0.child0','dev_points',1)
    el('tree.child5.child0.child0.child0.child1.child0.child0.child0','dy_num_points_required',0,'1','Population Surplus cost||x','normal')
    function upgrade:SimulateLClick() dispatches=dispatches+1; built_key=self.id end
end
local function close_popup() nodes.tree.count=5 end -- the pointer is elsewhere
function slot_building:SimulateLClick() dispatches=dispatches+1; open_popup() end
begin(); for n=1,12 do tick(1) end
go('Lothern (Elven Hamlet)'); fire('ShortcutTriggered',{string='script_F4'}); close_popup()
local heard=contents('bridge.jsonl')
assert(heard:find('Upgrades for Lothern (Elven Hamlet), 2 options.',1,true),heard:sub(-400))
assert(said()=='Lothern (Elven Village), button, Population surplus cost 1, 2 of 3',said())
local quiet=contents('bridge.jsonl'); for n=1,12 do tick(1) end
assert(contents('bridge.jsonl')==quiet,'Re-reads behind the list stay quiet: '..contents('bridge.jsonl'):sub(#quiet+1))
fire('ShortcutTriggered',{string='script_F2'}); assert(said()=='Close upgrades, button, 3 of 3',said())
fire('ShortcutTriggered',{string='script_F2'}); assert(said()=='Lothern (Elven Hamlet), button, built, 1 of 3',said())
fire('ShortcutTriggered',{string='script_F4'}); assert(said()=='Lothern (Elven Hamlet) is unavailable.' and dispatches==1,said())
fire('ShortcutTriggered',{string='script_F2'}); fire('ShortcutTriggered',{string='script_F4'})
assert(said()=='Build Lothern (Elven Village)? Press Enter again to confirm.' and dispatches==1,said())
fire('ShortcutTriggered',{string='script_F4'}); close_popup()
assert(dispatches==3 and built_key=='wh2_main_special_settlement_lothern_2' and said()=='Building Lothern (Elven Village).',said())
-- Close upgrades returns to the reader without clicking.
go('Lothern (Elven Hamlet)'); fire('ShortcutTriggered',{string='script_F4'}); close_popup()
fire('ShortcutTriggered',{string='script_F2'}); assert(said()=='Close upgrades, button, 3 of 3',said())
fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==4,'Only the reopening click')
assert(contents('bridge.jsonl'):find('Upgrades closed.',1,true))
-- 0.6.48: when both timers stop, an ordinary game event restarts them.
make=start('campaign',nil,1); begin(); for n=1,12 do tick(1) end
pending=false; watchdog_pending=false
fire('PanelOpenedCampaign',{}); assert(not pending,'No restart while ticks are recent')
local real_clock=os.clock; os.clock=function() return real_clock()+60 end
fire('PanelOpenedCampaign',{}); os.clock=real_clock
assert(pending and watchdog_pending,'Both timers restarted')
assert(contents('native-ui-campaign-discovery.jsonl'):find('"source":"PanelOpenedCampaign"',1,true))
-- 0.6.49: Recruit Lord panel: lord types are tabs, candidates list items
-- with costs; an unavailable one says why; Recruit asks first.
make=start('campaign',nil,1); nodes.tree.count=5
el('tree.child4','character_panel',3)
el('tree.child4.child0','lord_parent',1)
el('tree.child4.child0.child0','list_box',2)
el('tree.child4.child0.child0.child0','legendary_lords',1,'','','selected')
el('tree.child4.child0.child0.child0.child0','label',0,'Legendary Lords')
el('tree.child4.child0.child0.child1','hef_prince',1,'','','active')
el('tree.child4.child0.child0.child1.child0','label',0,'Prince')
el('tree.child4.child1','candidates',2)
el('tree.child4.child1.child0','general_candidate_8_',3,'','Alastar the White Lion\nPrince\n\n[[col:red]]Cannot recruit Lord\n\nYou have insufficient influence.[[/col]]','inactive')
el('tree.child4.child1.child0.child0','dy_name',0,'Alastar the White Lion')
el('tree.child4.child1.child0.child1','dy_subtype',0,'Prince')
el('tree.child4.child1.child0.child2','IntrigueCost',1,'','Influence||This is the amount')
el('tree.child4.child1.child0.child2.child0','Cost',0,'30','','Normal')
el('tree.child4.child1.child1','general_candidate_1_',3,'','Imrik\nPrince','active')
el('tree.child4.child1.child1.child0','dy_name',0,'Imrik')
el('tree.child4.child1.child1.child1','RecruitmentCost',1,'','Cost||This amount')
el('tree.child4.child1.child1.child1.child0','Cost',0,'825','','Normal')
el('tree.child4.child1.child1.child2','UpkeepCost',1,'','Upkeep||This amount')
el('tree.child4.child1.child1.child2.child0','Upkeep',0,'300','','Normal')
local raise=el('tree.child4.child2','button_raise',0,'','','inactive')
function raise:IsInteractive() return true end
begin(); for n=1,12 do tick(1) end
assert(go('Legendary Lords')=='Legendary Lords, tab, selected, ' .. said():match('(%d+ of %d+)$'),said())
assert(starts(go('Prince, tab'),'Prince, tab, '),said())
local alastar=go('Alastar the White Lion')
assert(starts(alastar,'Alastar the White Lion, list item, Prince, unavailable, influence 30, ') and alastar:sub(-58)=='Cannot recruit Lord. You have insufficient influence.' or alastar:find('Cannot recruit Lord. You have insufficient influence.',1,true),alastar)
fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==0 and said()=='Alastar the White Lion is unavailable.',said())
local imrik=go('Imrik')
assert(starts(imrik,'Imrik, list item, cost 825, upkeep 300, '),imrik)
assert(not contents('bridge.jsonl'):find('Upkeep, ',1,true),'Cost labels are folded in')
fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==1 and said()=='Imrik activated.',said())
assert(starts(go('Recruit, button'),'Recruit, button, '),said())
fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==1 and said()=='Recruit is unavailable.',said())
function raise:CurrentState() return 'active' end
fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==1 and said()=='Recruit? Press Enter again to confirm.',said())
fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==2 and said()=='Recruit activated.',said())
-- 0.6.52: Lords & Heroes rows and the army panel.
make=start('campaign',nil,1); nodes.tree.count=5
el('tree.child4','units_dropdown',1)
el('tree.child4.child0','list_box',1)
el('tree.child4.child0.child0','character_row_1',2,'','Left-click to zoom to this character.','unselected')
el('tree.child4.child0.child0.child0','indent_parent',5)
el('tree.child4.child0.child0.child0.child0','soldiers',0,'116')
el('tree.child4.child0.child0.child0.child1','dy_character_name',0,'Tyrion','','normal')
el('tree.child4.child0.child0.child0.child2','faction_leader',0,'','','leader')
el('tree.child4.child0.child0.child0.child3','forces_icon',0,'','Legendary Lord','army')
el('tree.child4.child0.child0.child0.child4','dy_rank',0,'1')
el('tree.child4.child0.child0.child1','action_points',0)
begin(); for n=1,12 do tick(1) end
local tyrion=go('Tyrion')
assert(starts(tyrion,'Tyrion, list item, Legendary Lord, ') and tyrion:find('faction leader',1,true) and tyrion:find('rank 1',1,true) and tyrion:find('116 soldiers',1,true),tyrion)
assert(not contents('bridge.jsonl'):find('Left-click to zoom to this character',1,true),'Row hint folded in')
fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==1 and said()=='Tyrion activated.',said())
-- The army panel opens: the lord's name is a heading; unit cards are read only.
el('tree.child5','units_panel',1); nodes.tree.count=6
el('tree.child5.child0','main_units_panel',2)
el('tree.child5.child0.child1','button_focus',1,'','Zoom to current selection')
el('tree.child5.child0.child1.child0','dy_txt',0,'Tyrion')
el('tree.child5.child0.child0','units',2)
el('tree.child5.child0.child0.child0','LandUnit 0',2,'','Tyrion\nLegendary Lord||Left-click to select\nRight-click for further information','active')
el('tree.child5.child0.child0.child0.child0','unit_category_icon',0,'','Sword Infantry')
el('tree.child5.child0.child0.child0.child1','unit_strength_number',0,'1','','1')
el('tree.child5.child0.child0.child1','LandUnit 1',3,'','Spearmen||Left-click to select\nRight-click for further information','active')
el('tree.child5.child0.child0.child1.child0','unit_category_icon',0,'','Spear Infantry')
el('tree.child5.child0.child0.child1.child1','unit_strength_number',0,'30','','1')
el('tree.child5.child0.child0.child1.child2','experience',0,'','','2')
for n=1,14 do tick(1) end
assert(starts(said(),'Tyrion, heading, '),said())
assert(starts(go('Tyrion Legendary Lord, list item'),'Tyrion Legendary Lord, list item, Sword Infantry, strength 1, '),said())
go('Tyrion, heading'); fire('ShortcutTriggered',{string='script_F2'})
assert(starts(said(),'Tyrion Legendary Lord, list item'),'Units follow the army heading: '..said())
local spear=go('Spearmen')
assert(starts(spear,'Spearmen, list item, Spear Infantry, strength 30, rank 2, '),spear)
assert(not contents('bridge.jsonl'):find('Right-click for further information',1,true),'Card hint dropped')
fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==1 and said()=='Not supported yet.','Unit cards are read only')
-- 0.6.57: with a repeating game timer, it is registered once and never from
-- inside a timer callback; the slow work still runs once a second.
make=start('campaign',nil,1)
local registrations,repeat_name={},nil
real_timer.register_singleshot=function(name,delay) registrations[#registrations+1]='single:' .. name end
real_timer.register_repeating=function(name,delay) registrations[#registrations+1]='repeat:' .. name .. ':' .. delay end
begin()
assert(#registrations==2 and registrations[1]=='repeat:warhammer_campaign_readonly_tick:100'
    and registrations[2]=='repeat:warhammer_campaign_readonly_watchdog:3000',table.concat(registrations,' '))
assert(contents('native-ui-campaign-discovery.jsonl'):find('"timer":"repeating"',1,true))
for n=1,150 do fire('RealTimeTrigger',{string=timer}) end
assert(#registrations==2,'Nothing registered from inside a callback: ' .. table.concat(registrations,' '))
assert(contents('bridge.jsonl'):find('Campaign map, ',1,true),'Slow work ran on the 100 ms timer')
fire('ShortcutTriggered',{string='script_shift_F2'}); fire('ShortcutTriggered',{string='script_shift_F2'})
assert(#registrations==2,'Reading mode does not re-register')
-- 0.6.59: document order (titles first); settlement figures, unit stats and the
-- tax check box are one item each; a button's own label is not a second item;
-- arrival starts at the top-most panel's title. IDs from the 0.6.48/0.6.49 captures.
make=start('campaign',nil,1); nodes.tree.count=7
el('tree.child4','settlement_panel',3)
el('tree.child4.child0','frame_growth',4)
el('tree.child4.child0.child0','header_frame',0,'[[url:script_link_campaign_growth]]Growth[[/url]]','Once growth reaches a threshold, surplus is created.||Left-click to open Help pages.')
el('tree.child4.child0.child1','growth_parent',1)
el('tree.child4.child0.child1.child0','tx_growth',0,'Growth:')
el('tree.child4.child0.child2','dy_growth',0,'0/600 [[col:dark_g]](+20)[[/col]]')
el('tree.child4.child0.child3','tx_turns',1,'Turns until surplus point:')
el('tree.child4.child0.child3.child0','dy_turns',0,'30')
el('tree.child4.child1','frame_PO_income',3)
el('tree.child4.child1.child0','header_taxes',1,'','','taxes')
el('tree.child4.child1.child0.child0','checkbox_tax_exempt',1,'','','selected')
el('tree.child4.child1.child0.child0.child0','label_txt',0,'[[url:script_link_campaign_tax]]Tax Province[[/url]]','Taxing a province gives more income.||Left-click to open Help pages.')
el('tree.child4.child1.child1','wealth_holder',3)
el('tree.child4.child1.child1.child0','tx_wealth',0,'Income')
el('tree.child4.child1.child1.child1','coin',0,'','This is the amount of income this province generates every turn.')
el('tree.child4.child1.child1.child2','dy_wealth',0,'520')
el('tree.child4.child1.child2','public_order_holder',1)
el('tree.child4.child1.child2.child0','public_order',2,'Public order')
el('tree.child4.child1.child2.child0.child0','total',0,'0 [[col:dark_r]](-1)[[/col]]')
el('tree.child4.child1.child2.child0.child1','icon_public_order',0,'','Neutral||The population are neither unhappy nor under control.','neutral')
el('tree.child4.child2','frame_corruption',1)
el('tree.child4.child2.child0','corruption_docker',1)
el('tree.child4.child2.child0.child0','wh_main_religion_untainted',0,'100%')
el('tree.child5','regions_dropdown',1)
el('tree.child5.child0','player_provinces',3)
el('tree.child5.child0.child0','headers',1)
el('tree.child5.child0.child0.child0','sort_name',0,'','Sort by name','active')
el('tree.child5.child0.child1','list_box',1)
el('tree.child5.child0.child1.child0','row_entry_wh2_main_vor_straits_of_lothern',1)
el('tree.child5.child0.child1.child0.child0','region_name',0,'Straits of Lothern')
el('tree.child5.child0.child2','tx_list_title',0,'Your Provinces')
el('tree.child6','character_panel',3)
el('tree.child6.child0','raise_forces_options',1)
el('tree.child6.child0.child0','button_raise',2,'','Raise army||The selected Lord will lead the new army.','active')
el('tree.child6.child0.child0.child0','button_txt',0,'','','active')
el('tree.child6.child0.child0.child1','dy_txt',0,'Recruit','','active')
el('tree.child6.child1','details',2)
el('tree.child6.child1.child0','dynamic_stats',2)
el('tree.child6.child1.child0.child0','stat1',2,'','How resistant a unit is to missile fire and melee attacks.')
el('tree.child6.child1.child0.child0.child0','dy_value',1,'80')
el('tree.child6.child1.child0.child0.child0.child0','mod_icon_list',1)
el('tree.child6.child1.child0.child0.child0.child0.child0','shield2',0,'','Shielded||This unit has a shield.','active')
el('tree.child6.child1.child0.child0.child1','stat_name',0,' Armour')
el('tree.child6.child1.child0.child1','stat2',2,'','This is how fast a unit moves.')
el('tree.child6.child1.child0.child1.child0','dy_value',0,'36')
el('tree.child6.child1.child0.child1.child1','stat_name',0,' Speed')
el('tree.child6.child1.child1','attribute_1',0,'Armoured & Shielded','Armoured units can block damage from any source apart from Armour-Piercing damage.')
el('tree.child6.child2','title_plaque',1)
el('tree.child6.child2.child0','tx_recruit',0,'Recruit Lord','','recruit_general')
begin(); for n=1,20 do tick(1) end
local heard=contents('bridge.jsonl')
assert(heard:find('Campaign map, ',1,true),heard)
assert(starts(said(),'Recruit Lord, heading, '),'Arrival starts at the top-most panel title: ' .. said())
fire('ShortcutTriggered',{string='script_F2'})
assert(starts(said(),'Recruit, button, ') and said():find('Raise army. The selected Lord will lead the new army.',1,true),said())
fire('ShortcutTriggered',{string='script_F2'})
assert(starts(said(),'Armour, 80, Shielded, ') and said():find('How resistant a unit is',1,true),said())
fire('ShortcutTriggered',{string='script_F2'}); assert(starts(said(),'Speed, 36, '),said())
fire('ShortcutTriggered',{string='script_F2'})
assert(starts(said(),'Armoured & Shielded, ') and said():find('Armoured units can block',1,true),said())
local growth=go('Growth, heading')
assert(growth:find('Once growth reaches a threshold, surplus is created.',1,true),growth)
fire('ShortcutTriggered',{string='script_F2'}); assert(starts(said(),'Growth, 0/600 (+20), '),said())
fire('ShortcutTriggered',{string='script_F2'}); assert(starts(said(),'Turns until surplus point, 30, '),said())
fire('ShortcutTriggered',{string='script_F2'})
assert(starts(said(),'Tax Province, check box, checked, ') and said():find('Taxing a province gives more income.',1,true),said())
fire('ShortcutTriggered',{string='script_F4'}); assert(dispatches==0 and said()=='Not supported yet.','The tax check box is read only')
fire('ShortcutTriggered',{string='script_F2'}); assert(starts(said(),'Income, 520, '),said())
fire('ShortcutTriggered',{string='script_F2'}); assert(starts(said(),'Public order, 0 (-1), Neutral, '),said())
fire('ShortcutTriggered',{string='script_F2'}); assert(starts(said(),'Untainted, 100%, '),said())
fire('ShortcutTriggered',{string='script_F2'}); assert(starts(said(),'Your Provinces, heading, '),'List title before its rows: ' .. said())
fire('ShortcutTriggered',{string='script_F2'}); assert(starts(said(),'Sort by name, button, '),said())
fire('ShortcutTriggered',{string='script_F2'}); assert(starts(said(),'Straits of Lothern, list item, '),said())
heard=contents('bridge.jsonl')
for _,unwanted in ipairs({'Txt, button','"text":"Recruit, %d','Growth:','Left%-click to open Help pages','"text":"80,','"text":"36,'}) do
    assert(not heard:find(unwanted),'Not read separately: ' .. unwanted)
end
-- 0.6.67: F6 switches between a lord and his settlement through the game's own
-- lists, Shift+F6 cycles lords, F7 lists places to move to; a confirmed move is
-- the game's own move order. Enemies are listed but not attacked.
do
    local make=start('campaign',nil,3)
    nodes['tree.child0'].count=5
    make('tree.child0.child3','radar_things',1)
    make('tree.child0.child3.child0','dropdown_parent',2)
    make('tree.child0.child3.child0.child0','units_dropdown',1)
    local units_panel=make('tree.child0.child3.child0.child0.child0','panel',1,'',false)
    make('tree.child0.child3.child0.child0.child0.child0','list_box',2)
    make('tree.child0.child3.child0.child0.child0.child0.child0','character_row_0',1)
    make('tree.child0.child3.child0.child0.child0.child0.child0.child0','indent_parent',1)
    make('tree.child0.child3.child0.child0.child0.child0.child0.child0.child0','dy_character_name',0,'Tyrion')
    make('tree.child0.child3.child0.child0.child0.child0.child1','character_row_1',1)
    make('tree.child0.child3.child0.child0.child0.child0.child1.child0','indent_parent',1)
    make('tree.child0.child3.child0.child0.child0.child0.child1.child0.child0','dy_character_name',0,'Cavill')
    make('tree.child0.child3.child0.child1','regions_dropdown',1)
    local regions_panel=make('tree.child0.child3.child0.child1.child0','panel',1,'',false)
    -- As in the game: the outer list holds sections; rows are inside them.
    make('tree.child0.child3.child0.child1.child0.child0','list_box',1)
    make('tree.child0.child3.child0.child1.child0.child0.child0','section',2)
    make('tree.child0.child3.child0.child1.child0.child0.child0.child0','headers',0)
    make('tree.child0.child3.child0.child1.child0.child0.child0.child1','list_box',2)
    make('tree.child0.child3.child0.child1.child0.child0.child0.child1.child0','row_entry_prov_eataine',0)
    make('tree.child0.child3.child0.child1.child0.child0.child0.child1.child1','row_entry_prov_tiranoc',0)
    make('tree.child0.child4','bar_small_top',1)
    make('tree.child0.child4.child0','tabs',2)
    local tab_units=make('tree.child0.child4.child0.child0','tab_units',0)
    local tab_regions=make('tree.child0.child4.child0.child1','tab_regions',0)
    function tab_units:SimulateLClick() dispatches=dispatches+1; clicked=self.path; units_panel.visible=true; regions_panel.visible=false end
    function tab_regions:SimulateLClick() dispatches=dispatches+1; clicked=self.path; regions_panel.visible=true; units_panel.visible=false end
    local function list(items) return {num_items=function() return #items end,item_at=function(_,i) return items[i+1] end} end
    local names={names_tyrion='Tyrion',names_cavill='Cavill',regions_onscreen_lothern='Lothern',regions_onscreen_tor_elasor='Tor Elasor',
        regions_onscreen_vauls_anvil="Vaul's Anvil",regions_onscreen_far='Far Away',provinces_onscreen_prov_eataine='Eataine',
        provinces_onscreen_prov_tiranoc='Tiranoc',factions_screen_name_def='Har Ganeth',factions_screen_name_neutral='Ellyrion'}
    effect={get_localised_string=function(key) return names[key] or '' end}
    local hef,def,neutral={},{},{}
    function hef:name() return 'hef' end; function def:name() return 'def' end; function neutral:name() return 'neutral' end
    local function region(key,province,owner,x,y)
        local settlement={x=x,y=y}
        function settlement:logical_position_x() return self.x end; function settlement:logical_position_y() return self.y end
        return {name=function() return key end,province_name=function() return province end,settlement=function() return settlement end,
            is_abandoned=function() return false end,owning_faction=function() return owner end,s=settlement}
    end
    local lothern=region('lothern','prov_eataine',hef,100,100)
    local tor=region('tor_elasor','prov_tiranoc',hef,110,100)
    local vaul=region('vauls_anvil','prov_tiranoc',def,100,112)
    local far=region('far','prov_far',neutral,200,200)
    local reach={[tor.s]=true,[vaul.s]=true}
    local function lord(cqi,key,x,y,leader)
        local char={x=x,y=y,ap=100,region_now=lothern}
        function char:cqi() return cqi end; function char:get_forename() return key end; function char:get_surname() return '' end
        function char:character_type(t) return t=='general' end; function char:has_military_force() return true end
        function char:military_force() return {is_armed_citizenry=function() return false end,unit_list=function() return list({1,2,3,4,5,6,7}) end} end
        function char:logical_position_x() return self.x end; function char:logical_position_y() return self.y end
        function char:action_points_remaining_percent() return self.ap end
        function char:in_settlement() return self.x==100 and self.y==100 end
        function char:has_region() return true end; function char:region() return self.region_now end
        function char:faction() return hef end
        return char
    end
    local tyrion,cavill=lord(5,'names_tyrion',100,100),lord(9,'names_cavill',130,100)
    function hef:character_list() return list({cavill,tyrion}) end
    function hef:faction_leader() return tyrion end
    function hef:region_list() return list({lothern,tor}) end
    function hef:at_war_with(other) return other==def end
    local orders,multiplayer={},false
    local model={world=function() return {region_manager=function() return {region_list=function() return list({far,vaul,tor,lothern}) end} end} end,
        character_can_reach_settlement=function(_,char,settlement) return reach[settlement]==true end}
    cm={is_multiplayer=function() return multiplayer end,get_local_faction=function() return hef end,is_local_players_turn=function() return true end,
        get_local_faction_name=function() return 'hef' end,
        model=function() return model end,get_character_by_cqi=function(_,cqi) return cqi==5 and tyrion or cavill end,
        move_to=function(_,lookup,x,y,queue) orders[#orders+1]={lookup,x,y,queue} end}
    begin(); for n=1,12 do tick(1) end
    local session=contents('reader-state.tsv'):match('^WH2READER1\t([^\t]+)\t')
    assert(session and contents('reader-state.tsv'):find('\t1\tcampaign\n',1,true),'Player HUD reading is on')
    local seq=0
    local function send(...)
        local lines={'WH2KEYS1\tcompanion\t' .. session .. '\t1'}
        for _,action in ipairs({...}) do seq=seq+1; lines[#lines+1]=seq .. '\t' .. action end
        files[prefix .. 'keys.tsv']=table.concat(lines,'\n') .. '\n'
        tick(1)
    end
    send('noop') -- announces the companion; its backlog is skipped
    local function said() return (contents('bridge.jsonl'):match('"text":"([^"]*)"}\n$')) end
    local function heard(text) return contents('bridge.jsonl'):find('"text":"' .. text .. '"',1,true)~=nil end
    send('moves'); assert(said()=='Select a lord first: press F6.',said())
    local before=dispatches
    send('lords')
    assert(dispatches==before+2 and clicked=='tree.child0.child3.child0.child0.child0.child0.child0','Opens the Lords list, then clicks the faction leader: ' .. tostring(clicked))
    assert(heard('Tyrion, 7 units, 100 percent movement.'),contents('bridge.jsonl'))
    send('moves')
    assert(heard('Move Tyrion, 100 percent movement, 2 of 3 places this turn.'),contents('bridge.jsonl'))
    assert(said()=='Tor Elasor, button, yours, this turn, 1 of 4',said())
    send('next'); assert(said()=="Vaul's Anvil, button, Har Ganeth, at war, this turn, 2 of 4",said())
    send('activate'); assert(said()=="Attack Vaul's Anvil with Tyrion? Press Enter again to confirm." and #orders==0,said())
    send('next'); assert(said()=='Far Away, button, Ellyrion, more than a turn, 3 of 4',said())
    send('next'); assert(said()=='Close, button, 4 of 4',said())
    send('back'); assert(said()=='Move list closed.' or heard('Move list closed.'),said())
    send('moves','activate'); assert(said()=='Move Tyrion to Tor Elasor? Press Enter again to confirm.' and #orders==0,said())
    send('activate')
    assert(#orders==1 and orders[1][1]=='character_cqi:5' and orders[1][2]==110 and orders[1][3]==100 and orders[1][4]==true,'The game move order')
    assert(said()=='Moving to Tor Elasor.',said())
    assert(contents('native-ui-campaign-discovery.jsonl'):find('"kind":"move-order"',1,true))
    tyrion.x=105; tick(1); tyrion.x=110; tyrion.region_now=tor; tyrion.ap=40; tick(3)
    assert(heard('Tyrion arrived at Tor Elasor.'),contents('bridge.jsonl'))
    -- From the lord to the settlement he stands in.
    before=dispatches; send('lords')
    assert(dispatches==before+2 and clicked=='tree.child0.child3.child0.child1.child0.child0.child0.child1.child1','Opens Provinces, then clicks Tiranoc: ' .. tostring(clicked))
    assert(heard('Tor Elasor, Tiranoc.'),contents('bridge.jsonl'))
    -- From a settlement back to the nearest lord (list already open: one click).
    fire('SettlementSelected',{garrison_residence=function() return {region=function() return lothern end} end})
    tyrion.x,tyrion.y=150,150; units_panel.visible=true; regions_panel.visible=false
    before=dispatches; send('lords')
    assert(dispatches==before+1 and clicked=='tree.child0.child3.child0.child0.child0.child0.child1','Nearest lord to Lothern is Cavill: ' .. tostring(clicked))
    send('nextlord'); assert(clicked=='tree.child0.child3.child0.child0.child0.child0.child0','Shift+F6 goes to the next lord')
    -- A lord missing from the list, a stray move order and multiplayer.
    names.names_tyrion='Somebody'; send('nextlord'); send('nextlord')
    assert(heard('Could not find Somebody in the Lords list.'),contents('bridge.jsonl'))
    tyrion.ap=0; fire('CharacterSelected',{character=function() return tyrion end})
    send('moves'); assert(heard('Move Somebody, no movement left, 0 of 4 places this turn.'),contents('bridge.jsonl'))
    send('back')
    multiplayer=true; send('lords'); assert(said()=='Not available in multiplayer.',said())
    send('moves'); assert(said()=='Not available in multiplayer.' and #orders==1,said())
    -- Your own settlement: the game's join-garrison command when it has one;
    -- an army that does not start moving gets one retry just outside the spot.
    multiplayer=false; names.names_tyrion='Tyrion'; tyrion.ap=100; tyrion.x,tyrion.y=120,100
    cm.game_interface={join_garrison=function() end}
    cm.join_garrison=function(_,lookup,key) orders[#orders+1]={'join',lookup,key} end
    fire('CharacterSelected',{character=function() return tyrion end})
    send('moves','letter:l'); assert(said()=='Lothern, button, yours, more than a turn, 3 of 5',said())
    send('activate','activate')
    assert(#orders==2 and orders[2][1]=='join' and orders[2][2]=='character_cqi:5' and orders[2][3]=='settlement:lothern','Join garrison order')
    assert(said()=='Moving toward Lothern.',said())
    tick(4); assert(#orders==3 and orders[3][1]=='character_cqi:5' and orders[3][2]==102 and orders[3][3]==100,'Retry next to the settlement')
    assert(contents('native-ui-campaign-discovery.jsonl'):find('"target":"102,100"',1,true))
    tick(7); assert(heard('Tyrion did not move.'),contents('bridge.jsonl'))
    -- A failing game read is said plainly.
    cm.get_local_faction=function() error('Synthetic failure') end
    send('lords'); assert(said()=='Not available here.',said())
    cm.get_local_faction=function() return hef end
    -- An error inside a command is logged and said, and the reader keeps working.
    local sort=table.sort
    table.sort=function(t,f) if t[1] and t[1].cqi then error('Synthetic command failure') end; return sort(t,f) end
    send('lords'); table.sort=sort
    assert(said()=='Could not do that.' and contents('native-ui-campaign-discovery.jsonl'):find('"kind":"command-error"',1,true),said())
    local list_before=contents('bridge.jsonl'); send('next'); assert(contents('bridge.jsonl')~=list_before,'Reader still answers keys')
    -- Two rows with the lord's name: refuse rather than pick the wrong one.
    units_panel.visible=true; regions_panel.visible=false
    nodes['tree.child0.child3.child0.child0.child0.child0.child1.child0.child0'].label='Tyrion'
    local selected_before=dispatches
    fire('CharacterSelected',{character=function() return cavill end})
    send('nextlord')
    assert(dispatches==selected_before and said()=='More than one lord is called Tyrion. Choose him in the Lords & Heroes list.',said())
    nodes['tree.child0.child3.child0.child0.child0.child0.child1.child0.child0'].label='Cavill'
    -- After a settlement is selected (e.g. the lord joined its garrison), F7
    -- still lists moves for the last lord selected; F4 works in the list too.
    tyrion.ap=100; tyrion.x,tyrion.y=120,100
    fire('CharacterSelected',{character=function() return tyrion end})
    -- An enemy army selected next does not replace him as the F7 fallback.
    local enemy={}
    function enemy:cqi() return 77 end; function enemy:faction() return def end
    function enemy:character_type() return true end; function enemy:has_military_force() return true end
    fire('CharacterSelected',{character=function() return enemy end})
    fire('SettlementSelected',{garrison_residence=function() return {region=function() return lothern end} end})
    send('moves'); assert(heard('Move Tyrion, 100 percent movement, 2 of 4 places this turn.'),contents('bridge.jsonl'))
    fire('ShortcutTriggered',{string='script_F4'}); assert(said()=='Move Tyrion to Tor Elasor? Press Enter again to confirm.',said())
    send('back')
    -- 0.6.74 attacks (owner, Nov 3): the nearest enemy army is listed; Enter
    -- asks, the second Enter gives the game's own attack order.
    local raider=lord(31,'names_raider',125,100)
    function raider:faction() return def end
    function raider:in_settlement() return false end
    names.names_raider='Malus'
    function hef:factions_at_war_with() return list({def}) end
    function def:character_list() return list({raider}) end
    model.character_can_reach_character=function(_,a,b) return b==raider end
    cm.get_character_by_cqi=function(_,cqi) if cqi==5 then return tyrion elseif cqi==31 then return raider end; return cavill end
    fire('CharacterSelected',{character=function() return tyrion end})
    local count=#orders
    send('moves'); assert(heard('Move Tyrion, 100 percent movement, 3 of 5 places this turn.'),contents('bridge.jsonl'))
    send('letter:m'); assert(said()=="Malus's army, button, Har Ganeth, at war, 7 units, this turn, 3 of 6",said())
    -- Without the game's attack command: said, no order.
    send('activate'); assert(said()=="Attack Malus's army with Tyrion? Press Enter again to confirm.",said())
    send('activate'); assert(said()=='Attacking is not available here.' and #orders==count,said())
    cm.game_interface={join_garrison=function() end,attack=function() end,attack_region=function() end}
    cm.attack=function(_,a,d,q) orders[#orders+1]={'attack',a,d,q} end
    cm.attack_region=function(_,a,r,q) orders[#orders+1]={'attack_region',a,r,q} end
    send('moves','letter:m','activate','activate')
    local o=orders[#orders]
    assert(#orders==count+1 and o[1]=='attack' and o[2]=='character_cqi:5' and o[3]=='character_cqi:31' and o[4]==true,'The game attack order')
    assert(said()=="Attacking Malus's army.",said())
    tyrion.x=124; tick(1); tick(3)
    assert(not heard("Tyrion arrived at Malus's army.") and not heard("Tyrion stopped on the way to Malus's army."),'The battle screen is read instead')
    -- A settlement at war: attack_region.
    tyrion.x=120
    send('moves','letter:v'); assert(said()=="Vaul's Anvil, button, Har Ganeth, at war, this turn, 2 of 6",said())
    send('activate','activate')
    o=orders[#orders]
    assert(o[1]=='attack_region' and o[2]=='character_cqi:5' and o[3]=='vauls_anvil' and o[4]==true,'The game attack_region order')
    assert(said()=="Attacking Vaul's Anvil.",said())
    -- Short of the target: said where he stopped.
    tyrion.x=115; tick(1); tick(3)
    assert(heard("Tyrion stopped on the way to Vaul's Anvil, 100 percent movement left."),contents('bridge.jsonl'))
    -- A neutral settlement is a move, never an attack.
    send('moves','letter:f','activate'); assert(said()=='Move Tyrion to Far Away? Press Enter again to confirm.',said())
    send('back')
end
-- With the game's timer: one repeating game callback, registered at the first
-- tick (never from inside a timer callback), runs the queued model jobs; the
-- reader's timer only queues them and does the UI clicks.
do
    local make=start('campaign',nil,3)
    nodes['tree.child0'].count=5
    make('tree.child0.child3','radar_things',1)
    make('tree.child0.child3.child0','dropdown_parent',1)
    make('tree.child0.child3.child0.child0','units_dropdown',1)
    local units_panel=make('tree.child0.child3.child0.child0.child0','panel',1,'',false)
    make('tree.child0.child3.child0.child0.child0.child0','list_box',1)
    make('tree.child0.child3.child0.child0.child0.child0.child0','character_row_0',1)
    make('tree.child0.child3.child0.child0.child0.child0.child0.child0','dy_character_name',0,'Tyrion')
    make('tree.child0.child4','bar_small_top',1)
    local tab_units=make('tree.child0.child4.child0','tab_units',0)
    function tab_units:SimulateLClick() dispatches=dispatches+1; clicked=self.path; units_panel.visible=true end
    local function list(items) return {num_items=function() return #items end,item_at=function(_,i) return items[i+1] end} end
    local names={names_tyrion='Tyrion',regions_onscreen_lothern='Lothern'}
    effect={get_localised_string=function(key) return names[key] or '' end}
    local hef={}; function hef:name() return 'hef' end
    local settlement={}; function settlement:logical_position_x() return 100 end; function settlement:logical_position_y() return 100 end
    local lothern={name=function() return 'lothern' end,province_name=function() return 'prov_eataine' end,settlement=function() return settlement end,
        is_abandoned=function() return false end,owning_faction=function() return hef end}
    local tyrion={x=110,y=100}
    function tyrion:cqi() return 5 end; function tyrion:get_forename() return 'names_tyrion' end; function tyrion:get_surname() return '' end
    function tyrion:character_type(t) return t=='general' end; function tyrion:has_military_force() return true end
    function tyrion:military_force() return {is_armed_citizenry=function() return false end,unit_list=function() return list({1,2}) end} end
    function tyrion:logical_position_x() return self.x end; function tyrion:logical_position_y() return self.y end
    function tyrion:action_points_remaining_percent() return 100 end; function tyrion:in_settlement() return false end
    function hef:character_list() return list({tyrion}) end; function hef:faction_leader() return tyrion end
    function hef:region_list() return list({lothern}) end; function hef:at_war_with() return false end
    local orders,pump,interval={}
    cm={is_multiplayer=function() return false end,get_local_faction=function() return hef end,is_local_players_turn=function() return true end,
        model=function() return {world=function() return {region_manager=function() return {region_list=function() return list({lothern}) end} end} end,
            character_can_reach_settlement=function() return true end} end,
        get_character_by_cqi=function() return tyrion end,game_interface={join_garrison=function() end},
        join_garrison=function(_,lookup,key) orders[#orders+1]={lookup,key} end,
        callback=function() error('No game timer may be registered from inside a timer callback') end,
        repeat_callback=function(_,fn,t,name) assert(not pump,'One repeating game timer'); pump,interval=fn,t end}
    begin(); for n=1,12 do tick(1) end
    assert(pump and interval==0.2 and contents('native-ui-campaign-discovery.jsonl'):find('"kind":"model-pump","on":true',1,true))
    local session=contents('reader-state.tsv'):match('^WH2READER1\t([^\t]+)\t')
    local seq=0
    local function send(...)
        local lines={'WH2KEYS1\tcompanion\t' .. session .. '\t1'}
        for _,action in ipairs({...}) do seq=seq+1; lines[#lines+1]=seq .. '\t' .. action end
        files[prefix .. 'keys.tsv']=table.concat(lines,'\n') .. '\n'
        tick(1)
    end
    send('noop')
    local function said() return (contents('bridge.jsonl'):match('"text":"([^"]*)"}\n$')) end
    local function heard(text) return contents('bridge.jsonl'):find('"text":"' .. text .. '"',1,true)~=nil end
    send('lords'); assert(dispatches==0,'F6 waits for the game timer')
    pump(); tick(1)
    assert(dispatches==2 and clicked=='tree.child0.child3.child0.child0.child0.child0.child0','Then opens the list and clicks the lord')
    assert(heard('Tyrion, 2 units, 100 percent movement.'),contents('bridge.jsonl'))
    send('moves'); pump(); assert(said()=='Lothern, button, yours, this turn, 1 of 2',said())
    send('activate'); assert(said()=='Move Tyrion to Lothern? Press Enter again to confirm.',said())
    send('activate'); assert(#orders==0,'The order waits for the game timer')
    pump(); assert(#orders==1 and orders[1][1]=='character_cqi:5' and orders[1][2]=='settlement:lothern' and said()=='Moving to Lothern.',said())
    tyrion.x=100; for n=1,4 do tick(1); pump() end
    assert(heard('Tyrion arrived at Lothern.'),contents('bridge.jsonl'))
    -- A game timer that stops: queued jobs are dropped after 3 s, said once.
    send('moves'); tick(4)
    assert(said()=='The game is busy. Try again.' and contents('native-ui-campaign-discovery.jsonl'):find('"kind":"model-stalled"',1,true),said())
    pump(); assert(said()=='The game is busy. Try again.','Dropped jobs do not run later')
    -- A full queue (16 jobs) says so instead of dropping the key silently.
    send('moves','moves','moves','moves','moves','moves','moves','moves')
    send('moves','moves','moves','moves','moves','moves','moves','moves')
    local busy=select(2,contents('bridge.jsonl'):gsub('The game is busy%. Try again%.',''))
    send('moves')
    assert(select(2,contents('bridge.jsonl'):gsub('The game is busy%. Try again%.',''))==busy+1,'Seventeenth job: busy')
end
-- Rows inside sections: lords in a "Lords" section next to "Heroes", and a
-- province beyond the 64th row (find_named looks at 64 children only).
do
    local make=start('campaign',nil,3)
    nodes['tree.child0'].count=5
    make('tree.child0.child3','radar_things',1)
    make('tree.child0.child3.child0','dropdown_parent',2)
    make('tree.child0.child3.child0.child0','units_dropdown',1)
    local units_panel=make('tree.child0.child3.child0.child0.child0','panel',1,'',false)
    make('tree.child0.child3.child0.child0.child0.child0','list_box',2)
    make('tree.child0.child3.child0.child0.child0.child0.child0','section_lords',2)
    make('tree.child0.child3.child0.child0.child0.child0.child0.child0','headers',0)
    make('tree.child0.child3.child0.child0.child0.child0.child0.child1','list_box',1)
    make('tree.child0.child3.child0.child0.child0.child0.child0.child1.child0','character_row_0',1)
    make('tree.child0.child3.child0.child0.child0.child0.child0.child1.child0.child0','dy_character_name',0,'Tyrion')
    make('tree.child0.child3.child0.child0.child0.child0.child1','section_heroes',1)
    make('tree.child0.child3.child0.child0.child0.child0.child1.child0','list_box',1)
    make('tree.child0.child3.child0.child0.child0.child0.child1.child0.child0','character_row_1',1)
    make('tree.child0.child3.child0.child0.child0.child0.child1.child0.child0.child0','dy_character_name',0,'Korhil')
    make('tree.child0.child3.child0.child1','regions_dropdown',1)
    local regions_panel=make('tree.child0.child3.child0.child1.child0','panel',1,'',false)
    make('tree.child0.child3.child0.child1.child0.child0','list_box',1)
    make('tree.child0.child3.child0.child1.child0.child0.child0','section',1)
    make('tree.child0.child3.child0.child1.child0.child0.child0.child0','list_box',70)
    for i=0,69 do make('tree.child0.child3.child0.child1.child0.child0.child0.child0.child' .. i,'row_entry_prov_' .. i,0) end
    make('tree.child0.child4','bar_small_top',1)
    make('tree.child0.child4.child0','tabs',2)
    local tab_units=make('tree.child0.child4.child0.child0','tab_units',0)
    local tab_regions=make('tree.child0.child4.child0.child1','tab_regions',0)
    function tab_units:SimulateLClick() dispatches=dispatches+1; clicked=self.path; units_panel.visible=true; regions_panel.visible=false end
    function tab_regions:SimulateLClick() dispatches=dispatches+1; clicked=self.path; regions_panel.visible=true; units_panel.visible=false end
    local function list(items) return {num_items=function() return #items end,item_at=function(_,i) return items[i+1] end} end
    local names={names_tyrion='Tyrion',regions_onscreen_far_city='Far City',provinces_onscreen_prov_69='Province Sixty-nine'}
    effect={get_localised_string=function(key) return names[key] or '' end}
    local hef={}; function hef:name() return 'hef' end
    local settlement={}; function settlement:logical_position_x() return 300 end; function settlement:logical_position_y() return 300 end
    local far_city={name=function() return 'far_city' end,province_name=function() return 'prov_69' end,settlement=function() return settlement end,
        is_abandoned=function() return false end,owning_faction=function() return hef end}
    local tyrion={}
    function tyrion:cqi() return 5 end; function tyrion:get_forename() return 'names_tyrion' end; function tyrion:get_surname() return '' end
    function tyrion:character_type(t) return t=='general' end; function tyrion:has_military_force() return true end
    function tyrion:military_force() return {is_armed_citizenry=function() return false end,unit_list=function() return list({1}) end} end
    function tyrion:logical_position_x() return 310 end; function tyrion:logical_position_y() return 300 end
    function tyrion:action_points_remaining_percent() return 100 end
    function tyrion:has_region() return true end; function tyrion:region() return far_city end
    function hef:character_list() return list({tyrion}) end; function hef:faction_leader() return tyrion end
    function hef:region_list() return list({far_city}) end
    cm={is_multiplayer=function() return false end,get_local_faction=function() return hef end}
    begin(); for n=1,12 do tick(1) end
    local session=contents('reader-state.tsv'):match('^WH2READER1\t([^\t]+)\t')
    assert(session:match(':[%d.]+$'),'The session ID ends with the game clock: ' .. session)
    local seq=0
    local function send(...)
        local lines={'WH2KEYS1\tcompanion\t' .. session .. '\t1'}
        for _,action in ipairs({...}) do seq=seq+1; lines[#lines+1]=seq .. '\t' .. action end
        files[prefix .. 'keys.tsv']=table.concat(lines,'\n') .. '\n'
        tick(1)
    end
    send('noop')
    send('lords')
    assert(clicked=='tree.child0.child3.child0.child0.child0.child0.child0.child1.child0','The lord row inside the Lords section: ' .. tostring(clicked))
    send('lords')
    assert(clicked=='tree.child0.child3.child0.child1.child0.child0.child0.child0.child69','Province row 70 is found: ' .. tostring(clicked))
    assert(contents('bridge.jsonl'):find('Far City, Province Sixty-nine.',1,true),contents('bridge.jsonl'))
end
-- Live Game Menu: button_windows has a child named string, not button_txt.
-- Its label must name the button, and exiting always requires confirmation.
do
    for _,condition in ipairs({'normal','navigate','hidden','disabled','replaced','timeout'}) do
        local make=start('campaign',nil,2)
        local button=nodes['tree.child0.child0']
        button.id='button_windows'; button.label=''; button.count=1
        make('tree.child0.child0.child0','string',0,'Exit to Windows')
        begin(); tick(12)
        assert(contents('bridge.jsonl'):find('Exit to Windows, button',1,true),contents('bridge.jsonl'))
        assert(not contents('bridge.jsonl'):find('"text":"Windows, button',1,true),'No shortened duplicate button')
        fire('ShortcutTriggered',{string='script_F4'})
        assert(dispatches==0 and said()=='Exit to Windows? Press Enter again to confirm.',said())
        if condition=='navigate' then
            fire('ShortcutTriggered',{string='script_F2'}); fire('ShortcutTriggered',{string='script_F3'})
        elseif condition=='hidden' then button.visible=false
        elseif condition=='disabled' then button.faults.IsInteractive='nil'
        elseif condition=='replaced' then button.id='button_other'
        elseif condition=='timeout' then tick(11) end
        fire('ShortcutTriggered',{string='script_F4'})
        if condition=='normal' then
            assert(dispatches==1 and clicked=='tree.child0.child0','Click the button, never its text child')
        else assert(dispatches==0,'Unsafe quit: ' .. condition) end
    end
end
-- 0.6.74: every Game Menu button (live tree: button_txt empty, label in a
-- child named string) is one item named by its label, not two.
do
    local make=start('campaign',nil,2)
    local button=nodes['tree.child0.child0']
    button.id='button_resume'; button.label=''; button.count=2
    make('tree.child0.child0.child0','button_txt',0,'')
    make('tree.child0.child0.child1','string',0,'Resume Game')
    begin(); tick(12)
    local log=contents('bridge.jsonl')
    assert(log:find('Resume Game, button',1,true),log)
    assert(not log:find('"text":"Resume, button',1,true) and not log:find('Resume Game, 2 of',1,true),'No duplicate item: ' .. log)
end
-- 0.6.74: the pre-battle panel. Fighting the battle yourself is refused
-- (battles are auto resolved); Auto Resolve asks first, then one click.
do
    local make=start('campaign',nil,1)
    local panel=nodes['tree.child0.child0']
    panel.id='popup_pre_battle'; panel.label=''; panel.count=1
    make('tree.child0.child0.child0','button_set_attack',2,'')
    make('tree.child0.child0.child0.child0','button_attack',0,'Attack')
    make('tree.child0.child0.child0.child1','button_autoresolve',0,'Auto Resolve')
    begin(); tick(12)
    local function last() return (contents('bridge.jsonl'):match('"text":"([^"]*)"}\n$')) end
    local function go(prefix)
        for _=1,6 do if (last() or ''):sub(1,#prefix)==prefix then return true end; fire('ShortcutTriggered',{string='script_F2'}) end
        return (last() or ''):sub(1,#prefix)==prefix
    end
    assert(go('Attack, button'),contents('bridge.jsonl'))
    fire('ShortcutTriggered',{string='script_F4'}); fire('ShortcutTriggered',{string='script_F4'})
    assert(dispatches==0 and last()=='Fighting the battle yourself is not supported. Choose Auto-resolve.',last())
    assert(go('Auto Resolve, button'),contents('bridge.jsonl'))
    fire('ShortcutTriggered',{string='script_F4'})
    assert(dispatches==0 and last()=='Auto Resolve? Press Enter again to confirm.',last())
    fire('ShortcutTriggered',{string='script_F4'})
    assert(dispatches==1 and clicked=='tree.child0.child0.child0.child1','Auto Resolve clicked once: ' .. tostring(clicked))
end
-- 0.6.74 live: the game hides the HUD (layout) while the pre-battle panel is
-- open at the root; the panel is read anyway. HUD hidden alone is not read.
do
    local make=start('campaign',nil,2)
    begin(); tick(12)
    local before=contents('bridge.jsonl')
    nodes['tree.child0'].visible=false; tick(6)
    assert(contents('bridge.jsonl')==before,'Hidden HUD alone: nothing new is read')
    nodes.tree.count=5
    make('tree.child4','popup_pre_battle',1,'')
    make('tree.child4.child0','button_autoresolve',0,'Auto Resolve')
    tick(12)
    assert(contents('bridge.jsonl'):find('Auto Resolve, button',1,true),'The battle panel is read: ' .. contents('bridge.jsonl'))
end
-- 0.6.74 live shapes: battle results row and unit card, Settlement Captured option.
do
    local make=start('campaign',nil,1)
    local function tip(node,text) node.GetTooltipText=function() return text end; return node end
    local panel=nodes['tree.child0.child0']; panel.id='popup_battle_results'; panel.label=''; panel.count=2
    make('tree.child0.child0.child0','details_table',1,'')
    make('tree.child0.child0.child0.child0','list_box',1,'')
    make('tree.child0.child0.child0.child0.child0','row_example',3,'')
    make('tree.child0.child0.child0.child0.child0.child0','dy_deployed',0,'116')
    make('tree.child0.child0.child0.child0.child0.child1','dy_lost',0,'14')
    make('tree.child0.child0.child0.child0.child0.child2','dy_remaining',0,'102')
    make('tree.child0.child0.child1','commander_header_0',1,'')
    make('tree.child0.child0.child1.child0','units',1,'')
    tip(make('tree.child0.child0.child1.child0.child0','wh2_main_hef_inf_spearmen_0',2,''),'Spearmen')
    tip(make('tree.child0.child0.child1.child0.child0.child0','unit_category_icon',0,''),'Spear Infantry')
    make('tree.child0.child0.child1.child0.child0.child1','unit_strength_number',0,'22')
    begin(); tick(12)
    for _=1,4 do fire('ShortcutTriggered',{string='script_F2'}) end
    local log=contents('bridge.jsonl')
    assert(log:find('Your side, deployed 116, lost 14, remaining 102',1,true),log)
    assert(log:find('Spearmen, list item, Spear Infantry, 22 soldiers',1,true),log)
end
do
    local make=start('campaign',nil,1)
    local function tip(node,text) node.GetTooltipText=function() return text end; return node end
    local panel=nodes['tree.child0.child0']; panel.id='settlement_captured'; panel.label=''; panel.count=1
    make('tree.child0.child0.child0','button_parent',1,'')
    make('tree.child0.child0.child0.child0','1063',2,'')
    make('tree.child0.child0.child0.child0.child0','frame',1,'')
    make('tree.child0.child0.child0.child0.child0.child0','icon_parent',1,'')
    tip(make('tree.child0.child0.child0.child0.child0.child0.child0','dy_public_order',0,'-10'),'Conquest penalty||This is the penalty.')
    tip(make('tree.child0.child0.child0.child0.child1','option_button',2,''),'You occupy the settlement and all captives are killed.')
    make('tree.child0.child0.child0.child0.child1.child0','button_txt',0,'')
    make('tree.child0.child0.child0.child0.child1.child1','dy_option',0,'Occupy')
    begin(); tick(12)
    local function last() return (contents('bridge.jsonl'):match('"text":"([^"]*)"}\n$')) end
    for _=1,6 do if (last() or ''):sub(1,15)=='Occupy, button,' then break end; fire('ShortcutTriggered',{string='script_F2'}) end
    assert((last() or ''):sub(1,38)=='Occupy, button, Conquest penalty -10, ' and (last() or ''):sub(-54)=='You occupy the settlement and all captives are killed.',contents('bridge.jsonl'))
    fire('ShortcutTriggered',{string='script_F4'})
    assert(dispatches==0 and last()=='Occupy? Press Enter again to confirm.',last())
    fire('ShortcutTriggered',{string='script_F4'})
    assert(dispatches==1 and clicked=='tree.child0.child0.child0.child0.child1','Clicks the option card\'s own button: ' .. tostring(clicked))
end
-- Ctrl+Backspace dismisses only known notification controls, one per press.
do
    for _,condition in ipairs({'advice','skip','none','disabled','hidden','replaced','stale','overlay','repeat','notice','changednotice','notice-advisor'}) do
        local make=start('campaign',nil,1)
        nodes.tree.count=5
        local panel=make('tree.child4',condition=='skip' and 'notification_frame' or 'advice_interface',1,'')
        local button=make('tree.child4.child0',condition=='skip' and 'button_skip' or 'button_close',0,'')
        if condition=='notice' or condition=='changednotice' or condition=='notice-advisor' then
            panel.id='event_dialog'; panel.count=2; button.id='button_accept'
            make('tree.child4.child1','dy_title',0,'How They Play')
        end
        if condition=='notice-advisor' then
            -- 0.6.74 live: the advisor sits on a higher layer than the notice; it does not block.
            nodes.tree.count=6; make('tree.child5','advice_interface',1,''); make('tree.child5.child0','button_close',0,'')
        end
        if condition=='none' then panel.id='game_menu' end
        begin(); tick(12)
        local function send(action,stale)
            local state=contents('reader-state.tsv')
            local session,gen=state:match('^WH2READER1\t([^\t]+)\t([^\t]+)')
            local previous=files[prefix .. 'keys.tsv'] or ''
            local seq=tonumber(previous:match('\n(%d+)\t[^\n]+\n$')) or 0
            files[prefix .. 'keys.tsv']='WH2KEYS1\tdismiss-test\t' .. session .. '\t' .. (stale and '0' or gen) .. '\n' .. (seq+1) .. '\t' .. action .. '\n'
            tick(1)
        end
        send('noop') -- establish owner, no backlog
        if condition=='disabled' then button.faults.IsInteractive='nil'
        elseif condition=='hidden' then button.visible=false
        elseif condition=='replaced' then button.id='button_exit'
        elseif condition=='changednotice' then nodes['tree.child4.child1'].label='Start battle?'
        elseif condition=='overlay' then
            nodes.tree.count=6; make('tree.child5','game_menu',0,'Game Menu')
        end
        send('dismiss',condition=='stale')
        if condition=='advice' or condition=='skip' or condition=='repeat' or condition=='notice' or condition=='notice-advisor' then
            assert(dispatches==1 and clicked=='tree.child4.child0',condition .. ': ' .. tostring(said()))
            if condition=='repeat' then send('dismiss'); assert(dispatches==1,'Cannot click again before re-reading') end
        else assert(dispatches==0,'Unsafe dismissal: ' .. condition) end
    end
end
io=saved_io;os.date=saved_date
print('PASS: ' .. scenarios .. ' campaign diagnostic scenarios; HUD readiness, scoped discovery, typed failures, capture protocol, replay/generation/lease guards, limits, cancellation and zero clicks')
