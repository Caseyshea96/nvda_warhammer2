-- Campaign HUD reader. Players get it without a flag; the developer flag adds
-- the status/request channel and its limits. HUD reading never queries the
-- model; F6/F7 (lords, settlements, moving) read it, and a confirmed move is
-- the only game command (the game's own move order).
if not core:is_campaign() or core:is_battle() then return end
local base=os.getenv('LOCALAPPDATA')
if type(base)~='string' or base=='' then return end
base=base .. '/WarhammerAccess/'
-- Test-only switch for comparing the game with and without the campaign reader.
do local off=io.open(base .. 'campaign-reader-off.flag','r'); if off then off:close(); return end end
local function utc() return os.date('!%Y-%m-%dT%H:%M:%SZ') end
local function stamp(value)
    return type(value)=='string' and value:match('^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$')~=nil
end
local function read_file(name,limit)
    local f=io.open(base .. name,'r'); if not f then return nil end
    local value=f:read(limit); f:close(); return value
end
local function read_flag()
    local raw=read_file('campaign-discovery.tsv',256)
    if type(raw)~='string' then return nil end
    local owner,expires,mode=raw:match('^WH2CAM1\t([a-f0-9]+)\t([^\t\r\n]+)\t([a-z]+)\n$')
    local now=utc()
    if not owner or #owner~=32 or not stamp(expires) or not stamp(now) or now>expires
        or (mode~='capture' and mode~='verify') then return nil end
    return raw,owner,expires,mode
end
local initial,owner,expiry,mode=read_flag()
local diagnostic=initial~=nil
if not diagnostic then owner,expiry,mode='player','9999-12-31T23:59:59Z','player' end
-- os.clock makes it unique: the companion drops speech from a retired
-- session, and a table address alone can repeat in a later campaign load.
local session='campaign:' .. owner .. ':' .. tostring({}) .. ':' .. tostring((pcall(os.clock) and os.clock()) or 0)
local version='0.6.72'
local sequence,generation,bytes,run,attempts=0,1,0,0,0
local phase,result,last_request='initialising','ready',''
local queue,head,visited,page,entries,index={},1,0,0,{},0
local limited,errors,finished=false,0,false
local root_identity,layout_identity,stable_identity,root_count
local waiting_ticks,stable_ticks,ticks=0,0,0
local timer_name='warhammer_campaign_readonly_tick'
-- The game sometimes drops a single-shot timer event (live: the reader went
-- silent mid-scan, no error). A second timer re-arms it when ticks stop.
local watchdog_name='warhammer_campaign_readonly_watchdog'
local tick_count,watchdog_seen=0,-1
-- Live, the game's own flyover froze together with the reader's timers. The
-- reader used to register its next single-shot timer from inside the timer
-- callback; when the game offers a repeating timer, one is registered once
-- (100 ms) and nothing is registered from inside a callback.
local repeating=false
local function restart_reader_timer()
    pcall(function() real_timer.unregister(timer_name) end)
    pcall(function()
        if repeating then real_timer.register_repeating(timer_name,100) else real_timer.register_singleshot(timer_name,100) end
    end)
end
-- Live, both timers once stopped together after a province zoom; game events
-- that happen anyway (panels, clicks, selections, shortcuts) restart them.
-- os.time() (~1.8e9) is useless in the game's single-precision numbers (steps
-- of about two minutes); os.clock() counts seconds since the game started.
local last_tick_clock,event_seen_ticks=nil,-1
local function game_seconds()
    local ok,value=pcall(function() return os.clock() end)
    if ok and type(value)=='number' then return value end
end
local rearm_events={'PanelOpenedCampaign','PanelClosedCampaign','ComponentLClickUp','ComponentMouseOn',
    'SettlementSelected','CharacterSelected','ShortcutTriggered'}
local polling=false
local reader_stopped=false -- set by stop(); the game-timer job pump then does nothing
local seen_requests={}
local request_count=0
local last_request_raw,last_readiness
local reported_limits={}
local publish_status,request_capture
local captured_signature,previous_keys,refresh_announce,changed_ticks,last_signature=nil,{},false,0,nil
local focus_key,post_click,previous_count=nil,nil,0
local menu -- upgrade options read from the construction popup -- the item to return to after a re-read; re-read once after a click
local function remember_entries()
    -- Keys use element IDs and names, so a panel added at the root does not make every item look new.
    previous_keys={}; previous_count=0
    for _,entry in ipairs(entries) do
        local key=(entry.idpath or entry.key) .. '|' .. entry.name
        if not previous_keys[key] then previous_keys[key]=true; previous_count=previous_count+1 end
    end
    local current=entries[index]
    focus_key=current and ((current.idpath or current.key) .. '|' .. current.name) or nil
end
local verified_reader=false
local client_captures=0
local auto_reader=false -- verify-mode HUD reading keeps the one-second pace
local function quoted(value)
    return '"' .. tostring(value):gsub('[%z\1-\31\\"]',function(c)
        return string.format('\\u%04x',string.byte(c))
    end) .. '"'
end
local function bounded(value,maximum)
    if #value<=maximum then return value end
    return value:sub(1,maximum):gsub('[\192-\255][\128-\191]*$','')
end
local function emit(line)
    if bytes+#line+2>2097152 then error('Campaign discovery log budget reached') end
    local f=io.open(base .. 'native-ui-campaign-discovery.jsonl',bytes==0 and 'w' or 'a')
    if not f then error('Campaign discovery log unavailable') end
    local written=f:write(line .. '\n'); local closed=f:close()
    if not written or closed==nil then error('Campaign discovery log write failed') end
    bytes=bytes+#line+2
end
local function speak(text)
    sequence=sequence+1
    local f=io.open(base .. 'bridge.jsonl','a'); if not f then return end
    f:write('{"version":1,"session":' .. quoted(session) .. ',"sequence":' .. sequence
        .. ',"generation":' .. generation .. ',"context":"campaign","kind":"speech","text":' .. quoted(text) .. '}\n')
    f:close()
end
local function read(fn)
    local value
    local ok,err=pcall(function() value=fn() end)
    return ok,value,err
end
local function identity(node)
    local ok,address=read(function() local v=node:Address(); return v end)
    if ok and (type(address)=='userdata' or type(address)=='string') then return tostring(address) end
end
local function lease_active()
    if not diagnostic then return core:is_campaign() end
    return core:is_campaign() and read_flag()==initial
end
local function clean(value)
    return value:gsub('%[%[.-%]%]',' '):gsub('<[^>]*>',' '):gsub('[%z\1-\31]',' ')
        :gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$','')
end
local function issue(path,method,ok,value,err,reason)
    errors=errors+1; limited=true
    emit('{"kind":"read-issue","run":' .. run .. ',"generation":' .. generation .. ',"page":' .. page
        .. ',"path":' .. quoted(path) .. ',"method":' .. quoted(method) .. ',"ok":' .. tostring(ok)
        .. ',"expected_type":' .. quoted(method=='ChildCount' and 'number' or 'string')
        .. ',"value_type":' .. quoted(type(value)) .. ',"reason":' .. quoted(reason or 'return-type')
        .. ',"error":' .. quoted(type(err)=='string' and bounded(err,300) or '') .. '}')
end
local function limit(reason,path,value)
    limited=true
    if reported_limits[reason] then return end
    reported_limits[reason]=true
    emit('{"kind":"limit","run":' .. run .. ',"page":' .. page .. ',"reason":' .. quoted(reason)
        .. ',"path":' .. quoted(path) .. ',"value":' .. value .. '}')
end
local function text(value) return type(value)=='string' and bounded(value,4000) or '' end
-- Reading IDs/visibility of root children reveals no hidden text. The game's
-- campaign UI library places its HUD under "layout"; the last live capture
-- showed this hidden while cinematic_bars was visible.
local signature_skip={Tooltip=true,['3d_ui_parent']=true,character_map_path_icons=true,
    watermark_square=true,black_fade=true,cinematic_bars=true}
local function hud_context()
    if not core:is_ui_created() then return nil,'ui-not-created' end
    local parts={}
    local ok,root=read(function() local v=core:get_ui_root(); return v end)
    if not ok or not root then return nil,'root-unavailable' end
    local _,id=read(function() local v=root:Id(); return v end)
    local _,visible=read(function() local v=root:Visible(true); return v end)
    local _,count=read(function() local v=root:ChildCount(); return v end)
    if id~='root' or visible~=true or type(count)~='number' or count<0 or count>100 or count%1~=0 then return nil,'root-shape' end
    local layout,layout_visible,bars,loading=nil,false,false,false
    for i=0,count-1 do
        local found,address=read(function() local v=root:Find(i); return v end)
        if not found or not address then return nil,'root-child-missing' end
        local converted,node=read(function() local v=UIComponent(address); return v end)
        if not converted or not node then return nil,'root-child-conversion' end
        local _,child_id=read(function() local v=node:Id(); return v end)
        local _,shown=read(function() local v=node:Visible(true); return v end)
        if type(child_id)~='string' or type(shown)~='boolean' then return nil,'root-child-type' end
        if not signature_skip[child_id] then parts[#parts+1]=child_id .. (shown and '+' or '-') end
        if child_id=='layout' then
            if layout then return nil,'duplicate-layout' end
            layout=node; layout_visible=shown
        elseif child_id=='cinematic_bars' and shown then bars=true
        elseif (child_id=='campaign' or child_id=='custom_loading_screen') and shown then loading=true end
    end
    if loading then return nil,'loading-screen' end
    if bars then return nil,'cinematic-visible' end
    if not layout or not layout_visible then return nil,'hud-hidden' end
    local root_address,layout_address=identity(root),identity(layout)
    if not root_address or not layout_address then return nil,'identity-unavailable' end
    return {root=root,root_address=root_address,layout_address=layout_address,count=count,signature=table.concat(parts,',')}
end
-- Which panels are showing, three levels deep (capped at 300 elements), so a
-- panel swapped inside a container (tutorial "Mission Issued!") is noticed.
local function panel_signature(context)
    local parts,queue_nodes,head_node,seen={},{},1,0
    for i=0,context.count-1 do
        local _,address=read(function() local v=context.root:Find(i); return v end)
        local ok,node=read(function() local v=UIComponent(address); return v end)
        if ok and node then queue_nodes[#queue_nodes+1]={node=node,depth=1} end
    end
    while head_node<=#queue_nodes and seen<300 do
        local item=queue_nodes[head_node]; head_node=head_node+1; seen=seen+1
        local _,id=read(function() local v=item.node:Id(); return v end)
        local _,shown=read(function() local v=item.node:Visible(true); return v end)
        if type(id)=='string' and not (item.depth==1 and signature_skip[id]) then
            parts[#parts+1]=item.depth .. id .. (shown==true and '+' or '-')
            if shown==true and item.depth<3 then
                local _,count=read(function() local v=item.node:ChildCount(); return v end)
                if type(count)=='number' then
                    for i=0,math.min(count,40)-1 do
                        local _,address=read(function() local v=item.node:Find(i); return v end)
                        local ok,child=read(function() local v=UIComponent(address); return v end)
                        if ok and child then queue_nodes[#queue_nodes+1]={node=child,depth=item.depth+1} end
                    end
                end
            end
        end
    end
    return table.concat(parts,',')
end
local function resolve(root,path,ids)
    local node=root
    for depth,child_index in ipairs(path) do
        local ok,visible=read(function() local v=node:Visible(true); return v end)
        if not ok or visible~=true then return nil,ok and 'hidden' or 'visibility-error' end
        local found,address=read(function() local v=node:Find(child_index); return v end)
        if not found or not address then return nil,'missing' end
        local converted,child=read(function() local v=UIComponent(address); return v end)
        if not converted or not child then return nil,'conversion' end
        node=child
        if ids[depth] then
            local _,id=read(function() local v=node:Id(); return v end)
            if id~=ids[depth] then return nil,'changed' end
        end
    end
    local ok,visible=read(function() local v=node:Visible(true); return v end)
    if not ok or visible~=true then return nil,ok and 'hidden' or 'visibility-error' end
    return node
end
local function cancel(reason)
    remember_entries()
    generation=generation+1; phase='cancelled'; result=reason
    finished=false; entries={}; queue={}; index=0
    emit('{"kind":"cancelled","run":' .. run .. ',"generation":' .. generation .. ',"reason":' .. quoted(reason) .. '}')
end
local function move_cursor(step)
    if index==0 then index=step>0 and 1 or #entries else index=((index-1+step)%#entries)+1 end
    return entries[index]
end
local function role_of(id,parent)
    if type(id)~='string' then return nil end
    return (id:sub(1,7)=='button_' and 'button') or (id:sub(1,4)=='tab_' and 'tab')
        or (id:sub(1,7)=='toggle_' and 'toggle button') or (id=='3D_advisor_portrait' and 'button')
        or (id:sub(1,5)=='sort_' and 'button')
        or ((id=='dy_title' or id=='tx_title' or id=='tx_list_title' or id=='dy_province' or id=='header_frame') and 'heading')
        or ((id=='dy_txt' and (parent=='header' or parent=='button_focus')) and 'heading')
        or (parent=='title_plaque' and 'heading') or nil
end
local function entry_role(entry) return entry.role or role_of(entry.id) end
-- Stable across panels opening (child indices shift when a root panel is added).
local function stable_key(entry) return (entry.idpath or entry.key) .. '|' .. entry.name end
-- Province rows and buildings are read as one item each: their child elements
-- (name, income, cost, lock, units) are folded into it.
local stat_holders={wealth_holder=true,public_order=true,pop_surplus=true,tx_turns=true,upkeep_cost=true}
local function composite_kind(id,ids,depth)
    if type(id)~='string' then return nil end
    if id:sub(1,10)=='row_entry_' then return 'row' end
    if id:sub(1,18)=='general_candidate_' then return 'candidate' end
    if id:sub(1,14)=='character_row_' then return 'character' end
    if id:match('^LandUnit %d+$') or id:match('^NavalUnit %d+$') then return 'unit' end
    -- Settlement panel figures: a label, a number and an icon are one item
    -- ("Income, 520", "Public order, 0 (-1), Neutral").
    if stat_holders[id] then return 'stat' end
    -- Unit details: "Armour, 80, Shielded" (name, number and modifier icons).
    if ids[depth-1]=='dynamic_stats' and id:match('^stat%d+$') then return 'stat' end
    if id:sub(1,9)=='checkbox_' then return 'checkbox' end
    local parent,grand=ids[depth-1],ids[depth-2]
    if parent=='list_box' then
        -- Lord types in the Recruit Lord panel (Legendary Lords, Prince, Princess).
        for _,ancestor in ipairs(ids) do if ancestor=='lord_parent' then return 'lordtype' end end
    end
    if (type(parent)=='string' and parent:sub(1,14)=='building_slot_') or grand=='slot_parent' then return 'building' end
end
local building_names,settlement_names={},{}
local function building_label(key)
    if key:match('^Slot%d+_Construction_Site$') then return 'Construction slot' end
    if building_names[key] then return building_names[key] end
    -- The game's own scripts read building names this way (lib_common_ui).
    local ok,loc=read(function() local v=effect.get_localised_string('building_culture_variants_name_' .. key); return v end)
    local result=(ok and type(loc)=='string') and clean(bounded(loc,200)) or ''
    if result=='' then result=(key:gsub('_',' ')) end
    building_names[key]=result
    return result
end
local building_states={built='built',locked='locked',not_owned='not owned'}
local function add_state(entry,value)
    if value=='' or #entry.states>=6 then return end
    for _,known in ipairs(entry.states) do if known==value then return end end
    entry.states[#entry.states+1]=value
end
local function contribute(entry,id,name,tip_name,state,parent)
    if entry.kind=='character' then
        -- Lords & Heroes row: "Tyrion, list item, Legendary Lord, faction leader, rank 1, 116 soldiers".
        if id=='dy_character_name' and name~='' then entry.name=name
        elseif id=='forces_icon' and tip_name~='' then entry.value=tip_name
        elseif id=='faction_leader' and state=='leader' then add_state(entry,'faction leader')
        elseif id=='dy_rank' and name~='' then add_state(entry,'rank ' .. name)
        elseif id=='soldiers' and name~='' then add_state(entry,name .. ' soldiers') end
        return
    elseif entry.kind=='unit' then
        -- Army unit card: "Spearmen, list item, Spear Infantry, strength 30".
        if id=='unit_category_icon' and tip_name~='' then entry.value=tip_name
        elseif id=='unit_strength_number' and name~='' then add_state(entry,'strength ' .. name)
        elseif id=='experience' and type(state)=='string' and state:match('^%d+$') and state~='0' then add_state(entry,'rank ' .. state) end
        return
    end
    if entry.kind=='stat' then
        if (id:sub(1,3)=='tx_' or id=='stat_name') and name~='' then entry.name=(name:gsub('%s*:$',''))
        elseif parent=='mod_icon_list' and tip_name~='' then add_state(entry,tip_name)
        elseif (id:sub(1,3)=='dy_' or id=='total') and name~='' then entry.value=name
        elseif id=='icon_public_order' and tip_name~='' then add_state(entry,tip_name) end
        return
    elseif entry.kind=='checkbox' then
        -- "Tax Province, check box, checked, …, Taxing a province will provide …"
        if id=='label_txt' and name~='' then entry.name=name; entry.description=tip_name end
        return
    end
    local person=entry.kind=='candidate' or entry.kind=='lordtype'
    if person then
        if (id=='dy_name' or (id=='label' and entry.kind=='lordtype')) and name~='' then entry.name=name
        elseif id=='dy_subtype' and name~='' then entry.value=name
        elseif parent=='RecruitmentCost' and name~='' then add_state(entry,'cost ' .. name)
        elseif parent=='UpkeepCost' and name~='' then add_state(entry,'upkeep ' .. name)
        elseif parent=='IntrigueCost' and name~='' then add_state(entry,'influence ' .. name)
        elseif id=='dy_rank' and name~='' then add_state(entry,'rank ' .. name)
        elseif id=='icon_background_skill' and name~='' then add_state(entry,name) end
        return
    end
    if id=='region_name' and name~='' then
        entry.name=name
        if tip_name~='' then add_state(entry,(tip_name:gsub('^%((.*)%)$','%1'))) end
    elseif id=='income' and name~='' then entry.value=name
    elseif id=='dy_num_points_required' and name~='' then
        add_state(entry,'Population surplus cost ' .. name .. (state=='red' and ', not enough' or ''))
    elseif id=='button_expand_slot' and state=='locked' then add_state(entry,'locked')
    elseif id=='turns_center' and name~='' then
        add_state(entry,'under construction, ' .. name .. (name=='1' and ' turn left' or ' turns left'))
    elseif parent=='units_list' and tip_name~='' then
        if #entry.units<8 then entry.units[#entry.units+1]=tip_name end
    elseif tip_name~='' and tip_name~='Left-click to zoom to province' then
        add_state(entry,(tip_name:gsub('^%((.*)%)$','%1')))
    end
end
-- Reading order: each settlement's buildings right after its name; the
-- minimap's settlement icons after everything else.
local function arrange_entries()
    -- Document order, as NVDA reads a page: each panel's title, text and
    -- buttons together (the scan itself is breadth-first).
    -- A title is read before the elements beside it ("Your Provinces" sits
    -- after its sort buttons and rows in the tree).
    local function order_path(entry)
        local path=entry.path or {}
        if entry_role(entry)=='heading' and entry.id~='dy_province' and #path>0 then
            local level=#path
            local parent=entry.ids and entry.ids[#path-1]
            -- "Recruit Lord" sits in a title plaque after the panel's list.
            if type(parent)=='string' and level>1 and (parent:match('title') or parent:match('plaque')) then level=level-1 end
            local moved={}
            for depth=1,level-1 do moved[depth]=path[depth] end
            moved[level]=-1
            return moved
        end
        return path
    end
    for position,entry in ipairs(entries) do entry.scan_order=position; entry.order_path=order_path(entry) end
    table.sort(entries,function(a,b)
        local pa,pb=a.order_path,b.order_path
        for depth=1,math.min(#pa,#pb) do
            if pa[depth]~=pb[depth] then return pa[depth]<pb[depth] end
        end
        if #pa~=#pb then return #pa<#pb end
        return a.scan_order<b.scan_order
    end)
    -- Group members (a settlement's buildings, an army's unit cards) are read
    -- right after their heading, wherever they sit in the tree.
    local function member(entry) return entry.settlement or entry.group_key end
    local groups,headed,minimap,ordered={}, {}, {}, {}
    for _,entry in ipairs(entries) do
        local key=member(entry)
        if key then groups[key]=groups[key] or {}; local list=groups[key]; list[#list+1]=entry end
        local heading=entry.settlement_heading or entry.group_heading
        if heading then headed[heading]=true end
    end
    for _,entry in ipairs(entries) do
        local own=member(entry)
        if entry.idpath and ('/' .. entry.idpath):match('/radar/') then minimap[#minimap+1]=entry
        elseif not (own and headed[own]) then
            ordered[#ordered+1]=entry -- a member without a heading stays where it is
            local heading=entry.settlement_heading or entry.group_heading
            if heading and groups[heading] and headed[heading]~='placed' then
                headed[heading]='placed'
                for _,other in ipairs(groups[heading]) do ordered[#ordered+1]=other end
            end
        end
    end
    for _,entry in ipairs(minimap) do ordered[#ordered+1]=entry end
    if #ordered==#entries then entries=ordered end
end
local function strip_levels(label,levels)
    for _=1,levels do label=label:gsub('%.child%d+$','') end
    return label
end
local pending_confirm -- End Turn / Quit / Exit / Load ask first
local function browse(step,quiet)
    pending_confirm=nil -- moving cancels a pending confirmation
    if not lease_active() or not finished then return false end
    local context=hud_context()
    if not context or context.root_address~=root_identity or context.layout_address~=layout_identity or context.count~=root_count then cancel('hud-changed');return false end
    if #entries==0 then if not quiet then speak('No readable campaign text.') end;return false end
    local item=move_cursor(step)
    if not quiet then
        local role=entry_role(item)
        local parts={item.name}
        if role then parts[#parts+1]=role end
        if item.value and item.value~='' then parts[#parts+1]=item.value end
        for _,state in ipairs(item.states or {}) do parts[#parts+1]=state end
        parts[#parts+1]=index .. ' of ' .. #entries
        if item.units and #item.units>0 then parts[#parts+1]='Units: ' .. table.concat(item.units,', ') end
        if item.description and item.description~='' then parts[#parts+1]=item.description end
        speak(table.concat(parts,', '))
    end
    return item.key
end
local function verify_reader()
    if mode~='verify' or limited or #entries==0 then return end
    index=0
    -- Cursor traversal is pure; normal browse gates are exercised at both wraps.
    for expected=1,#entries do assert(move_cursor(1).key==entries[expected].key,'Reader order changed') end
    assert(browse(1,true)==entries[1].key,'Next wrap failed')
    assert(browse(-1,true)==entries[#entries].key,'Previous wrap failed')
    emit('{"kind":"reader-verification","run":' .. run .. ',"passed":true,"entries":' .. #entries .. ',"source":"native-self-test","physical_keys_verified":false}')
    index=0
    verified_reader=true -- developer verify mode then turns HUD reading on (Shift+F2 cannot be injected)
end
-- Labels for HUD elements whose own text is only a value or whose tooltip is
-- a warning rather than a name (from the 0.6.32 live capture).
local value_labels={dy_income='Income',counter='Unresolved events',dy_growth='Growth'}
-- "Growth:" sits beside its value (dy_growth, read as "Growth, 0/600 (+20)").
local dropped_labels={tx_growth=true,hit_points=true}
local help_hint='Left-click to open Help pages.'
local religion_names={untainted='Untainted',chaos='Chaos corruption',undeath='Vampiric corruption',skaven='Skaven corruption'}
local function religion_label(id)
    local key=id:match('religion_(.+)$') or id
    if religion_names[key] then return religion_names[key] end
    local words=key:gsub('_',' ')
    return words:sub(1,1):upper() .. words:sub(2)
end
local name_labels={button_end_turn='End turn',button_skip='Skip',['3D_advisor_portrait']='Repeat advice',button_raise='Recruit'}
local punctuation={['(']=true,[')']=true}
-- Buttons with no text or tooltip (check marks, close buttons) still need a
-- name, or a keyboard user cannot dismiss advice: derive it from the ID.
local function button_name(id,ancestors)
    if type(id)~='string' or id:sub(1,7)~='button_' or id:match('test') then return '' end
    local words=id:sub(8):gsub('_',' '):lower()
    if words=='' then return '' end
    local name=words:sub(1,1):upper() .. words:sub(2)
    for _,ancestor in ipairs(ancestors or {}) do
        if type(ancestor)=='string' and ancestor:match('advice') then return name .. ' advice' end
    end
    return name
end
local function is_number(value)
    if value=='' then return false end
    for position=1,#value do
        local byte=string.byte(value,position)
        if not (byte>=48 and byte<=57) and byte~=44 and byte~=45 and byte~=43 then return false end
    end
    return true
end
local excluded={['3d_ui_parent']='world-space',['character_map_path_icons']='world-space',
    ['watermark_square']='visual-only',['black_fade']='visual-only',['cinematic_bars']='visual-only',
    ['Tooltip']='hover-tooltip'}
local function page_read()
    local context=hud_context()
    if not context or context.root_address~=root_identity or context.layout_address~=layout_identity or context.count~=root_count then cancel('hud-changed');return end
    local root=context.root
    page=page+1; local examined=0
    while examined<48 and head<=#queue and visited<1536 do
        local item=queue[head];head=head+1;examined=examined+1;visited=visited+1
        local node,reason=resolve(root,item.path,item.ids)
        if node then
            local id_ok,id,id_error=read(function() local v=node:Id();return v end)
            if not id_ok or type(id)~='string' then issue(item.label,'Id',id_ok,id,id_error);id='' end
            if #item.path==1 and excluded[id] then
                emit('{"kind":"excluded","run":' .. run .. ',"page":' .. page .. ',"path":' .. quoted(item.label) .. ',"id":' .. quoted(id) .. ',"reason":' .. quoted(excluded[id]) .. '}')
            else
                local getters={GetStateText=function() local v=node:GetStateText();return v end,
                    GetTooltipText=function() local v=node:GetTooltipText();return v end,
                    CurrentState=function() local v=node:CurrentState();return v end,
                    ChildCount=function() local v=node:ChildCount();return v end}
                local values,types={Id=id},{Id=type(id)}
                for _,method in ipairs({'GetStateText','GetTooltipText','CurrentState','ChildCount'}) do
                    local ok,value,err=read(getters[method]);values[method]=value;types[method]=type(value)
                    local wanted=method=='ChildCount' and 'number' or 'string'
                    if not ok or type(value)~=wanted then issue(item.label,method,ok,value,err)
                    elseif type(value)=='string' and #value>4000 then issue(item.label,method,ok,value,nil,'text-limit') end
                end
                local label,tip,state=text(values.GetStateText),text(values.GetTooltipText),text(values.CurrentState)
                local count=values.ChildCount
                if type(count)~='number' then count=0
                elseif count~=count or count<0 or count%1~=0 then issue(item.label,'ChildCount',true,count,nil,'invalid-count');count=0 end
                emit('{"kind":"node","run":' .. run .. ',"page":' .. page .. ',"path":' .. quoted(item.label) .. ',"id":' .. quoted(id)
                    .. ',"text":' .. quoted(label) .. ',"tooltip":' .. quoted(tip) .. ',"state":' .. quoted(state) .. ',"children":' .. count
                    .. ',"text_type":' .. quoted(types.GetStateText) .. ',"tooltip_type":' .. quoted(types.GetTooltipText)
                    .. ',"state_type":' .. quoted(types.CurrentState) .. ',"children_type":' .. quoted(types.ChildCount) .. '}')
                local name,tooltip=clean(label),clean(tip)
                -- Tooltips read "Name||Description"; a value with a tooltip is
                -- one item: "Treasury, 6000, This is the total amount ...".
                local tip_name,tip_description=tooltip,''
                for position=1,#tooltip-1 do
                    if string.byte(tooltip,position)==124 and string.byte(tooltip,position+1)==124 then
                        tip_name=clean(string.sub(tooltip,1,position-1)); tip_description=clean((string.sub(tooltip,position+2):gsub('%s*||%s*','. '):gsub('%.%.%s','. '))); break
                    end
                end
                local depth=#item.path
                local parent=item.ids[depth-1]
                local group,kind=item.group,nil
                if group then
                    -- Part of a province row or building: fold it into that item.
                    contribute(group,id,name,tip_name,state,parent)
                else kind=composite_kind(id,item.ids,depth) end
                if kind and #entries>=512 then limit('entry-budget',item.label,#entries)
                elseif kind then
                    local entry={key='campaign:' .. item.label .. ':' .. kind,name=tip_name,value='',description='',states={},units={},
                        id=id,path=item.path,ids=item.ids,idpath=table.concat(item.ids,'/') .. '/' .. id}
                    entry.kind=kind
                    if kind=='row' then entry.role='list item'
                    elseif kind=='candidate' then
                        entry.role='list item'; entry.name=''
                        if state=='inactive' then
                            -- The tooltip says why: "Cannot recruit Lord. You have insufficient influence."
                            add_state(entry,'unavailable')
                            local lines,reason={},{}
                            for line in (tip .. '\n'):gmatch('([^\n]*)\n') do lines[#lines+1]=line end
                            for position=3,#lines do local part=clean(lines[position]); if part~='' then reason[#reason+1]=part end end
                            entry.description=table.concat(reason,'. ')
                        end
                    elseif kind=='character' then entry.role='list item'; entry.name=''
                    elseif kind=='stat' then
                        entry.read_only=true; entry.name=name~='' and (name:gsub('%s*:$','')) or tip_name
                        if id:match('^stat%d+$') then entry.name=''; entry.description=tip_name end
                    elseif kind=='checkbox' then
                        -- Read only for now: toggling (taxes) is not unblocked.
                        entry.role='check box'; entry.name=tip_name; entry.read_only=true
                        add_state(entry,(state=='selected' or state=='selected_hover' or state=='selected_down') and 'checked' or 'not checked')
                    elseif kind=='unit' then
                        entry.role='list item'; entry.name=tip_name; entry.read_only=true; entry.group_key='army'
                    elseif kind=='lordtype' then
                        entry.role='tab'; entry.name=(id:gsub('_',' '))
                        if state=='selected' then add_state(entry,'selected') end
                    else
                        entry.role='button'; entry.name=building_label(id)
                        add_state(entry,building_states[state] or '')
                        if parent and parent:sub(1,14)=='building_slot_' then
                            entry.settlement=strip_levels(item.label,3); entry.value=settlement_names[entry.settlement] or ''
                        end
                        -- Choosing an available upgrade in the construction popup starts building it.
                        if parent~=nil and item.ids[depth-2]=='slot_parent' and state=='normal' then entry.confirm='Build ' .. entry.name end
                    end
                    entries[#entries+1]=entry; group=entry
                end
                local entry_name,value,description=name,'',''
                local created_button
                if group then entry_name=''
                elseif name~='' and tip_name~='' and tip_name~=name and tip_description=='' and (#tip_name>48 or tip_name:sub(-1)=='.') then
                    -- A sentence tooltip explains the text: "Armoured & Shielded, …, Armoured units can block …".
                    entry_name,description=name,tip_name
                elseif name~='' and tip_name~='' and tip_name~=name then entry_name,value,description=tip_name,name,tip_description
                elseif name=='' then entry_name,description=tip_name,tip_description end
                if not group and name~='' and role_of(id,parent)=='heading' then
                    -- A panel title keeps its own text; the tooltip explains it ("Growth, heading, …, Once growth reaches …").
                    entry_name,value,description=name,'',(tip_name~=name and tip_name or '')
                end
                if not group and parent=='corruption_docker' and name~='' then
                    entry_name,value=religion_label(id),name
                end
                if dropped_labels[id] then entry_name='' end
                if description==help_hint then description='' end
                if id=='dy_province' and name~='' then
                    -- A settlement's name above its building slots.
                    entry_name,value,description=name,'',''
                    settlement_names[strip_levels(item.label,2)]=name
                end
                -- Containers named button_* sit in NewState; only clickable states count.
                local derived=false
                if entry_name=='' and not group and (state=='active' or state=='hover' or state=='selected' or state=='down') then entry_name=button_name(id,item.ids); derived=entry_name~='' end
                -- A button's own label element ("Recruit" inside Recruit) is not a second item.
                local owner=item.owner
                if owner and not group and parent~='button_focus' and (id=='button_txt' or id=='dy_txt'
                    or (id=='string' and parent=='button_windows')) then
                    if name~='' and owner.derived then owner.name=name; owner.derived=false end
                    entry_name=''
                end
                if group then -- folded into the row/building above
                elseif name_labels[id] then
                    -- The tooltip is a warning ("Dismiss all advice ..."): keep it as the description.
                    if entry_name~=name_labels[id] then description=tip_description~='' and (tip_name .. '. ' .. tip_description) or tooltip end
                    entry_name,value=name_labels[id],(name~='' and name~=tooltip) and name or ''
                elseif value_labels[id] and value=='' and name~='' then entry_name,value=value_labels[id],name end
                local previous=entries[#entries]
                if punctuation[entry_name] and value=='' then entry_name=''
                elseif value=='' and description=='' and is_number(entry_name) and previous and (previous.value or '')=='' and not previous.states then
                    -- A bare count belongs to the item before it: "Missions, 1".
                    previous.value=entry_name; entry_name=''
                end
                if entry_name~='' then
                    if #entries>=512 then limit('entry-budget',item.label,#entries)
                    else entries[#entries+1]={key='campaign:' .. item.label .. ':' .. (name~='' and 'text' or 'tooltip'),
                        name=entry_name,value=value,description=description,id=id,path=item.path,ids=item.ids,
                        role=role_of(id,parent),idpath=table.concat(item.ids,'/') .. '/' .. id,
                        settlement_heading=(id=='dy_province') and strip_levels(item.label,2) or nil,
                        group_heading=(id=='dy_txt' and parent=='button_focus' and ('/' .. table.concat(item.ids,'/')):match('/units_panel/')) and 'army' or nil}
                        local made=entries[#entries]
                        if made.role=='button' then made.derived=derived; created_button=made end
                    end
                end
                if #item.path>=16 and count>0 then limit('depth-budget',item.label,#item.path)
                else
                    if count>256 then limit('child-budget',item.label,count) end
                    for child_index=0,math.min(count,256)-1 do
                        if #queue>=2048 then limit('queue-budget',item.label,#queue);break end
                        local path,ids={},{}
                        for depth,value in ipairs(item.path) do path[depth]=value;ids[depth]=item.ids[depth] end
                        if #path>0 then ids[#path]=id end
                        path[#path+1]=child_index
                        queue[#queue+1]={path=path,ids=ids,label=item.label .. '.child' .. child_index,group=group,owner=created_button}
                    end
                end
            end
        else
            if reason~='hidden' then errors=errors+1;limited=true end
            emit('{"kind":"skip","run":' .. run .. ',"page":' .. page .. ',"path":' .. quoted(item.label) .. ',"reason":' .. quoted(reason) .. '}')
        end
    end
    finished=head>#queue or visited>=1536
    if visited>=1536 and head<=#queue then limit('node-budget','tree',visited) end
    emit('{"kind":"page","run":' .. run .. ',"page":' .. page .. ',"examined":' .. examined .. ',"total":' .. visited
        .. ',"entries":' .. #entries .. ',"errors":' .. errors .. ',"done":' .. tostring(finished)
        .. ',"complete":' .. tostring(finished and not limited) .. ',"limited":' .. tostring(limited) .. '}')
    if finished then
        arrange_entries()
        phase=limited and 'limited' or 'ready';result='capture-complete';verify_reader()
        -- The upgrade list keeps the keys; a re-read behind it stays quiet.
        if menu then refresh_announce=false; return end
        if refresh_announce then
            -- Like focus moving into a newly opened dialog: start at the first new item.
            refresh_announce=false
            -- Prefer a new heading, then new text, then any new item.
            local heading,text_item,first_new,focus,composite
            local kept,seen_keys=0,{}
            for position,entry in ipairs(entries) do
                local key=stable_key(entry)
                if key==focus_key then focus=focus or position end
                if previous_keys[key] and not seen_keys[key] then kept=kept+1 end
                seen_keys[key]=true
                if not previous_keys[key] then
                    first_new=first_new or position
                    local role=entry_role(entry)
                    if role=='heading' then heading=heading or position
                    elseif entry.states then composite=composite or position
                    elseif role==nil then text_item=text_item or position end
                end
            end
            local found=heading or composite or text_item or first_new
            if found then
                speak('Screen updated.')
                index=found-1
            elseif kept<previous_count then
                -- Something closed: say so and stay on the same item if it is still there.
                speak('Screen updated.')
                index=focus and focus-1 or 0
            else
                -- Nothing new (a click that changed only a state): stay on the same item, quietly.
                index=focus or 0
                emit('{"kind":"refresh-unchanged","entries":' .. #entries .. '}')
                return
            end
        else
            speak('Campaign map, ' .. #entries .. ' items.' .. (limited and ' Some text could not be read.' or ''))
            -- Like NVDA in a window with a dialog open: start at the title of the
            -- top-most panel (drawn last, so the highest root child), else the first item.
            local base_layer=entries[1] and entries[1].path and entries[1].path[1] or 0
            local best,best_layer
            for position,entry in ipairs(entries) do
                local layer=entry.path and entry.path[1] or 0
                if entry_role(entry)=='heading' and layer>base_layer and (not best_layer or layer>best_layer) then best,best_layer=position,layer end
            end
            index=best and best-1 or 0
        end
        browse(1,false)
    end
end
request_capture=function(source)
    -- The three-capture cap guards the developer client's explicit requests;
    -- automatic re-reads after screen changes do not count against it.
    if diagnostic and source=='read-only-client' and client_captures>=3 then result='capture-limit';return false end
    if source=='read-only-client' or source=='first-tick' then client_captures=client_captures+1 end
    -- Re-reads can go on for a whole session: start the log over when large.
    if bytes>1048576 then bytes=0 end
    attempts=attempts+1;generation=generation+1;phase='waiting';result='accepted'
    entries={};queue={};index=0;head=1;visited=0;page=0;errors=0;limited=false;finished=false
    settlement_names={};post_click=nil
    waiting_ticks=0;stable_ticks=0;stable_identity=nil;last_readiness=nil;reported_limits={}
    emit('{"kind":"capture-request","generation":' .. generation .. ',"attempt":' .. attempts .. ',"source":' .. quoted(source) .. '}')
    return true
end
local function waiting_step()
    waiting_ticks=waiting_ticks+1
    local context,reason=hud_context()
    if context then
        local signature=context.root_address .. '|' .. context.layout_address .. '|' .. context.count
        stable_ticks=signature==stable_identity and stable_ticks+1 or 1;stable_identity=signature;reason='hud-stabilising'
        if stable_ticks>=2 then
            run=run+1;root_identity=context.root_address;layout_identity=context.layout_address;root_count=context.count
            captured_signature=panel_signature(context)
            queue={{path={},ids={},label='tree'}};phase='scanning';result='scanning'
            emit('{"kind":"begin","version":' .. quoted(version) .. ',"session":' .. quoted(session) .. ',"run":' .. run
                .. ',"generation":' .. generation .. ',"read_only":true,"scope":"hud-and-dialogs-excluding-world-space","page_budget":48,"node_budget":1536}')
            if not refresh_announce then speak('Reading the campaign map.') end;return
        end
    else stable_ticks=0;stable_identity=nil end
    if reason~=last_readiness then
        emit('{"kind":"readiness","generation":' .. generation .. ',"reason":' .. quoted(reason) .. '}');last_readiness=reason
    end
    if waiting_ticks>=180 then phase='waiting-timeout';result='hud-timeout';emit('{"kind":"timeout","generation":' .. generation .. ',"reason":"hud-not-ready"}') end
end
publish_status=function()
    if not diagnostic then return end
    local item=entries[index]
    local line='{"protocol":"WH2CAMSTATUS1","version":' .. quoted(version) .. ',"owner":' .. quoted(owner)
        .. ',"session":' .. quoted(session) .. ',"generation":' .. generation .. ',"phase":' .. quoted(phase)
        .. ',"request":' .. quoted(last_request) .. ',"result":' .. quoted(result) .. ',"attempts":' .. attempts
        .. ',"run":' .. run .. ',"count":' .. #entries .. ',"index":' .. index .. ',"errors":' .. errors
        .. ',"complete":' .. tostring(finished and not limited) .. ',"expires":' .. quoted(expiry)
        .. ',"selected_key":' .. quoted(item and item.key or '') .. ',"label":' .. quoted(item and bounded(item.name,800) or '') .. '}\n'
    local f=io.open(base .. 'campaign-discovery-status.json','w');if not f then error('Campaign status unavailable') end
    local written=f:write(line);local closed=f:close();if not written or closed==nil then error('Campaign status write failed') end
end
local function read_request()
    if not diagnostic then return end
    local raw=read_file('campaign-discovery-request.tsv',513)
    if type(raw)~='string' or #raw>512 or raw==last_request_raw then return end
    last_request_raw=raw
    local request_owner,request_session,wanted_generation,token,expires=raw:match('^WH2CAMCAP1\t([a-f0-9]+)\t([^\t\r\n]+)\t(%d+)\t([a-f0-9]+)\t([^\t\r\n]+)\n$')
    if not token or #token~=32 or request_owner~=owner or request_session~=session or seen_requests[token] then return end
    if request_count>=16 then return end
    request_count=request_count+1;seen_requests[token]=true;last_request=token
    if not stamp(expires) or utc()>expires or expires>expiry then result='rejected:expiry'
    elseif wanted_generation~=tostring(generation) then result='rejected:generation'
    else request_capture('read-only-client') end
end
local function stop(reason)
    polling=false;generation=generation+1;phase='cancelled';result=reason;finished=false;entries={};queue={}
    reader_stopped=true; menu=nil
    if real_timer then pcall(function() real_timer.unregister(timer_name) end); pcall(function() real_timer.unregister(watchdog_name) end) end
    core:remove_listener(timer_name); core:remove_listener(watchdog_name)
    for _,event in ipairs(rearm_events) do core:remove_listener('warhammer_campaign_readonly_rearm_' .. event) end
end
-- HUD reading mode (Shift+F2), like a screen reader's browse mode: while on,
-- the companion's standard keys (arrows, Home/End, letters, Enter) read HUD
-- items; while off, they stay with the game (arrows move the camera).
local reader_mode=false
-- 0.6.60: players start with HUD reading on once the map is read (a blind
-- player has no use for camera arrows first); Shift+F2 still switches.
local mode_chosen=false
local keys_owner,keys_seq,state_line,state_ticks,fast_ticks=nil,0,nil,0,0
local function publish_reader_state(force)
    local line='WH2READER1\t' .. session .. '\t' .. generation .. '\t' .. (reader_mode and '1' or '0') .. '\tcampaign\n'
    state_ticks=state_ticks+1
    -- The companion needs a heartbeat under 15 s old (written about every second).
    if not force and line==state_line and state_ticks<((reader_mode and auto_reader) and 1 or 10) then return end
    state_ticks=0
    local f=io.open(base .. 'reader-state.tsv','w'); if not f then return end
    f:write(line); f:close(); state_line=line
end
local function needs_confirmation(id)
    return id=='button_end_turn' or id=='button_raise' or id=='button_windows' or id:match('quit')~=nil or id:match('exit')~=nil or id:match('load')~=nil
        or id:match('abandon')~=nil or id:match('disband')~=nil or id:match('raze')~=nil
        or id:match('demolish')~=nil or id:match('dismantle')~=nil or id:match('recruit')~=nil
end
local activatable={button=true,tab=true,['list item']=true}
local function native_click(node)
    return pcall(function() node:SimulateLClick() end) -- the only native click in this module
end
-- The current item's element, re-found from a fresh root and checked; nil
-- (after speaking why) when the screen changed or it is unavailable.
local function fresh_node(item)
    local id=type(item.id)=='string' and item.id or ''
    local context=hud_context()
    if not context or context.root_address~=root_identity or context.layout_address~=layout_identity or context.count~=root_count then
        emit('{"kind":"activation-blocked","reason":"hud-changed"}'); menu=nil; cancel('hud-changed'); speak('The screen changed. Reading it again.'); return nil
    end
    local node,reason=resolve(context.root,item.path or {},item.ids or {})
    local leaf_ok,leaf=false,nil
    if node then leaf_ok,leaf=read(function() local v=node:Id(); return v end) end
    if not node or not leaf_ok or leaf~=id then
        emit('{"kind":"activation-blocked","reason":' .. quoted(node and 'identity' or tostring(reason)) .. '}')
        menu=nil; cancel('target-changed'); speak('The screen changed. Reading it again.'); return nil
    end
    local _,interactive=read(function() local v=node:IsInteractive(); return v end)
    local _,state=read(function() local v=node:CurrentState(); return v end)
    if interactive~=true or state=='inactive' or state=='locked' or state=='disabled' or state=='not_owned' then
        emit('{"kind":"activation-blocked","reason":' .. quoted('state:' .. tostring(state) .. ':' .. tostring(interactive)) .. '}')
        speak(item.name .. ' is unavailable.'); return nil
    end
    return node
end
local function find_named(parent,name,max_depth)
    local level={parent}
    for _=1,max_depth do
        local next_level={}
        for _,node in ipairs(level) do
            local _,count=read(function() local v=node:ChildCount(); return v end)
            if type(count)=='number' then
                for i=0,math.min(count,64)-1 do
                    local _,address=read(function() local v=node:Find(i); return v end)
                    local ok,child=read(function() local v=UIComponent(address); return v end)
                    if ok and child then
                        local _,child_id=read(function() local v=child:Id(); return v end)
                        if child_id==name then return child end
                        next_level[#next_level+1]=child
                    end
                end
            end
        end
        if #next_level>600 then return nil end
        level=next_level
    end
end
-- The game closes the upgrade popup as soon as the mouse pointer is not over
-- it, so its options are read in the same moment it opens and offered as a
-- list; building reopens it and clicks the option in one step.
local function read_upgrades()
    local ok,root=read(function() local v=core:get_ui_root(); return v end)
    if not ok or not root then return nil end
    local popup=find_named(root,'construction_popup',1); if not popup then return nil end
    local slots=find_named(popup,'slot_parent',4); if not slots then return nil end
    local _,count=read(function() local v=slots:ChildCount(); return v end)
    if type(count)~='number' then return nil end
    local items={}
    for i=0,math.min(count,12)-1 do
        local _,address=read(function() local v=slots:Find(i); return v end)
        local ok_holder,holder=read(function() local v=UIComponent(address); return v end)
        local building
        if ok_holder and holder then
            local _,inner=read(function() local v=holder:Find(0); return v end)
            local ok_building,found=read(function() local v=UIComponent(inner); return v end)
            if ok_building then building=found end
        end
        if building then
            local _,key=read(function() local v=building:Id(); return v end)
            local _,state=read(function() local v=building:CurrentState(); return v end)
            if type(key)=='string' and key~='' then
                local option={id=key,name=building_label(key),role='button',states={},units={},value='',description='',
                    key='upgrade:' .. key,live_state=state,node=building}
                add_state(option,building_states[state] or '')
                local cost=state~='built' and find_named(building,'dy_num_points_required',3) or nil
                if cost then
                    local _,amount=read(function() local v=cost:GetStateText(); return v end)
                    local _,cost_state=read(function() local v=cost:CurrentState(); return v end)
                    if type(amount)=='string' and amount~='' then
                        add_state(option,'Population surplus cost ' .. clean(amount) .. (cost_state=='red' and ', not enough' or ''))
                    end
                end
                items[#items+1]=option
            end
        end
    end
    return #items>0 and items or nil
end
local function speak_option(position)
    local option=menu.items[position]
    local parts={option.name,option.role}
    for _,state in ipairs(option.states or {}) do parts[#parts+1]=state end
    parts[#parts+1]=position .. ' of ' .. #menu.items
    speak(table.concat(parts,', '))
end
local function menu_move(step)
    pending_confirm=nil
    local count=#menu.items
    if menu.index==0 then menu.index=step>0 and 1 or count else menu.index=((menu.index-1+step)%count)+1 end
    speak_option(menu.index)
end
local function open_upgrades(item,node)
    emit('{"kind":"activation-dispatch","id":' .. quoted(item.id) .. ',"name":' .. quoted(item.name) .. '}')
    if not native_click(node) then speak('Could not activate ' .. item.name .. '.'); return end
    local items=read_upgrades()
    emit('{"kind":"upgrades-read","found":' .. (items and #items or 0) .. '}')
    if not items then post_click=ticks+2; speak(item.name .. ' activated.'); return end
    items[#items+1]={name='Close upgrades',role='button',states={},key='upgrade:close',close=true}
    menu={owner=item,items=items,index=0}
    local first=1
    for position,option in ipairs(items) do if option.live_state=='normal' then first=position; break end end
    speak('Upgrades for ' .. item.name .. ', ' .. (#items-1) .. ' options.')
    menu.index=first; speak_option(first)
end
local function menu_activate()
    local option=menu.items[menu.index]
    if not option then return end
    if option.close then menu=nil; pending_confirm=nil; speak('Upgrades closed.'); browse(0,false); return end
    if option.live_state~='normal' then speak(option.name .. ' is unavailable.'); return end
    if not (pending_confirm and pending_confirm.key==option.key and ticks<=pending_confirm.until_tick) then
        pending_confirm={key=option.key,until_tick=ticks+10}
        speak('Build ' .. option.name .. '? Press Enter again to confirm.'); return
    end
    pending_confirm=nil
    local owner=menu.owner
    local node=fresh_node(owner); if not node then menu=nil; return end
    -- Reopen the popup and choose the option in the same moment.
    if not native_click(node) then menu=nil; speak('Could not open the upgrades.'); return end
    local target
    for _,fresh in ipairs(read_upgrades() or {}) do if fresh.id==option.id then target=fresh end end
    menu=nil
    if not target or target.live_state~='normal' then
        emit('{"kind":"activation-blocked","reason":"upgrade-changed"}')
        speak('The upgrades changed. Reading the screen again.'); post_click=ticks+2; return
    end
    emit('{"kind":"activation-dispatch","id":' .. quoted(option.id) .. ',"name":' .. quoted(option.name) .. '}')
    local clicked=native_click(target.node)
    speak(clicked and ('Building ' .. option.name .. '.') or ('Could not build ' .. option.name .. '.'))
    post_click=ticks+2
end
-- Lords, settlements and movement (owner, November 1): F6 switches between a
-- lord and his settlement, Shift+F6 goes to the next lord, F7 lists places the
-- selected lord can move to. Selecting clicks a row in the game's own Lords &
-- Heroes or Provinces list, as a player would; a move is the game's own move
-- order through its command queue. Attacks are not offered yet.
local selected_cqi,selected_region -- the game's current selection (its events)
local last_lord_cqi -- the last character selected; F7 falls back to him
local pending_select -- a list row to click once the game has opened the list
local moving -- the lord last ordered to move, watched until he stops
local fast_count=0
local function campaign_game()
    local ok,value=pcall(function() return cm end)
    if ok and type(value)=='table' then return value end
end
local function localised(key)
    if type(key)~='string' or key=='' then return nil end
    local ok,value=read(function() local v=effect.get_localised_string(key); return v end)
    if ok and type(value)=='string' then value=clean(value); if value~='' then return value end end
end
local function list_items(list)
    local items={}
    local ok,count=read(function() local v=list:num_items(); return v end)
    if not ok or type(count)~='number' then return items end
    for i=0,math.min(count,1024)-1 do
        local got,item=read(function() local v=list:item_at(i); return v end)
        if got and item then items[#items+1]=item end
    end
    return items
end
local function player_faction()
    local game=campaign_game(); if not game then return nil,'Not available here.' end
    local ok_mp,mp=read(function() local v=game:is_multiplayer(); return v end)
    if not ok_mp or mp~=false then return nil,'Not available in multiplayer.' end
    local ok,faction=read(function() local v=game:get_local_faction(true); return v end)
    if not ok or type(faction)=='boolean' or not faction then return nil,'Not available here.' end
    return faction,nil,game
end
local function position(object)
    local ok,x=read(function() local v=object:logical_position_x(); return v end)
    local ok2,y=read(function() local v=object:logical_position_y(); return v end)
    if ok and ok2 and type(x)=='number' and type(y)=='number' then return x,y end
end
local function distance(ax,ay,bx,by) local dx,dy=ax-bx,ay-by; return math.sqrt(dx*dx+dy*dy) end
local function percent(value) return type(value)=='number' and math.floor(value+0.5) or nil end
local function lord_name(char)
    local _,fore=read(function() local v=char:get_forename(); return v end)
    local _,sur=read(function() local v=char:get_surname(); return v end)
    local first,last=localised(fore),localised(sur)
    if first and last then return first .. ' ' .. last,first end
    return first or last or 'Lord',first or last or 'Lord'
end
-- The player's lords who lead an army (not garrisons), faction leader first.
local function player_lords(faction)
    local lords={}
    local ok,list=read(function() local v=faction:character_list(); return v end)
    if not ok or not list then return lords end
    local _,leader=read(function() local v=faction:faction_leader(); return v end)
    local _,leader_cqi=read(function() local v=leader:cqi(); return v end)
    for _,char in ipairs(list_items(list)) do
        local _,general=read(function() local v=char:character_type('general'); return v end)
        local _,army=read(function() local v=char:has_military_force(); return v end)
        local _,citizens=read(function() local v=army==true and char:military_force():is_armed_citizenry(); return v end)
        local _,cqi=read(function() local v=char:cqi(); return v end)
        if general==true and army==true and citizens~=true and type(cqi)=='number' then
            local full,first=lord_name(char)
            lords[#lords+1]={char=char,cqi=cqi,name=full,short=first,leader=cqi==leader_cqi}
        end
    end
    table.sort(lords,function(a,b) if a.leader~=b.leader then return a.leader end; return a.cqi<b.cqi end)
    return lords
end
local function region_place(region)
    local _,settlement=read(function() local v=region:settlement(); return v end)
    local x,y
    if settlement then x,y=position(settlement) end
    return {region=region,settlement=settlement,x=x,y=y}
end
local function region_details(info)
    local region=info.region
    local _,key=read(function() local v=region:name(); return v end)
    local _,province=read(function() local v=region:province_name(); return v end)
    info.key,info.province=key,province
    info.name=localised('regions_onscreen_' .. tostring(key)) or tostring(key)
    return info
end
local function region_info(region) return region_details(region_place(region)) end
local function owned_regions(faction)
    local ok,list=read(function() local v=faction:region_list(); return v end)
    local regions={}
    for _,region in ipairs(ok and list and list_items(list) or {}) do regions[#regions+1]=region_info(region) end
    return regions
end
local function owner_label(info,faction)
    local _,abandoned=read(function() local v=info.region:is_abandoned(); return v end)
    if abandoned==true then return 'ruins','ruins' end
    local _,owner=read(function() local v=info.region:owning_faction(); return v end)
    local _,owner_key=read(function() local v=owner:name(); return v end)
    local _,mine=read(function() local v=faction:name(); return v end)
    if type(owner_key)~='string' then return 'unknown owner','other' end
    if owner_key==mine then return 'yours','own' end
    local _,war=read(function() local v=faction:at_war_with(owner); return v end)
    local name=localised('factions_screen_name_' .. owner_key) or 'another faction'
    if war==true then return name .. ', at war','enemy' end
    return name,'other'
end
local function lord_summary(lord)
    local parts={lord.name}
    local _,units=read(function() local v=lord.char:military_force():unit_list():num_items(); return v end)
    if type(units)=='number' then parts[#parts+1]=units .. (units==1 and ' unit' or ' units') end
    local _,ap=read(function() local v=lord.char:action_points_remaining_percent(); return v end)
    ap=percent(ap)
    if ap then parts[#parts+1]=ap==0 and 'no movement left' or (ap .. ' percent movement') end
    return table.concat(parts,', ') .. '.'
end
local function ui_path(names)
    local ok,node=read(function() local v=core:get_ui_root(); return v end)
    if not ok or not node then return nil end
    for _,step in ipairs(names) do node=find_named(node,step[1],step[2]); if not node then return nil end end
    return node
end
local function shown(node) local ok,value=read(function() local v=node:Visible(); return v end); return ok and value==true end
local function row_name(text) return type(text)=='string' and clean(text) or '' end
-- Every descendant (to max_depth) whose ID passes wanted: list rows can sit
-- inside sections (Provinces: your / other provinces), and a long list has
-- more rows than find_named looks at.
local function find_rows(parent,wanted,max_depth)
    local found,level,seen={},{parent},0
    for _=1,max_depth do
        local next_level={}
        for _,node in ipairs(level) do
            local _,count=read(function() local v=node:ChildCount(); return v end)
            for i=0,math.min(type(count)=='number' and count or 0,512)-1 do
                seen=seen+1
                if seen>4000 then return found end
                local _,address=read(function() local v=node:Find(i); return v end)
                local ok,child=read(function() local v=UIComponent(address); return v end)
                if ok and child then
                    local _,id=read(function() local v=child:Id(); return v end)
                    if type(id)=='string' and wanted(id) then found[#found+1]={row=child,id=id}
                    else next_level[#next_level+1]=child end
                end
            end
        end
        level=next_level
        if #level==0 then break end
    end
    return found
end
-- Clicks the target's row when its list is open: 'clicked', 'closed',
-- 'missing' or 'ambiguous'. A lord's row is found by his full name; by his
-- first name only when exactly one row has it (rows may show only that).
local function click_row(target)
    local dropdown=target.kind=='lord' and 'units_dropdown' or 'regions_dropdown'
    local panel=ui_path({{'layout',1},{'radar_things',1},{dropdown,2},{'panel',1}})
    if not panel or not shown(panel) then return 'closed' end
    local full,short={},{}
    if target.kind=='settlement' then
        -- Province rows sit inside sections (your provinces, others) of the
        -- list (live 0.6.68): found by ID anywhere in the panel.
        local wanted='row_entry_' .. tostring(target.province)
        full=find_rows(panel,function(id) return id==wanted end,8)
    else
        -- Lord rows likewise, wherever they sit (lords and heroes may be in
        -- sections, as provinces are).
        for _,found in ipairs(find_rows(panel,function(id) return id:sub(1,14)=='character_row_' end,8)) do
            local label=find_named(found.row,'dy_character_name',3)
            local _,text=read(function() local v=label and label:GetStateText(); return v end)
            text=row_name(text)
            if text~='' and text==target.name then full[#full+1]=found
            elseif text~='' and text==target.short then short[#short+1]=found end
        end
    end
    local found
    if #full==1 then found=full[1] elseif #full==0 and #short==1 then found=short[1]
    elseif #full>1 or #short>1 then return 'ambiguous' end
    if not found then return 'missing' end
    local _,interactive=read(function() local v=found.row:IsInteractive(); return v end)
    if not shown(found.row) or interactive~=true then return 'missing' end
    emit('{"kind":"activation-dispatch","id":' .. quoted(found.id) .. ',"name":' .. quoted(target.name) .. ',"source":"select"}')
    if not native_click(found.row) then return 'missing' end
    return 'clicked'
end
-- Model reads and orders run on the game's own timer, as the game's scripts
-- do: one repeating game-timer callback, registered once at the first tick,
-- runs the jobs the reader queues. Live, the game ignored orders made from
-- the reader's timer; it froze while the reader's timer read the model during
-- a selection or a march, and again right after a game timer was registered
-- from inside the reader's timer. UI clicks stay on the reader's timer.
-- Without the game timer (tests), jobs run at once.
local model_jobs,model_pump_on,model_pump_tick,model_wait_tick={},false,nil,nil
local function model_pump()
    if reader_stopped then model_jobs={}; return end
    model_pump_tick=ticks
    for _=1,4 do
        local job=table.remove(model_jobs,1)
        if not job then break end
        job()
    end
    if not model_jobs[1] then model_wait_tick=nil end
end
local function model_call(fn)
    local function run()
        local ok,err=pcall(fn)
        if not ok then
            pcall(function() emit('{"kind":"command-error","action":"model","error":' .. quoted(bounded(tostring(err),300)) .. '}') end)
            menu=nil; pending_select=nil; speak('Could not do that.')
        end
    end
    if not model_pump_on then run(); return end
    if #model_jobs>=16 then speak('The game is busy. Try again.'); return end
    model_jobs[#model_jobs+1]=run
    model_wait_tick=model_wait_tick or ticks
end
local function select_failed(target)
    speak('Could not find ' .. target.name .. ' in the ' .. (target.kind=='lord' and 'Lords' or 'Provinces') .. ' list.')
end
local function selected(target)
    if target.kind=='lord' then selected_cqi,selected_region,last_lord_cqi=target.cqi,nil,target.cqi else selected_cqi,selected_region=nil,target.key end
    speak(target.summary)
    post_click=ticks+2
end
-- On the reader's timer: click the target's row, opening its list first.
local function select_step()
    local pending=pending_select; if not pending then return end
    local target=pending.target
    local result=click_row(target)
    if result=='clicked' then pending_select=nil; selected(target); return end
    if result=='ambiguous' then
        pending_select=nil
        speak('More than one lord is called ' .. target.short .. '. Choose him in the Lords & Heroes list.'); return
    end
    if not pending.until_fast then
        pending.until_fast=fast_count+30
        if result=='closed' then
            local id=target.kind=='lord' and 'tab_units' or 'tab_regions'
            local tab=ui_path({{'layout',1},{id,3}})
            local _,interactive=read(function() local v=tab and tab:IsInteractive(); return v end)
            if tab and shown(tab) and interactive==true and native_click(tab) then
                emit('{"kind":"activation-dispatch","id":' .. quoted(id) .. ',"source":"select"}'); return
            end
        end
        pending_select=nil; select_failed(target); return
    end
    if fast_count>=pending.until_fast then pending_select=nil; select_failed(target) end
end
local function settlement_target(info)
    local province=localised('provinces_onscreen_' .. tostring(info.province))
    return {kind='settlement',key=info.key,province=info.province,name=info.name,summary=info.name .. (province and (', ' .. province) or '') .. '.'}
end
local function lord_target(lord) return {kind='lord',cqi=lord.cqi,name=lord.name,short=lord.short,summary=lord_summary(lord)} end
local function choose(target) pending_confirm=nil; menu=nil; pending_select={target=target} end
-- In the game's callback: decide what F6 / Shift+F6 selects.
local function switch_selection(next_lord)
    local faction,why=player_faction(); if not faction then speak(why); return end
    local lords=player_lords(faction)
    local current
    for place,lord in ipairs(lords) do if lord.cqi==selected_cqi then current=place end end
    if next_lord then
        if #lords==0 then speak('You have no lords with armies.'); return end
        choose(lord_target(lords[current and (current%#lords)+1 or 1])); return
    end
    if current then
        -- From a lord to his settlement: the one he stands in, else the nearest of yours.
        local lord=lords[current]
        local regions=owned_regions(faction)
        if #regions==0 then speak('You have no settlements.'); return end
        local x,y=position(lord.char)
        local _,here=read(function() local v=lord.char:has_region() and lord.char:region():name(); return v end)
        local best,best_distance
        for _,info in ipairs(regions) do
            local d=(info.key==here) and -1 or (x and info.x and distance(x,y,info.x,info.y)) or math.huge
            if not best_distance or d<best_distance then best,best_distance=info,d end
        end
        choose(settlement_target(best)); return
    end
    if #lords==0 then speak('You have no lords with armies.'); return end
    -- From a settlement (or nothing) to the nearest lord, else the faction leader.
    local chosen=lords[1]
    if selected_region then
        for _,info in ipairs(owned_regions(faction)) do
            if info.key==selected_region and info.x then
                local best_distance
                for _,lord in ipairs(lords) do
                    local x,y=position(lord.char)
                    local d=x and distance(x,y,info.x,info.y)
                    if d and (not best_distance or d<best_distance) then chosen,best_distance=lord,d end
                end
            end
        end
    end
    choose(lord_target(chosen))
end
-- In the game's callback: the places the selected lord can move to.
local function open_moves()
    local faction,why,game=player_faction(); if not faction then speak(why); return end
    local _,turn=read(function() local v=game:is_local_players_turn(); return v end)
    if turn==false then speak('Wait for your turn.'); return end
    -- The selected lord; else the last one selected (the game may have
    -- selected his settlement, for example after he joined its garrison).
    local lord,last
    for _,candidate in ipairs(player_lords(faction)) do
        if candidate.cqi==selected_cqi then lord=candidate end
        if candidate.cqi==last_lord_cqi then last=candidate end
    end
    lord=lord or last
    if not lord then speak('Select a lord first: press F6.'); return end
    local lx,ly=position(lord.char)
    if not lx then speak('Could not read where ' .. lord.name .. ' is.'); return end
    local _,ap=read(function() local v=lord.char:action_points_remaining_percent(); return v end)
    ap=percent(ap) or 0
    local _,in_settlement=read(function() local v=lord.char:in_settlement(); return v end)
    local ok,list=read(function() local v=game:model():world():region_manager():region_list(); return v end)
    local places={}
    for _,region in ipairs(ok and list and list_items(list) or {}) do
        local info=region_place(region)
        if info.x and info.settlement then info.distance=distance(lx,ly,info.x,info.y); places[#places+1]=info end
    end
    table.sort(places,function(a,b) return a.distance<b.distance end)
    local items,reachable={},0
    for order,info in ipairs(places) do
        if #items>=15 then break end
        if not (in_settlement==true and info.distance<2) then
            region_details(info)
            local label,kind=owner_label(info,faction)
            local reach=false
            if ap>0 then
                local got,value=read(function() local v=game:model():character_can_reach_settlement(lord.char,info.settlement); return v end)
                reach=got and value==true
            end
            if reach then reachable=reachable+1 end
            items[#items+1]={name=info.name,role='button',states={label,reach and 'this turn' or 'more than a turn'},
                key='move:' .. tostring(info.key),place=info,kind=kind,reach=reach,order=order}
        end
    end
    if #items==0 then speak('No places found.'); return end
    -- Places reachable this turn first, nearest first in each group.
    table.sort(items,function(a,b) if a.reach~=b.reach then return a.reach end; return a.order<b.order end)
    items[#items+1]={name='Close',role='button',states={},key='move:close',close=true}
    pending_confirm=nil
    menu={kind='move',owner=lord,items=items,index=1}
    speak('Move ' .. lord.name .. ', ' .. (ap==0 and 'no movement left' or (ap .. ' percent movement')) .. ', '
        .. reachable .. ' of ' .. (#items-1) .. ' places this turn.')
    speak_option(1)
end
-- A command on the game's script interface, or nil (indexing a missing one may throw).
local function game_command(game,name)
    local ok,value=pcall(function() return rawget(game,'game_interface')[name] end)
    if ok then return value end
    return nil
end
-- Live diagnosis: the lord's state when an order is given.
local function log_lord_state(game,char)
    local fields={}
    for _,name in ipairs({'is_at_sea','in_settlement','has_garrison_residence','is_embedded_in_military_force','action_points_remaining_percent','has_military_force'}) do
        local ok,value=read(function() local v=char[name](char); return v end)
        fields[#fields+1]=quoted(name) .. ':' .. quoted(ok and tostring(value) or 'error')
    end
    local _,turn=read(function() local v=game:whose_turn_is_it(); return v end)
    local _,mine=read(function() local v=game:get_local_faction_name(true); return v end)
    fields[#fields+1]='"turn":' .. quoted(tostring(turn)) .. ',"local":' .. quoted(tostring(mine))
    emit('{"kind":"lord-state",' .. table.concat(fields,',') .. '}')
end
local function order(method,cqi,a,b)
    local game=campaign_game(); local lookup='character_cqi:' .. cqi
    local ok,err=pcall(function()
        pcall(function() game:enable_movement_for_character(lookup) end)
        if method=='join_garrison' then game:join_garrison(lookup,'settlement:' .. a)
        else game:move_to(lookup,a,b,true) end
    end)
    emit('{"kind":"order-run","method":' .. quoted(method) .. ',"cqi":' .. cqi .. ',"target":' .. quoted(tostring(a) .. (b and (',' .. b) or ''))
        .. ',"ok":' .. tostring(ok) .. ',"error":' .. quoted(ok and '' or bounded(tostring(err),300)) .. '}')
    return ok,err
end
-- In the game's callback: give the confirmed move order and start watching.
local function give_order(lord,option)
    local faction,why,game=player_faction(); if not faction then speak(why); return end
    local _,char=read(function() local v=game:get_character_by_cqi(lord.cqi); return v end)
    local x,y
    if char then x,y=position(char) end
    if not x then speak(lord.name .. ' is no longer available.'); return end
    local sx,sy=option.place.x,option.place.y
    -- Your own settlement: the game's command for entering it, when it has one.
    local method='move_to'
    if option.kind=='own' and type(game_command(game,'join_garrison'))=='function' then method='join_garrison' end
    emit('{"kind":"move-order","method":' .. quoted(method) .. ',"cqi":' .. lord.cqi .. ',"region":' .. quoted(tostring(option.place.key))
        .. ',"x":' .. sx .. ',"y":' .. sy .. ',"from_x":' .. x .. ',"from_y":' .. y .. '}')
    if diagnostic then pcall(log_lord_state,game,char) end
    local ordered
    if method=='join_garrison' then ordered=order('join_garrison',lord.cqi,option.place.key) end
    if not ordered then ordered=order('move_to',lord.cqi,sx,sy) end
    if not ordered then speak('Could not move ' .. lord.name .. '.'); return end
    speak((option.reach and 'Moving to ' or 'Moving toward ') .. option.name .. '.')
    moving={cqi=lord.cqi,name=lord.name,dest=option.name,x=sx,y=sy,x0=x,y0=y,last_x=x,last_y=y,still=0,started=ticks,moved=false,retried=false}
end
-- On the reader's timer: the move list's Enter (asks first).
local function move_activate(option)
    if option.close then menu=nil; pending_confirm=nil; speak('Move list closed.'); browse(0,false); return end
    if option.kind=='enemy' then speak('Attacking is not supported yet.'); return end
    local lord=menu.owner
    if not (pending_confirm and pending_confirm.key==option.key and ticks<=pending_confirm.until_tick) then
        pending_confirm={key=option.key,until_tick=ticks+10}
        speak('Move ' .. lord.name .. ' to ' .. option.name .. '? Press Enter again to confirm.'); return
    end
    pending_confirm=nil; menu=nil
    model_call(function() give_order(lord,option) end)
end
-- In the game's callback: say where the lord stopped (arrived, or how far he got).
local function watch_moving()
    if not moving then return end
    local game=campaign_game()
    local _,char=read(function() local v=game:get_character_by_cqi(moving.cqi); return v end)
    local x,y
    if char then x,y=position(char) end
    if not x then moving=nil; return end
    if x~=moving.x0 or y~=moving.y0 then moving.moved=true end
    if x==moving.last_x and y==moving.last_y then moving.still=moving.still+1 else moving.still=0 end
    moving.last_x,moving.last_y=x,y
    local elapsed=ticks-moving.started
    if elapsed<=12 then emit('{"kind":"move-watch","x":' .. x .. ',"y":' .. y .. ',"tick":' .. elapsed .. '}') end
    if not moving.moved and elapsed>=3 and not moving.retried then
        -- A settlement's own spot may not be a place an army can stand: aim
        -- just outside it, on the side the lord comes from.
        moving.retried=true
        local d=distance(moving.x0,moving.y0,moving.x,moving.y)
        if d>3 then
            order('move_to',moving.cqi,math.floor(moving.x+(moving.x0-moving.x)/d*2+0.5),math.floor(moving.y+(moving.y0-moving.y)/d*2+0.5))
        end
        return
    end
    if not moving.moved and elapsed>=9 then speak(moving.name .. ' did not move.'); moving=nil; return end
    if (moving.moved and moving.still>=2) or elapsed>=60 then
        local _,ap=read(function() local v=char:action_points_remaining_percent(); return v end)
        ap=percent(ap)
        if distance(x,y,moving.x,moving.y)<=3 then speak(moving.name .. ' arrived at ' .. moving.dest .. '.')
        else speak(moving.name .. ' stopped on the way to ' .. moving.dest .. (ap and (', ' .. (ap==0 and 'no movement left' or (ap .. ' percent movement left'))) or '') .. '.') end
        moving=nil
    end
end
local function log_game_api()
    local names={}
    pcall(function()
        local index=getmetatable(rawget(campaign_game(),'game_interface')).__index
        if type(index)=='table' then for name in pairs(index) do if type(name)=='string' then names[#names+1]=name end end end
    end)
    local game=campaign_game()
    for _,name in ipairs({'move_to','join_garrison','leave_garrison','attack_region','attack','teleport_to','enable_movement_for_character',
        'select_character','select_settlement','scroll_camera_to_character','scroll_camera_to_settlement','set_camera_position'}) do
        names[#names+1]=name .. '=' .. type(game and game_command(game,name))
    end
    pcall(function() for name in pairs(CampaignUI) do if type(name)=='string' then names[#names+1]='CampaignUI.' .. name end end end)
    table.sort(names)
    emit('{"kind":"game-api","count":' .. #names .. ',"names":' .. quoted(bounded(table.concat(names,' '),60000)) .. '}')
end
-- An error in the lords / moves commands never stops the reader: logged, said.
local function guarded(action,fn,...)
    local ok,err=pcall(fn,...)
    if not ok then
        emit('{"kind":"command-error","action":' .. quoted(action) .. ',"error":' .. quoted(bounded(tostring(err),300)) .. '}')
        menu=nil; pending_select=nil; speak('Could not do that.')
    end
end
local function activate_current()
    if menu then
        if menu.kind=='move' then guarded('activate',move_activate,menu.items[menu.index]) else menu_activate() end
        return
    end
    if not finished or #entries==0 or index==0 then speak('No item selected.'); return end
    local item=entries[index]
    local id=type(item.id)=='string' and item.id or ''
    local role=entry_role(item)
    if not activatable[role] or item.read_only or (role=='button' and id:sub(1,5)=='sort_') then speak('Not supported yet.'); return end
    local node=fresh_node(item); if not node then return end
    if item.settlement then open_upgrades(item,node); return end
    if (item.confirm or needs_confirmation(id)) and not (pending_confirm and pending_confirm.key==item.key and ticks<=pending_confirm.until_tick) then
        pending_confirm={key=item.key,until_tick=ticks+10}
        speak((item.confirm or item.name) .. '? Press Enter again to confirm.'); return
    end
    pending_confirm=nil
    emit('{"kind":"activation-dispatch","id":' .. quoted(id) .. ',"name":' .. quoted(item.name) .. '}')
    local clicked=native_click(node)
    speak(clicked and (item.name .. ' activated.') or ('Could not activate ' .. item.name .. '.'))
    -- Re-read once even if the change is deeper than the panel watch (a list opening).
    if clicked then post_click=ticks+2 end
end
local function speak_current()
    if not finished then
        if phase~='waiting' and phase~='scanning' then request_capture('keyboard') end
        return
    end
    browse(index==0 and 1 or 0,false)
end
-- Only known notification controls: never a generic Close in another panel.
local function dismiss_notification()
    pending_confirm=nil
    if not finished or limited then speak('Notifications are still being read. Try again.'); return end
    local target,priority,layer,top_layer=nil,0,-1,-1
    local notices={}
    for _,item in ipairs(entries) do
        if entry_role(item)=='heading' and (item.name=='How They Play' or item.name=='Mission Issued!') then
            notices[item.path[1]]=item
        end
    end
    for _,item in ipairs(entries) do
        local advice,notification=false,false
        for _,id in ipairs(item.ids or {}) do
            if id=='advice_interface' then advice=true end
            if id=='notification_frame' then notification=true end
        end
        local rank=(notices[item.path[1]] and item.id=='button_accept') and 3
            or (advice and item.id=='button_close') and 2
            or (notification and item.id=='button_skip') and 1 or 0
        local level=item.path and item.path[1] or -1
        if level>top_layer then top_layer=level end
        if rank>priority or (rank>0 and rank==priority and level>layer) then target,priority,layer=item,rank,level end
    end
    if not target or layer<top_layer then speak('No dismissible notification.'); return end
    local node=fresh_node(target); if not node then return end
    if priority==3 then
        -- Accept is safe only while the same informational notice is present.
        local title=notices[layer]
        local context=hud_context()
        local heading=context and resolve(context.root,title.path,title.ids)
        local ok,text=read(function() return heading:GetStateText() end)
        if not ok or clean(text)~=title.name then speak('The screen changed. Press again.'); return end
    end
    local clicked=native_click(node)
    speak(clicked and 'Notification dismissed.' or 'Could not dismiss the notification.')
    if clicked then finished=false; post_click=ticks+2 end -- no repeat click on a stale capture
end
local function key_action(action)
    if action=='dismiss' then dismiss_notification(); return end
    if action=='lords' or action=='nextlord' then guarded(action,model_call,function() switch_selection(action=='nextlord') end); return end
    if action=='moves' then guarded(action,model_call,open_moves); return end
    if menu then
        if action=='next' or action=='previous' then menu_move(action=='next' and 1 or -1)
        elseif action=='first' or action=='last' then menu.index=0; menu_move(action=='first' and 1 or -1)
        elseif action=='activate' then activate_current()
        elseif action=='back' then
            local kind=menu.kind; menu=nil; pending_confirm=nil
            speak(kind=='move' and 'Move list closed.' or 'Upgrades closed.'); browse(0,false)
        elseif #action==8 and action:sub(1,7)=='letter:' then
            local letter=action:sub(8,8)
            for offset=1,#menu.items do
                local candidate=((menu.index-1+offset)%#menu.items)+1
                if string.lower(menu.items[candidate].name:sub(1,1))==letter then menu.index=candidate-1; menu_move(1); return end
            end
        end
        return
    end
    if action=='next' or action=='previous' then
        if finished then browse(action=='next' and 1 or -1,false) else speak_current() end
    elseif action=='first' or action=='last' then
        if finished then index=0; browse(action=='first' and 1 or -1,false) else speak_current() end
    elseif action=='activate' then activate_current()
    elseif #action==8 and action:sub(1,7)=='letter:' then
        if not finished or #entries==0 then speak_current(); return end
        local letter=action:sub(8,8)
        for offset=1,#entries do
            local candidate=((index-1+offset)%#entries)+1
            if string.lower(entries[candidate].name:sub(1,1))==letter then index=candidate-1; browse(1,false); return end
        end
    end
end
local function poll_keys()
    local raw=read_file('keys.tsv',4097)
    if type(raw)~='string' or #raw>4096 then return end
    local lines={}
    for line in raw:gmatch('([^\n]*)\n') do lines[#lines+1]=line end
    local header_owner,header_session=(lines[1] or ''):match('^WH2KEYS1\t([^\t]+)\t([^\t]+)\t[^\t]+$')
    if not header_owner then return end
    local events,newest={},0
    for position=2,math.min(#lines,33) do
        local number,action=lines[position]:match('^(%d+)\t([a-z:]+)$')
        number=tonumber(number)
        if number then events[#events+1]={seq=number,action=action}; if number>newest then newest=number end end
    end
    if header_owner~=keys_owner then keys_owner,keys_seq=header_owner,newest; return end -- skip any backlog
    if header_session~=session then keys_seq=math.max(keys_seq,newest); return end
    table.sort(events,function(a,b) return a.seq<b.seq end)
    local handled=0
    for _,event in ipairs(events) do
        if event.seq>keys_seq and handled<8 then
            keys_seq=event.seq; handled=handled+1
            if event.action=='dismiss' and (lines[1] or ''):match('\t([^\t]+)$')~=tostring(generation) then
                speak('The screen changed. Press again.')
            else key_action(event.action) end
        end
    end
    if newest>keys_seq then keys_seq=newest end
end
local live_ids={Text='Advisor: ',dy_notification=''}
local function watch_live_text()
    if not finished then return end
    local context=hud_context()
    if not context or context.root_address~=root_identity or context.layout_address~=layout_identity then return end
    for _,entry in ipairs(entries) do
        local prefix=live_ids[entry.id]
        if prefix and entry.path then
            local node=resolve(context.root,entry.path,entry.ids or {})
            if node then
                local ok,raw=read(function() local v=node:GetStateText(); return v end)
                local now=ok and type(raw)=='string' and clean(bounded(raw,4000)) or ''
                if now~='' and now~=entry.name then
                    entry.name=now
                    emit('{"kind":"live-text","id":' .. quoted(entry.id) .. '}')
                    speak(prefix .. now)
                end
            end
        end
    end
end
local function tick()
    if not polling then return end
    tick_count=tick_count+1
    last_tick_clock=game_seconds()
    local ok,err=pcall(function()
        -- Capture work keeps its one-second pace; keys are polled every 100 ms
        -- while HUD reading is on.
        fast_ticks=fast_ticks+1
        local slow
        if repeating then slow=fast_ticks>=10 else slow=not reader_mode or auto_reader or fast_ticks>=10 end
        if slow then
            fast_ticks=0
            ticks=ticks+1
            if not lease_active() or (diagnostic and ticks>1800) then stop('lease-ended');publish_status();return end
            read_request()
            if phase=='waiting' then waiting_step() elseif phase=='scanning' then
                -- Players get a re-read in about three seconds; the developer mode keeps one page a second.
                for _=1,(diagnostic and 1 or 3) do if phase=='scanning' then page_read() end end
            end
            if phase=='ready' or phase=='limited' then watch_live_text() end
            -- Jobs the game timer has not run for 3 s are dropped (said once).
            if model_wait_tick and ticks-model_wait_tick>3 then
                model_jobs={}; model_wait_tick=nil; pending_select=nil; moving=nil
                emit('{"kind":"model-stalled","last_pump":' .. tostring(model_pump_tick) .. '}')
                speak('The game is busy. Try again.')
            end
            -- One watch job at a time (a lost one is replaced after 5 s).
            if moving and (not moving.wait_tick or ticks-moving.wait_tick>5) then
                moving.wait_tick=ticks
                model_call(function() if moving then moving.wait_tick=nil; watch_moving() end end)
            end
            if (phase=='ready' or phase=='limited') and post_click and ticks>=post_click then
                post_click=nil; remember_entries(); refresh_announce=request_capture('after-activation')
            end
            -- Re-read automatically when the visible panels change and settle.
            if phase=='ready' or phase=='limited' or phase=='cancelled' then
                local context=phase~='cancelled' and hud_context() or nil
                local signature=context and panel_signature(context)
                -- Changed, and the same for two seconds (blinking never settles).
                local settled=signature and signature==last_signature
                last_signature=signature
                if phase=='cancelled' or (signature and signature~=captured_signature and settled) then
                    changed_ticks=changed_ticks+1
                    if changed_ticks>=2 then
                        changed_ticks=0
                        if phase~='cancelled' then
                            remember_entries()
                        end
                        refresh_announce=request_capture('auto-refresh')
                    end
                else changed_ticks=0 end
            end
            publish_status()
        end
        if verified_reader and not reader_mode then
            verified_reader=false; reader_mode=true; auto_reader=true; keys_owner=nil
            emit('{"kind":"reader-mode","on":true,"source":"verify-flag"}'); publish_reader_state(true)
        elseif not diagnostic and not mode_chosen and not reader_mode and finished then
            mode_chosen=true; reader_mode=true; keys_owner=nil
            emit('{"kind":"reader-mode","on":true,"source":"player-default"}'); publish_reader_state(true)
        end
        fast_count=fast_count+1
        if reader_mode then poll_keys() end
        if pending_select and not pcall(select_step) then pending_select=nil; speak('Could not do that.') end
        publish_reader_state(false)
        if polling and not repeating then real_timer.register_singleshot(timer_name,(reader_mode and not auto_reader) and 100 or 1000) end
    end)
    if not ok then
        stop('diagnostic-error');phase='error'
        pcall(function() emit('{"kind":"error","run":' .. run .. ',"detail":' .. quoted(type(err)=='string' and bounded(err,500) or type(err)) .. '}');publish_status() end)
    end
end
core:add_listener('warhammer_campaign_discovery_first_tick','FirstTickAfterWorldCreated',true,function()
    local ok,err=pcall(function()
        if polling then return end
        if not real_timer or type(real_timer.register_singleshot)~='function' or type(real_timer.unregister)~='function' then error('Campaign real_timer unavailable') end
        polling=true
        repeating=type(real_timer.register_repeating)=='function'
        core:add_listener(timer_name,'RealTimeTrigger',function(c) return c.string==timer_name end,tick,true)
        emit('{"kind":"session","version":' .. quoted(version) .. ',"session":' .. quoted(session) .. ',"read_only":true,"scheduler":"real_timer","os_clock":' .. tostring(game_seconds()~=nil) .. ',"timer":' .. quoted(repeating and 'repeating' or 'singleshot') .. '}')
        core:add_listener(watchdog_name,'RealTimeTrigger',function(c) return c.string==watchdog_name end,function()
            if not polling then return end
            pcall(function()
                if tick_count==watchdog_seen then
                    restart_reader_timer()
                    emit('{"kind":"timer-rearmed","ticks":' .. tick_count .. '}')
                end
            end)
            watchdog_seen=tick_count
            if not repeating then pcall(function() real_timer.register_singleshot(watchdog_name,3000) end) end
        end,true)
        for _,event in ipairs(rearm_events) do
            core:add_listener('warhammer_campaign_readonly_rearm_' .. event,event,true,function()
                if not polling then return end
                local now=game_seconds()
                local stalled
                if now and last_tick_clock then stalled=now-last_tick_clock>=2
                else stalled=tick_count==event_seen_ticks end -- no clock: two events with no tick between
                event_seen_ticks=tick_count
                if not stalled then return end
                last_tick_clock=now
                restart_reader_timer()
                pcall(function()
                    real_timer.unregister(watchdog_name)
                    if repeating then real_timer.register_repeating(watchdog_name,3000) else real_timer.register_singleshot(watchdog_name,3000) end
                end)
                pcall(function() emit('{"kind":"timer-rearmed","source":' .. quoted(event) .. '}') end)
            end,true)
        end
        -- The selection, for F6 / F7 (read from the game's own events).
        core:add_listener('warhammer_campaign_selection_character','CharacterSelected',true,function(context)
            pcall(function()
                local character=context:character()
                selected_cqi=character:cqi(); selected_region=nil
                -- The F7 fallback: only one of the player's lords with an army.
                local game=campaign_game()
                if game and character:faction():name()==game:get_local_faction_name(true)
                    and character:character_type('general') and character:has_military_force() then last_lord_cqi=selected_cqi end
            end)
        end,true)
        core:add_listener('warhammer_campaign_selection_settlement','SettlementSelected',true,function(context)
            pcall(function() selected_region=context:garrison_residence():region():name(); selected_cqi=nil end)
        end,true)
        -- The one repeating game timer for model jobs (registered here, at the
        -- first tick, never from inside a timer callback).
        local game=campaign_game()
        model_pump_on=game~=nil and pcall(function() game:repeat_callback(function() pcall(model_pump) end,0.2,'warhammer_access_model_jobs') end)
        emit('{"kind":"model-pump","on":' .. tostring(model_pump_on) .. '}')
        if diagnostic then pcall(log_game_api) end
        request_capture('first-tick');publish_status()
        if repeating then real_timer.register_repeating(timer_name,100); real_timer.register_repeating(watchdog_name,3000)
        else real_timer.register_singleshot(timer_name,1000); real_timer.register_singleshot(watchdog_name,3000) end
    end)
    if not ok then stop('scheduler-error');phase='error';pcall(function() emit('{"kind":"error","detail":' .. quoted(type(err)=='string' and err or type(err)) .. '}');publish_status() end) end
end,false)
core:add_ui_destroyed_callback(function() if polling then cancel('ui-destroyed');publish_status() end end)
core:add_listener('warhammer_campaign_readonly_keys','ShortcutTriggered',function(c)
    return c.string=='script_F2' or c.string=='script_F3' or c.string=='script_F4'
        or c.string=='script_shift_F2' or c.string=='script_shift_F3'
end,function(c)
    if not lease_active() then return end
    local ok,err=pcall(function()
        if c.string=='script_shift_F2' then
            reader_mode=not reader_mode; auto_reader=false; keys_owner=nil; mode_chosen=true -- a fresh mode never replays old keys
            publish_reader_state(true)
            speak(reader_mode and 'Reading HUD.' or 'Map controls.')
            if reader_mode then speak_current() end
            if polling and not repeating then pcall(function() real_timer.unregister(timer_name); real_timer.register_singleshot(timer_name,reader_mode and 100 or 1000) end) end
        elseif c.string=='script_shift_F3' then
            if phase~='waiting' and phase~='scanning' then request_capture('keyboard-refresh') end
            -- Also recovers a stopped reader timer.
            local now=game_seconds()
            if polling and (not repeating or not now or not last_tick_clock or now-last_tick_clock>=2) then restart_reader_timer() end
        elseif c.string=='script_F4' then activate_current()
        elseif menu then menu_move(c.string=='script_F2' and 1 or -1)
        elseif finished then browse(c.string=='script_F2' and 1 or -1,false)
        elseif phase~='waiting' and phase~='scanning' then request_capture('keyboard') end
        publish_status()
    end)
    if not ok then stop('keyboard-error');pcall(publish_status) end
end,true)
