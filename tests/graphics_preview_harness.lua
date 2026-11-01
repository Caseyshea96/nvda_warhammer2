-- Lua 5.1 fixtures reconstructed from the successful native 0.5.3 capture.
local real_io, real_time, real_date = io, os.time, os.date
local real_getenv = os.getenv
local fixture = dofile('tests/fixtures/frontend_menu_0_5_3.lua')
local graphics_fixture = dofile('tests/fixtures/graphics_basic_0_5_6.lua')
local captured_advanced_fixture = dofile('tests/fixtures/graphics_advanced_0_5_8.lua')
local windowed_fixture = dofile('tests/fixtures/graphics_basic_windowed_0_5_9.lua')
local lord_fixture = dofile('tests/fixtures/lord_discovery_synthetic.lua')
local graphics_key = 'tree.child2.child1.child0.child0.child2.child0.child1'
local nodes, listeners, files, dispatches, created, destroyed, ready, now, context_mode
local read_hook, click_hook, file_failure, speech_write_throw
local lord_write_failure
local automation_poll, automation_timer, automation_base, automation_status_failure, automation_timer_failure
local scenarios = 0
local probe_flag = false
local single_press = false -- tests of default single-press activation
local flat_lords = true -- 0.6.64: older Select Lord tests use the single list (lord-list-flat.flag)
local repeating_timer = false -- 0.6.64: the game's register_repeating is offered
local timer_registrations = 0
local keys_poll
local function build_nodes(layout)
    local result = {}
    for prefix, row in pairs(layout) do
        local n = {data = {}, children = {}, faults = {}, address = newproxy(), prefix = prefix}
        for k, v in pairs(row) do n.data[k] = v end
        local function read(self, method)
            if read_hook then read_hook(self, method) end
            if self.faults[method] == 'throw' then error('native read failure: ' .. method) end
            if self.faults[method] == 'function' then return function() end end
            if self.faults[method] == 'nil' then return nil end
            if method == 'Address' then return self.address end
            return self.data[method]
        end
        function n:Id() return read(self, 'Id') end
        function n:Visible() return read(self, 'Visible') end
        function n:IsInteractive() return read(self, 'IsInteractive') end
        function n:GetStateText() return read(self, 'GetStateText') end
        function n:GetTooltipText() return read(self, 'GetTooltipText') end
        function n:CurrentState() return read(self, 'CurrentState') end
        function n:ChildCount() return read(self, 'ChildCount') end
        function n:Address() return read(self, 'Address') end
        function n:Find(i) return self.children[i] end
        function n:SimulateLClick()
            dispatches[#dispatches+1] = self.prefix
            if click_hook then click_hook() end
        end
        result[prefix] = n
    end
    for prefix, n in pairs(result) do
        local parent, i = prefix:match('^(.*)%.child(%d+)$')
        if parent then result[parent].children[tonumber(i)] = n end
    end
    return result
end
local function start(mode, layout, enable_automation, setup_status_failure, environment_disappears, setup_timer_failure, initial_time)
    scenarios = scenarios + 1
    nodes, listeners, files, dispatches = {}, {}, {}, {}
    ready, now, context_mode = true, initial_time or 1000, mode or 'frontend'
    read_hook, click_hook, file_failure, speech_write_throw = nil, nil, nil, false
    lord_write_failure=false
    nodes = build_nodes(layout or fixture)
    automation_poll,automation_timer,automation_status_failure=nil,nil,setup_status_failure or false
    get_tm=function() error('Unavailable frontend model timer must not be used') end
    timer_manager=nil; automation_timer_failure=setup_timer_failure
    keys_poll=nil
    local function fire_timer(name)
        local listener=listeners[name .. '_real_timer']
        assert(listener and listener[1]=='RealTimeTrigger')
        local context={string=name}
        if listener[2](context) then listener[3](context) end
    end
    real_timer={
        unregister=function(name)
            if name=='warhammer_accessibility_keys' then keys_poll=nil; return end
            assert(name=='warhammer_accessibility_automation'); automation_poll=nil
        end,
        register_singleshot=function(name,interval)
            if name=='warhammer_accessibility_keys' then
                assert(not repeating_timer,'No single shot when a repeating timer exists')
                assert(interval==100)
                keys_poll=function() keys_poll=nil; fire_timer(name) end
                return
            end
            error('Automation timer requires a lease')
        end}
    timer_registrations=0
    if repeating_timer then
        real_timer.register_repeating=function(name,interval)
            assert(name=='warhammer_accessibility_keys' and interval==100)
            timer_registrations=timer_registrations+1
            keys_poll=function() fire_timer(name) end -- stays registered
        end
    end
    os.getenv=real_getenv
    automation_base=(real_getenv('LOCALAPPDATA') or '') .. '/JawsWarhammer2/'
    -- Most legacy scenarios exercise press-twice confirmation.
    if not single_press and context_mode=='frontend' then files[automation_base .. 'confirm-activations.flag']={'1'} end
    if environment_disappears then
        local lookups=0
        os.getenv=function(name)
            if name=='LOCALAPPDATA' then lookups=lookups+1; if lookups>2 then return nil end end
            return real_getenv(name)
        end
    end
    if probe_flag then files[automation_base .. 'string-find-probe.flag']={'1'} end
    if flat_lords and context_mode=='frontend' then files[automation_base .. 'lord-list-flat.flag']={'1'} end
    if enable_automation then
        local keys_timer=real_timer
        files[automation_base .. 'automation-enabled.tsv']={type(enable_automation)=='string' and enable_automation or ('WH2LEASE1\t' .. string.rep('a',32) .. '\t1060\n')}
        real_timer={
            unregister=function(name)
                if name=='warhammer_accessibility_keys' then return keys_timer.unregister(name) end
                assert(name=='warhammer_accessibility_automation'); automation_poll=nil
            end,
            register_singleshot=function(name,interval)
                if name=='warhammer_accessibility_keys' then return keys_timer.register_singleshot(name,interval) end
                assert(name=='warhammer_accessibility_automation' and interval==250)
                if automation_timer_failure then error('Fixture real timer registration failed') end
                automation_poll=function()
                    automation_poll=nil -- one-shot is consumed before the event callback
                    local listener=listeners[name .. '_real_timer']
                    assert(listener and listener[1]=='RealTimeTrigger')
                    local context={string=name}
                    if listener[2](context) then listener[3](context) end
                end
            end}
    end
    core = {
        is_frontend = function() return context_mode == 'frontend' end,
        is_campaign = function() return context_mode == 'campaign' end,
        is_battle = function() return context_mode == 'battle' end,
        is_ui_created = function() return ready end,
        get_ui_root = function() assert(ready); return nodes.tree end,
        add_ui_created_callback = function(_, cb) created = cb end,
        add_ui_destroyed_callback = function(_, cb) destroyed = cb end,
        add_listener = function(_, name, event, condition, cb) listeners[name] = {event, condition, cb} end,
        remove_listener = function(_,name) listeners[name]=nil end
    }
    UIComponent = function(value) assert(type(value)=='table' and value.prefix, 'invalid component'); return value end
    os.time = function() return math.floor((now+64)/128)*128 end -- observed WH2 epoch precision
    os.date = function(format) return real_date(format,now) end
    io = {open = function(path, mode)
        if lord_write_failure and path:find('native-ui-lord-discovery.jsonl',1,true) then return nil end
        if file_failure and path:find('native-ui-graphics-preview.log',1,true) then return nil end
        if mode == 'r' then
            if not files[path] then return nil end
            return {read=function(_,limit) return table.concat(files[path]):sub(1,limit) end,close=function() return true end}
        end
        if mode == 'w' then files[path] = {} end
        return {write = function(self, text)
            if automation_status_failure and path:find('automation-status.tsv',1,true) then error('fixture status write failure') end
            if speech_write_throw and (path:find('bridge.jsonl',1,true) or path:find('jaws_access.jsonl',1,true)) then
                speech_write_throw=false; error('fixture speech write exception')
            end
            files[path] = files[path] or {}; files[path][#files[path]+1] = text; return self end,
            close = function() return true end}
    end}
    effect = {trigger_shortcut = function() error('No shortcut dispatch permitted') end}
    dofile('diagnostics/graphics_preview.lua')
end
local function fire(event, context)
    for _, listener in pairs(listeners) do
        if listener[1] == event and (listener[2] == true or listener[2](context)) then listener[3](context) end
    end
end
local function key(value) fire('ShortcutTriggered', {string=value}) end
local function contents(suffix)
    for path, text in pairs(files) do if path:sub(-#suffix) == suffix then return table.concat(text) end end
    return ''
end
local function last()
    local bridge = contents('bridge.jsonl')
    if bridge == '' then bridge = contents('jaws_access.jsonl') end
    return bridge:match('([^\n]+)\n$') or ''
end
-- NVDA-style speech: name, role, value, states, position.
local function says(...)
    local text = last()
    for _, part in ipairs({...}) do if not text:find(part,1,true) then return false end end
    return true
end
local function choose_graphics()
    for i=1,22 do
        key('script_F2')
        if says('Graphics, button') then return end
    end
    error('Graphics was not found: ' .. last())
end
local function no_dispatch(message) assert(#dispatches == 0, message) end
start()
key('script_F4'); no_dispatch('No selection')
key('script_F2'); assert(says('New Campaign','1 of 22'))
key('script_F3'); assert(says('Quit','22 of 22'))
key('script_F2'); assert(says('New Campaign','1 of 22'))
key('script_F2'); assert(says('Continue Campaign, button, unavailable'))
assert(contents('native-ui-graphics-preview.log'):find('tree.nodes\tnumber\t86',1,true))
-- Browsing is cached; a second F2 does not rescan or change the native read order.
local _, captures = contents('native-ui-graphics-preview.log'):gsub('capture.COMPLETE','')
assert(captures==1)
choose_graphics(); key('script_F4')
assert(last():find('Press again',1,true), last()); no_dispatch('First F4 only arms')
now=1001; key('script_F4')
assert(#dispatches==1 and dispatches[1]==graphics_key)
assert(says(' activated.'))
key('script_F4'); assert(#dispatches==1, 'Third F4 cannot reuse confirmation')
-- All other classified main-menu controls remain blocked, including Continue and Quit.
start()
for i=1,22 do
    key('script_F2')
    if not says('Graphics, button') and not says('New Campaign, button') then
        key('script_F4'); key('script_F4'); no_dispatch('Non-Graphics control')
    end
end
-- Navigation cancels confirmation even when returning to the same entry.
start(); choose_graphics(); key('script_F4'); key('script_F2'); key('script_F3'); key('script_F4')
no_dispatch('Navigation cancels'); assert(last():find('Press again',1,true))
-- Timeouts and clock rollback do not send input or retain the old confirmation.
for _, delta in ipairs({5,-1}) do
    start(); choose_graphics(); key('script_F4'); now=now+delta; key('script_F4')
    no_dispatch('Time changed'); assert(says('timed out'))
end
start(); choose_graphics(); key('script_F4'); now=0/0; key('script_F4'); no_dispatch('Invalid clock')
-- Same-looking replacement native components must be rejected.
for _, prefix in ipairs({'tree', 'tree.child2', graphics_key}) do
    start(); choose_graphics(); key('script_F4'); nodes[prefix].address=newproxy(); key('script_F4')
    no_dispatch('Stale native identity')
end
for _, method in ipairs({'Visible','IsInteractive','CurrentState','GetStateText','GetTooltipText','Address','ChildCount','Id'}) do
    for _, fault in ipairs({'throw','function','nil'}) do
        start(); choose_graphics(); key('script_F4'); nodes[graphics_key].faults[method]=fault; key('script_F4')
        no_dispatch('Failed required read: '..method..'/'..fault)
    end
end
-- Persistent malformed values cannot authorize matching fallback snapshots.
start(); nodes[graphics_key].faults.GetTooltipText='function'; choose_graphics()
key('script_F4'); key('script_F4'); no_dispatch('Persistent bad tooltip')
-- Known enabled/visible properties and every ancestor remain required.
for _, prefix in ipairs({'tree.child2', graphics_key}) do
    start(); choose_graphics(); key('script_F4'); nodes[prefix].data.Visible=false; key('script_F4')
    no_dispatch('Hidden ancestor or leaf')
end
for _, property in ipairs({'IsInteractive','CurrentState','Id','GetStateText','GetTooltipText'}) do
    start(); choose_graphics(); key('script_F4')
    nodes[graphics_key].data[property] = property=='IsInteractive' and false or 'changed'
    key('script_F4'); no_dispatch('Changed Graphics property')
end
-- Layout/template verification applies even when a panel was already present at browse time.
start(); nodes.tree.data.ChildCount=6; choose_graphics(); key('script_F4'); key('script_F4')
no_dispatch('Preexisting extra panel')
start(); choose_graphics(); key('script_F4'); nodes.tree.data.ChildCount=6; key('script_F4')
no_dispatch('New unannounced panel')
start(); nodes[graphics_key].data.Id='button_audio'; choose_graphics(); key('script_F4'); key('script_F4')
no_dispatch('Duplicate/mismatched id')
-- Native UI recreation, destruction and panel callbacks invalidate cached selection.
for _, event in ipairs({'create','destroy','PanelOpenedCampaign','PanelClosedCampaign'}) do
    start(); choose_graphics(); key('script_F4')
    if event=='create' then created() elseif event=='destroy' then ready=false; destroyed()
    else fire(event, {string='dialog'}) end
    key('script_F4'); no_dispatch('Lifecycle cancellation: '..event)
end
-- Invalidation during the fresh scan or final path resolution must block input.
start(); choose_graphics(); key('script_F4')
read_hook=function(n, method) if method=='ChildCount' then read_hook=nil; created() end end
key('script_F4'); no_dispatch('UI recreation during scan')
start(); choose_graphics(); key('script_F4')
local reads=0
read_hook=function(n, method)
    if n.prefix==graphics_key and method=='Address' then
        reads=reads+1
        if reads==2 then n.address=newproxy() end
    end
end
key('script_F4'); no_dispatch('Leaf replaced during final resolution')
-- A click that recreates the UI is still reported only as input sent.
start(); choose_graphics(); key('script_F4'); click_hook=function() created() end
key('script_F4'); assert(#dispatches==1); assert(says(' activated.'))
-- Errors after native dispatch may not be presented as confirmed success.
start(); choose_graphics(); key('script_F4'); click_hook=function() error('native click exception') end
key('script_F4'); assert(#dispatches==1); assert(not last():find('Graphics opened',1,true))
-- Losing diagnostic output after arming must block dispatch.
start(); choose_graphics(); key('script_F4'); file_failure=true; key('script_F4')
no_dispatch('Diagnostic I/O failure')
-- 0.6.64: at its 2 MiB cap the log starts again (never larger, never "unavailable").
start(); choose_graphics()
for i=1,30 do now=now+5; key('script_F4') end
no_dispatch('Timed-out presses'); assert(#contents('native-ui-graphics-preview.log') <= 2097152)
local restarted=false
for _=1,400 do
    key('script_F2'); key('script_F3')
    if contents('native-ui-graphics-preview.log'):find('log.restarted',1,true) then restarted=true; break end
end
assert(restarted,'The log restarts at its cap')
assert(#contents('native-ui-graphics-preview.log') <= 2097152)
choose_graphics(); key('script_F4'); now=now+1; key('script_F4')
assert(#dispatches==1 and not says('Accessibility log unavailable'),'Activation works after the restart: '..last())
-- The four-second boundary is inclusive; expiration during validation is rejected.
start(); choose_graphics(); key('script_F4'); now=1004; key('script_F4'); assert(#dispatches==1)
start(); choose_graphics(); key('script_F4')
reads=0
read_hook=function(n, method)
    if n.prefix==graphics_key and method=='Address' then
        reads=reads+1; if reads==2 then now=1005 end
    end
end
key('script_F4'); no_dispatch('Confirmation expired during final validation')
-- Switching game context while retaining an old callback never permits input.
for _, mode in ipairs({'campaign','battle'}) do
    start(); choose_graphics(); key('script_F4'); context_mode=mode; key('script_F4')
    no_dispatch('Context switched after browse')
end
-- Exercise the actual first-input lifecycle order reported by the live run.
start(); created(); key('script_F2'); key('script_F3')
assert(contents('native-ui-graphics-preview.log'):find('navigation.received\tstring\tscript_F2',1,true))
assert(contents('native-ui-graphics-preview.log'):find('navigation.received\tstring\tscript_F3',1,true))
assert(contents('native-ui-graphics-preview.log'):find('capture.ENTER\tstring\tbrowse',1,true))
assert(says('Quit','22 of 22'))
-- A remapped/unrecognized shortcut is traced without starting a scan or action.
start(); key('script_shift_F2')
assert(contents('native-ui-graphics-preview.log'):find('shortcut.seen\tstring\tstring:script_shift_F2',1,true))
assert(not contents('native-ui-graphics-preview.log'):find('capture.ENTER',1,true))
no_dispatch('Unknown shortcut is diagnostic only')
-- The raw shortcut sample remains bounded even when unknown events repeat.
start()
for i=1,100 do key('script_unrecognized') end
local _, shortcut_count=contents('native-ui-graphics-preview.log'):gsub('shortcut.seen','')
assert(shortcut_count==64)
-- An exception outside capture's own protection is surfaced, cancels selection
-- and permits a fresh browse after the transient failure clears.
start(); speech_write_throw=true; key('script_F2')
assert(contents('native-ui-graphics-preview.log'):find('navigation.ERROR',1,true))
assert(says('Could not read this screen.')); no_dispatch('Navigation exception')
key('script_F2'); assert(says('New Campaign','1 of 22'))
-- The successful diagnostic does not require string.match. A reduced host
-- library must not break logging, navigation, or the error-reporting path.
start()
local original_match=string.match
string.match=nil
local minimal_ok, minimal_err=pcall(function() key('script_F2'); key('script_F3') end)
string.match=original_match
assert(minimal_ok, minimal_err)
assert(says('Quit','22 of 22'))
assert(contents('native-ui-graphics-preview.log'):find('capture.buffers',1,true))
-- The real Graphics capture contains seven controls, not the three footer links.
start(nil, graphics_fixture)
local expected_names={'Run in window, check box','Accept changes, button','Cancel changes, button','Advanced, button','Recommended, button','Resolution, combo box, 1280x720','Quality, combo box, Low'}
for _, name in ipairs(expected_names) do
    key('script_F2')
    assert(says(' of 7') and last():find(name,1,true),last())
    assert(not last():find('Total War Academy',1,true) and not last():find('Patch Notes',1,true) and not last():find('Quit',1,true))
    if name ~= 'Advanced, button' then
        key('script_F4'); key('script_F4'); no_dispatch('Graphics setting remains read only')
        assert(says('Not supported yet.'))
    end
end
key('script_F2'); assert(says('Run in window','1 of 7'))
assert(says('check box, state unknown'))
key('script_F3'); assert(says('Quality, combo box, Low','7 of 7'))
-- Native result observation after a single allowed click produces the scoped list.
start(); choose_graphics(); key('script_F4')
click_hook=function() nodes=build_nodes(graphics_fixture) end
key('script_F4'); assert(#dispatches==1)
key('script_F2'); assert(says('Graphics. Run in window','1 of 7'))
assert(contents('native-ui-graphics-preview.log'):find('capture.screen\tstring\tgraphics',1,true))
-- Escape may replace the panel without a UI-created event. Probe its identity
-- before reusing cached entries, then restore the main-menu list.
nodes=build_nodes(fixture)
key('script_F2'); assert(says('New Campaign','1 of 22'))
assert(contents('native-ui-graphics-preview.log'):find('navigation.screen_changed',1,true))
-- Background controls remain hidden on unknown, advanced and popup screens.
start(nil, graphics_fixture); nodes['tree.child2'].data.Id='unknown_panel'; key('script_F2')
assert(says('This screen is not supported yet.')); no_dispatch('Unknown panel')
for _, prefix in ipairs({'tree.child2.child0','tree.child2.child2','tree.child2.child1.child5.child1','tree.child2.child1.child6.child1'}) do
    start(nil, graphics_fixture); nodes[prefix].data.Visible=true; key('script_F2')
    assert(last():find(prefix=='tree.child2.child0' and 'Advanced graphics. No readable controls.' or 'This dialog is not supported yet.',1,true),last())
    key('script_F4'); no_dispatch('Unsupported popup cannot activate')
end
-- Hidden controls are excluded; malformed selected values are not fabricated.
start(nil, graphics_fixture); nodes['tree.child2.child1.child2.child1'].data.Visible=false
key('script_F2'); assert(says('1 of 6'))
start(nil, graphics_fixture); nodes['tree.child2.child1.child5.child0'].faults.GetStateText='function'
for i=1,6 do key('script_F2') end
assert(says('Resolution, combo box, value unavailable'))
-- Manually entering Graphics also invalidates a main-menu cache without a
-- lifecycle event. It does not dispatch any input through this integration.
start(); key('script_F2'); nodes=build_nodes(graphics_fixture); key('script_F2')
assert(says('Run in window','1 of 7')); no_dispatch('Manual panel transition')
-- Graphics naming and root/panel probes also work without string.match.
start(nil, graphics_fixture)
original_match=string.match; string.match=nil
local graphics_minimal_ok,graphics_minimal_err=pcall(function() for i=1,7 do key('script_F2') end end)
string.match=original_match
assert(graphics_minimal_ok,graphics_minimal_err)
assert(says('Quality, combo box, Low','7 of 7'))
-- Advanced activation changes only a view. These synthetic leaves remain
-- useful for testing bounded discovery independently of production labels.
local advanced_key='tree.child2.child1.child3'
local advanced_fixture={}
for prefix,row in pairs(graphics_fixture) do
    advanced_fixture[prefix]={}; for k,v in pairs(row) do advanced_fixture[prefix][k]=v end
end
advanced_fixture['tree.child2.child0'].Visible=true
advanced_fixture['tree.child2.child1'].Visible=false
for i=0,11 do
    advanced_fixture['tree.child2.child0.child'..i]={Id='fixture_advanced_'..i,Visible=true,IsInteractive=true,
        ChildCount=0,GetStateText='Fixture advanced label '..i,GetTooltipText='',CurrentState='active'}
end
local function install_scene(layout)
    local root_address,panel_address=nodes.tree.address,nodes['tree.child2'].address
    nodes=build_nodes(layout)
    nodes.tree.address=root_address; nodes['tree.child2'].address=panel_address
end
local function choose_advanced()
    for i=1,4 do key('script_F2') end
    assert(says('Advanced, button','4 of 7'),last())
end
start(nil,graphics_fixture); choose_advanced(); key('script_F4')
assert(last():find('Advanced. Press again',1,true)); no_dispatch('First Advanced confirmation')
click_hook=function() install_scene(advanced_fixture) end
key('script_F4'); assert(#dispatches==1 and dispatches[1]==advanced_key)
assert(not contents('native-ui-graphics-preview.log'):find('activation.observed_result',1,true))
key('script_F2'); assert(says('Advanced graphics. No readable controls.'))
assert(contents('native-ui-graphics-preview.log'):find('activation.observed_result\tstring\tAdvanced',1,true))
assert(contents('native-ui-graphics-preview.log'):find('fixture_advanced_11',1,true))
key('script_F4'); assert(#dispatches==1)
-- Collapsing Advanced without replacing the root or Graphics component must
-- refresh the cache using the observed child visibility flags.
install_scene(graphics_fixture); key('script_F2')
assert(says('Run in window','1 of 7'))
assert(contents('native-ui-graphics-preview.log'):find('navigation.screen_changed',1,true))
for _, delta in ipairs({5,-1}) do
    start(nil,graphics_fixture); choose_advanced(); key('script_F4'); now=now+delta; key('script_F4')
    no_dispatch('Advanced confirmation time anomaly')
end
start(nil,graphics_fixture); choose_advanced(); key('script_F4'); key('script_F2'); key('script_F3'); key('script_F4')
no_dispatch('Advanced navigation cancels confirmation')
for _, prefix in ipairs({'tree','tree.child2','tree.child2.child1',advanced_key}) do
    start(nil,graphics_fixture); choose_advanced(); key('script_F4'); nodes[prefix].address=newproxy(); key('script_F4')
    no_dispatch('Advanced stale ancestor identity')
end
for _, method in ipairs({'Visible','IsInteractive','CurrentState','GetStateText','GetTooltipText','Address','Id','ChildCount'}) do
    for _, fault in ipairs({'throw','function','nil'}) do
        start(nil,graphics_fixture); choose_advanced(); key('script_F4'); nodes[advanced_key].faults[method]=fault; key('script_F4')
        no_dispatch('Advanced native failure: '..method..'/'..fault)
    end
end
for _, prefix in ipairs({'tree.child2.child0','tree.child2.child2'}) do
    start(nil,graphics_fixture); choose_advanced(); key('script_F4'); nodes[prefix].data.Visible=true; key('script_F4')
    no_dispatch('Another Graphics panel opened after arming')
end
start(nil,graphics_fixture); choose_advanced(); key('script_F4'); created(); key('script_F4')
no_dispatch('Advanced lifecycle invalidation')
start(nil,graphics_fixture); choose_advanced(); key('script_F4'); file_failure=true; key('script_F4')
no_dispatch('Advanced diagnostic loss')
start(nil,graphics_fixture); choose_advanced(); key('script_F4')
nodes['tree.child2.child1.child4'].data.Id='button_advanced_options'; key('script_F4')
no_dispatch('Duplicate Advanced ID invalidates screen template')
-- A returned click alone is not screen confirmation. Staying on Basic must
-- produce result_not_observed instead of a success claim.
start(nil,graphics_fixture); choose_advanced(); key('script_F4'); key('script_F4')
assert(#dispatches==1); key('script_F2')
assert(contents('native-ui-graphics-preview.log'):find('activation.result_not_observed\tstring\tAdvanced:graphics',1,true))
assert(not contents('native-ui-graphics-preview.log'):find('activation.observed_result',1,true))
-- Discovery remains bounded on an oversized synthetic Advanced subtree.
local oversized={}
for prefix,row in pairs(advanced_fixture) do
    oversized[prefix]={}; for k,v in pairs(row) do oversized[prefix][k]=v end
end
for i=0,11 do
    local section='tree.child2.child0.child'..i
    oversized[section].ChildCount=20
    for j=0,19 do
        oversized[section..'.child'..j]={Id='fixture_leaf_'..j,Visible=true,IsInteractive=true,
            ChildCount=0,GetStateText='Fixture leaf',GetTooltipText='',CurrentState='active'}
    end
end
start(nil,oversized); key('script_F2')
assert(contents('native-ui-graphics-preview.log'):find('tree.nodes\tnumber\t200',1,true))
assert(contents('native-ui-graphics-preview.log'):find('.bounded',1,true))
assert(says('Advanced graphics. No readable controls.'))
key('script_F4'); no_dispatch('Bounded Advanced discovery has no setting action')
-- The observed 152-node panel has 33 semantic entries. These labels/values
-- come from the captured native fields, not the synthetic discovery subtree.
start(nil,captured_advanced_fixture)
local advanced_names={
    'Benchmark, button','Unlimited video memory, check box','V-sync, check box','Vignette, check box','Proximity fading, check box','Battery meter, check box','SSAO, check box','Sharpening, check box',
    'Direct X, combo box, DX11','Anti-aliasing, combo box, Off','Texture quality, combo box, Low','Texture filtering, combo box, Trilinear','Shadow detail, combo box, Off',
    'Water detail, combo box, Low','VFX detail, combo box, Low','Grass detail, combo box, Low','Tree detail, combo box, Low','Terrain detail, combo box, Low','Unit detail, combo box, Low',
    'Building detail, combo box, Low','Depth of field, combo box, Off','Unit size, combo box, Small','Screen space reflections, combo box, Off','Porthole quality, combo box, 2D',
    'Fog, combo box, Low','Corpse Lifespan (in seconds), combo box, 30','Graphics Card, Intel(R) Iris(R) Plus Graphics',
    'Video Memory (MB), 800 MB','Accept changes, button','Cancel changes, button','Resolution scale, slider, +100%',
    'UI scale, slider, 100%','Apply UI Scale, button'}
for i,name in ipairs(advanced_names) do
    key('script_F2')
    assert(says(i..' of 33') and last():find(name,1,true),last())
    assert(not last():find('read only',1,true))
    if i==2 or i==9 or i==25 then assert(says('unavailable')) end
    if i==5 or i==8 then assert(says('check box, selected'),last()) end
    assert(not last():find('Total War Academy',1,true) and not last():find('Patch Notes',1,true) and not last():find('Quit',1,true))
    key('script_F4'); key('script_F4'); no_dispatch('Every Advanced setting is read only')
end
assert(contents('native-ui-graphics-preview.log'):find('tree.nodes\tnumber\t152',1,true))
assert(not contents('native-ui-graphics-preview.log'):find('.bounded',1,true))
local _, actual_captures=contents('native-ui-graphics-preview.log'):gsub('capture.COMPLETE','')
assert(actual_captures==1, 'Advanced navigation must remain cached')
key('script_F2'); assert(says('Benchmark','1 of 33'))
key('script_F3'); assert(says('Apply UI Scale','33 of 33'))
-- Real observed panels also test unchanged-root visibility transitions.
install_scene(graphics_fixture); key('script_F2'); assert(says('Run in window','1 of 7'))
install_scene(captured_advanced_fixture); key('script_F2'); assert(says('Benchmark','1 of 33'))
install_scene(fixture); key('script_F2'); assert(says('New Campaign','1 of 22'))
-- Hidden and presentation-only descendants are not navigation entries.
start(nil,captured_advanced_fixture); nodes['tree.child2.child0.child0'].data.Visible=false
key('script_F2'); assert(says('Unlimited video memory','1 of 32'))
-- A missing dropdown value is announced as unavailable, never inferred from state.
start(nil,captured_advanced_fixture); nodes['tree.child2.child0.child2.child0.child0'].faults.GetStateText='function'
for i=1,9 do key('script_F2') end
assert(says('Direct X, combo box, value unavailable'))
-- A missing native label excludes its control without exposing an internal id.
start(nil,captured_advanced_fixture); nodes['tree.child2.child0.child2.child0.child2'].faults.GetStateText='function'
key('script_F2'); assert(says(' of 32'))
for i=1,32 do
    key('script_F2'); assert(not last():find('dropdown_directx',1,true))
end
-- Popup detection at capture time hides the underlying panel until a future
-- popup reader is implemented. No setting action is dispatched.
start(nil,captured_advanced_fixture); nodes['tree.child2.child0.child2.child0.child1'].data.Visible=true
key('script_F2'); assert(says('This list is not supported yet.'))
key('script_F4'); no_dispatch('Expanded Advanced popup')
-- No optional string.match dependency is introduced by the new reader.
start(nil,captured_advanced_fixture)
original_match=string.match; string.match=nil
local advanced_minimal_ok,advanced_minimal_err=pcall(function() for i=1,33 do key('script_F2') end end)
string.match=original_match
assert(advanced_minimal_ok,advanced_minimal_err)
assert(says('Apply UI Scale','33 of 33'))
-- Regression: persisted windowed mode must not block Advanced view activation.
-- This uses the actual failing 0.5.9 basic-screen capture.
start(nil,windowed_fixture); choose_advanced(); key('script_F4')
assert(last():find('Advanced. Press again',1,true),last())
click_hook=function() install_scene(captured_advanced_fixture) end
key('script_F4'); assert(#dispatches==1 and dispatches[1]==advanced_key)
key('script_F2'); assert(says('Benchmark','1 of 33'))
assert(contents('native-ui-graphics-preview.log'):find('activation.observed_result\tstring\tAdvanced',1,true))
-- Allowing a starting variant must not allow that value to change while armed.
for _, initial in ipairs({'active','selected'}) do
    start(nil,graphics_fixture); nodes['tree.child2.child1.child0'].data.CurrentState=initial
    choose_advanced(); key('script_F4')
    nodes['tree.child2.child1.child0'].data.CurrentState=initial=='active' and 'selected' or 'active'
    key('script_F4'); no_dispatch('Window mode changed during confirmation')
end
-- No other checkbox state or unreadable native value gets a layout exemption.
for _, state in ipairs({'inactive','disabled','selected_hover','unknown'}) do
    start(nil,graphics_fixture); nodes['tree.child2.child1.child0'].data.CurrentState=state
    choose_advanced(); key('script_F4'); key('script_F4'); no_dispatch('Unobserved windowed state: '..state)
end
for _, fault in ipairs({'throw','function','nil'}) do
    start(nil,windowed_fixture); nodes['tree.child2.child1.child0'].faults.CurrentState=fault
    choose_advanced(); key('script_F4'); key('script_F4'); no_dispatch('Unreadable windowed state: '..fault)
end
-- The exception is specific to one field on the captured checkbox, not any
-- control called selected, nor its visibility, type, or interactive state.
start(nil,windowed_fixture); choose_advanced(); key('script_F4')
nodes[advanced_key].data.CurrentState='selected'; key('script_F4'); no_dispatch('Advanced must remain active')
start(nil,windowed_fixture); choose_advanced(); key('script_F4')
nodes['tree.child2.child1.child0'].data.Visible=false; key('script_F4'); no_dispatch('Hidden windowed control')
start(nil,windowed_fixture); nodes['tree.child2.child1.child0'].data.IsInteractive=false
choose_advanced(); key('script_F4'); key('script_F4'); no_dispatch('Noninteractive windowed control')
start(nil,windowed_fixture); choose_advanced(); key('script_F4')
nodes['tree.child2.child1.child0'].data.Id='checkbox_other'; key('script_F4'); no_dispatch('Wrong checkbox id')
start(nil,windowed_fixture); choose_advanced(); key('script_F4')
nodes[advanced_key].address=newproxy(); key('script_F4'); no_dispatch('Windowed mode still requires native identity')
-- The next slice opens only the actually captured main-menu New Campaign.
local campaign_key='tree.child2.child1.child0.child0.child0.child0.child1'
local function choose_campaign() key('script_F2'); assert(says('New Campaign','1 of 22')) end
start(); choose_campaign(); key('script_F4'); no_dispatch('Campaign first press only arms')
assert(last():find('New Campaign. Press again',1,true))
key('script_F4'); assert(#dispatches==1 and dispatches[1]==campaign_key)
key('script_F4'); assert(#dispatches==1, 'No reusing campaign confirmation')
-- Synthetic unknown setup data is only a test, not a captured game template.
local unknown_setup={}
for prefix,row in pairs(fixture) do
    unknown_setup[prefix]={}; for k,v in pairs(row) do unknown_setup[prefix][k]=v end
end
unknown_setup['tree.child2'].Id='fixture_unmapped_setup'
start(); choose_campaign(); key('script_F4')
click_hook=function() install_scene(unknown_setup) end
key('script_F4'); key('script_F2')
assert(says('This screen is not supported yet.'))
assert(not last():find('New Campaign opened',1,true))
assert(contents('native-ui-graphics-preview.log'):find('activation.result_requires_mapping',1,true))
assert(not contents('native-ui-graphics-preview.log'):find('activation.observed_result',1,true))
key('script_F4'); assert(#dispatches==1, 'Unmapped setup cannot start a campaign')
local _, before_refresh=contents('native-ui-graphics-preview.log'):gsub('capture.COMPLETE','')
key('script_F2')
local _, after_refresh=contents('native-ui-graphics-preview.log'):gsub('capture.COMPLETE','')
assert(after_refresh==before_refresh+1, 'Explicit browse must refresh an unknown panel')
install_scene(fixture); key('script_F2'); assert(says('New Campaign','1 of 22'))
-- Campaign activation retains the same exact validation and cancellation rules.
for _, prefix in ipairs({'tree','tree.child2',campaign_key}) do
    start(); choose_campaign(); key('script_F4'); nodes[prefix].address=newproxy(); key('script_F4')
    no_dispatch('Campaign stale identity')
end
for _, method in ipairs({'Id','Visible','IsInteractive','CurrentState','GetStateText','GetTooltipText','Address','ChildCount'}) do
    for _, fault in ipairs({'throw','function','nil'}) do
        start(); choose_campaign(); key('script_F4'); nodes[campaign_key].faults[method]=fault; key('script_F4')
        no_dispatch('Campaign native read failure: '..method..'/'..fault)
    end
end
for _, state in ipairs({'inactive','selected','disabled'}) do
    start(); nodes[campaign_key].data.CurrentState=state; choose_campaign()
    key('script_F4'); key('script_F4'); no_dispatch('Campaign not active')
end
for _, prefix in ipairs({'tree.child2.child1','tree.child2.child1.child0.child0.child0',campaign_key}) do
    start(); choose_campaign(); key('script_F4'); nodes[prefix].data.Visible=false; key('script_F4')
    no_dispatch('Campaign hidden ancestor or leaf')
end
for _, delta in ipairs({5,-1}) do
    start(); choose_campaign(); key('script_F4'); now=now+delta; key('script_F4'); no_dispatch('Campaign clock')
end
start(); choose_campaign(); key('script_F4'); key('script_F2'); key('script_F3'); key('script_F4')
no_dispatch('Campaign navigation cancels confirmation')
start(); choose_campaign(); key('script_F4'); created(); key('script_F4'); no_dispatch('Campaign lifecycle')
start(); choose_campaign(); key('script_F4'); file_failure=true; key('script_F4'); no_dispatch('Campaign log failure')
start(); nodes.tree.data.ChildCount=6; choose_campaign(); key('script_F4'); key('script_F4'); no_dispatch('Campaign extra modal')
start(); nodes['tree.child3.child0.child0'].data.Id='button_new_campaign'
-- 0.6.60: the selected element is clicked by its own path; a lookalike elsewhere is never the target.
choose_campaign(); key('script_F4'); key('script_F4'); assert(#dispatches==1 and dispatches[1]==campaign_key,'Selected element only')
-- Actual 0.6.0 campaign selection data, including the second hidden-Tooltip capture.
local campaign_fixture=dofile('tests/fixtures/campaign_selection_0_6_0.lua')
local tooltip_fixture=dofile('tests/fixtures/campaign_selection_tooltip_0_6_0.lua')
local continue_key='tree.child2.child2.child0'
local function choose_continue()
    for i=1,17 do key('script_F2'); if says('Continue, button') then return end end
    error('Continue was not found: '..last())
end
local selection_names={'The Eye of the Vortex, radio button','Mortal Empires, radio button','Continue, button',
    'Campaign description: At the heart of the Elven homeland','Listed race: High Elves','Listed race: Lizardmen',
    'Listed race: Dark Elves','Listed race: Skaven','Listed race: Vampire Coast','Listed race: Tomb Kings',
    'Listed race: The Empire','Listed race: Bretonnia','Listed race: Beastmen Warherds','Listed race: Dwarfs',
    'Listed race: Greenskins','Listed race: Wood Elves','Return to main menu, button'}
for _, layout in ipairs({campaign_fixture,tooltip_fixture}) do
    start(nil,layout)
    for i,name in ipairs(selection_names) do
        key('script_F2')
        assert(says(i..' of 17') and last():find(name,1,true),last())
        if i==1 then assert(says('radio button, checked')) end
        if i~=3 and i~=2 then -- 0.6.64: Mortal Empires can be chosen (tested below)
            assert(not last():find('read only',1,true)); key('script_F4'); key('script_F4'); no_dispatch('Selection information cannot dispatch')
        end
        assert(not last():find('button_campaign_entry',1,true) and not last():find('new_content_icon',1,true))
    end
    local _, captures=contents('native-ui-graphics-preview.log'):gsub('capture.COMPLETE','')
    assert(captures==1,'Campaign list browsing must remain cached')
    key('script_F2'); assert(says('The Eye of the Vortex','1 of 17'))
    key('script_F3'); assert(says('17 of 17'))
    -- Activating this one captured view button requires both F4 presses.
    start(nil,layout); choose_continue(); key('script_F4'); no_dispatch('Continue first press')
    assert(last():find('Continue. Press again',1,true),last())
    click_hook=function() install_scene(unknown_setup) end
    key('script_F4'); assert(#dispatches==1 and dispatches[1]==continue_key)
    assert(says(' activated.'))
    key('script_F2'); assert(says('This screen is not supported yet.'))
    assert(contents('native-ui-graphics-preview.log'):find('activation.result_requires_mapping\tstring\tContinue:unknown',1,true))
    assert(not contents('native-ui-graphics-preview.log'):find('activation.observed_result',1,true))
    key('script_F4'); key('script_F4'); assert(#dispatches==1,'Unmapped lord/setup controls cannot activate')
end
-- 0.6.64: Mortal Empires (trial run 3 said "Not supported yet") is chosen by its radio button.
local me_key='tree.child2.child0.child1.child1.child1'
for _, layout in ipairs({campaign_fixture,tooltip_fixture}) do
    start(nil,layout); key('script_F2'); key('script_F2'); assert(says('Mortal Empires, radio button, not checked, 2 of 17'),last())
    key('script_F4'); no_dispatch('Mortal Empires first press'); assert(says('Mortal Empires. Press again'),last())
    key('script_F4'); assert(#dispatches==1 and dispatches[1]==me_key,'Mortal Empires clicked'); assert(says('Mortal Empires selected.'),last())
end
single_press=true
start(nil,campaign_fixture); key('script_F2'); key('script_F2'); key('script_F4')
assert(#dispatches==1 and dispatches[1]==me_key and says('Mortal Empires selected.'),'One press chooses Mortal Empires')
-- The checked campaign is not clicked again.
start(nil,campaign_fixture); key('script_F2'); key('script_F4'); no_dispatch('Checked campaign'); assert(says('The Eye of the Vortex is already selected.'),last())
-- A campaign that changes between selection and press is not clicked.
start(nil,campaign_fixture); key('script_F2'); key('script_F2')
nodes['tree.child2.child0.child1.child1.child1.child0'].data.GetStateText='Other'
key('script_F4'); no_dispatch('Changed campaign label')
single_press=false
-- 0.6.64: back from Select Lord a hidden tooltip_campaign_select_lord layer
-- replaces "Tooltip"; arrows must still move on (live: every key restarted at 1).
local after_lord={}
for prefix,row in pairs(tooltip_fixture) do local c={}; for k,v in pairs(row) do c[k]=v end; after_lord[prefix]=c end
after_lord['tree.child5'].Id='tooltip_campaign_select_lord'
start(nil,after_lord); key('script_F2'); key('script_F2'); assert(says('Mortal Empires, radio button','2 of 17'),last())
key('script_F2'); assert(says('Continue, button','3 of 17'),last())
-- A layer that becomes visible is still a screen change.
nodes['tree.child5'].data.Visible=true; key('script_F2')
assert(contents('native-ui-graphics-preview.log'):find('navigation.screen_changed',1,true),'Shown layer re-reads the screen')
-- New Campaign now has a real observed panel identity for its result.
start(); choose_campaign(); key('script_F4'); click_hook=function() install_scene(campaign_fixture) end
key('script_F4'); key('script_F2'); assert(says('1 of 17'))
assert(contents('native-ui-graphics-preview.log'):find('activation.observed_result\tstring\tNew Campaign',1,true))
-- Returning with no recreated root/panel still restores the main-menu scope.
install_scene(fixture); key('script_F2'); assert(says('New Campaign','1 of 22'))
-- Cached navigation detects selection and description-title changes.
start(nil,campaign_fixture); key('script_F2')
nodes['tree.child2.child0.child1.child0.child1'].data.CurrentState='active'
nodes['tree.child2.child0.child1.child1.child1'].data.CurrentState='selected'
key('script_F2'); assert(says('The Eye of the Vortex, radio button, not checked','1 of 17'))
-- 0.6.60: a campaign remembered as selected on another PC (Mortal Empires) may continue.
choose_continue(); key('script_F4'); key('script_F4'); assert(#dispatches==1 and dispatches[1]==continue_key,'Continue with Mortal Empires selected')
start(nil,campaign_fixture); key('script_F2')
nodes['tree.child2.child0.child0.child1.child0.child1.child0'].data.GetStateText='Changed title'
key('script_F2'); assert(contents('native-ui-graphics-preview.log'):find('navigation.screen_changed',1,true))
-- Exact fields/identities are checked on every F4, not merely on browse.
for _, method in ipairs({'Id','Visible','IsInteractive','CurrentState','GetStateText','GetTooltipText','ChildCount','Address'}) do
    for _, fault in ipairs({'throw','function','nil'}) do
        start(nil,campaign_fixture); choose_continue(); key('script_F4')
        nodes[continue_key].faults[method]=fault; key('script_F4'); no_dispatch('Continue native failure: '..method..'/'..fault)
    end
end
for _, prefix in ipairs({'tree','tree.child2','tree.child2.child2',continue_key}) do
    start(nil,campaign_fixture); choose_continue(); key('script_F4'); nodes[prefix].address=newproxy(); key('script_F4')
    no_dispatch('Continue stale identity')
    start(nil,campaign_fixture); choose_continue(); key('script_F4'); nodes[prefix].data.Visible=false; key('script_F4')
    no_dispatch('Continue hidden ancestor')
end
for _, state in ipairs({'inactive','selected','disabled','unknown'}) do
    start(nil,campaign_fixture); nodes[continue_key].data.CurrentState=state; choose_continue()
    key('script_F4'); key('script_F4'); no_dispatch('Continue not active')
end
start(nil,campaign_fixture); choose_continue(); key('script_F4'); key('script_F4'); key('script_F2')
assert(contents('native-ui-graphics-preview.log'):find('activation.result_not_observed\tstring\tContinue:campaign_selection',1,true))
assert(not contents('native-ui-graphics-preview.log'):find('activation.observed_result',1,true))
for _, delta in ipairs({5,-1}) do
    start(nil,campaign_fixture); choose_continue(); key('script_F4'); now=now+delta; key('script_F4'); no_dispatch('Continue clock')
end
start(nil,campaign_fixture); choose_continue(); key('script_F4'); created(); key('script_F4'); no_dispatch('Continue lifecycle')
start(nil,campaign_fixture); choose_continue(); key('script_F4'); key('script_F2'); key('script_F3'); key('script_F4'); no_dispatch('Continue navigation cancellation')
start(nil,campaign_fixture); choose_continue(); key('script_F4'); file_failure=true; key('script_F4'); no_dispatch('Continue log failure')
start(nil,campaign_fixture); choose_continue(); key('script_F4'); nodes['tree.child2.child2.child1'].data.Visible=true; key('script_F4'); no_dispatch('Purchase panel appeared')
start(nil,campaign_fixture); choose_continue(); key('script_F4'); nodes['tree.child2.child2.child2'].data.Visible=true; key('script_F4'); no_dispatch('Download panel appeared')
start(nil,campaign_fixture); choose_continue(); key('script_F4'); nodes['tree.child2.child2.child1'].data.Id='button_next'; key('script_F4'); no_dispatch('Duplicate Continue ID')
start(nil,campaign_fixture); nodes[continue_key].data.Id='button_start_campaign'; key('script_F2'); key('script_F4'); key('script_F4'); no_dispatch('Start Campaign is never allowed')
-- Extra root children may only be the actually observed hidden noninteractive Tooltip.
for _, field in ipairs({'Id','Visible','IsInteractive'}) do
    start(nil,tooltip_fixture); choose_continue(); key('script_F4')
    nodes['tree.child5'].data[field]=field=='Id' and 'dialog' or true
    key('script_F4'); no_dispatch('Unexpected extra root child: '..field)
end
start(nil,campaign_fixture); choose_continue(); key('script_F4'); nodes.tree.data.ChildCount=7; key('script_F4'); no_dispatch('Extra root popup')
-- 0.6.60: a hover tooltip left open by the pointer does not hide the screen.
start(nil,tooltip_fixture); nodes['tree.child5'].data.Visible=true; key('script_F2'); assert(says('1 of 17'),last())
start(nil,tooltip_fixture); nodes['tree.child5'].data.Id='dialog'; nodes['tree.child5'].data.Visible=true; key('script_F2'); assert(says('This screen is not supported yet.')); key('script_F4'); no_dispatch('Visible overlay')
-- Only observed empty, noninteractive smoke leaves may change visibility.
local particle='tree.child2.child0.child1.child0.child0.child1.child34'
start(nil,campaign_fixture); choose_continue(); key('script_F4'); nodes[particle].data.Visible=not nodes[particle].data.Visible
key('script_F4'); assert(#dispatches==1 and dispatches[1]==continue_key,'Empty particle visibility must not cancel')
for _, property in ipairs({'Id','IsInteractive','GetStateText','GetTooltipText','CurrentState','ChildCount'}) do
    start(nil,campaign_fixture); choose_continue(); key('script_F4')
    nodes[particle].data[property]=property=='IsInteractive' and true or property=='ChildCount' and 1 or 'changed'
    key('script_F4'); no_dispatch('A particle cannot become content: '..property)
end
-- Changing the actually selected campaign or title during confirmation cancels.
start(nil,campaign_fixture); choose_continue(); key('script_F4')
nodes['tree.child2.child0.child1.child0.child1'].data.CurrentState='active'; key('script_F4'); no_dispatch('Campaign selected state changed')
start(nil,campaign_fixture); choose_continue(); key('script_F4')
nodes['tree.child2.child0.child0.child1.child0.child1.child0'].data.GetStateText='Mortal Empires'; key('script_F4'); no_dispatch('Campaign title changed')
-- Labels and values must come from native strings; no internal-ID fallback.
start(nil,campaign_fixture); nodes['tree.child2.child0.child1.child1.child1.child0'].faults.GetStateText='function'
key('script_F2'); assert(says('1 of 16'))
start(nil,campaign_fixture); nodes['tree.child2.child0.child0.child1.child1.child1.child0'].data.Visible=false
key('script_F2'); assert(says('1 of 16'))
start(nil,campaign_fixture); original_match=string.match; string.match=nil
local campaign_minimal_ok,campaign_minimal_err=pcall(function() for i=1,17 do key('script_F2') end end)
string.match=original_match; assert(campaign_minimal_ok,campaign_minimal_err); assert(says('17 of 17'))
-- Cached selection speech refreshes when visible/enabled Continue or description changes.
start(nil,campaign_fixture); key('script_F2'); nodes[continue_key].data.CurrentState='inactive'
choose_continue(); assert(says('unavailable'))
start(nil,campaign_fixture); key('script_F2'); nodes[continue_key].data.Visible=false
key('script_F2'); assert(says('1 of 16'))
start(nil,campaign_fixture); key('script_F2')
nodes['tree.child2.child0.child0.child1.child0.child0.child0'].data.GetStateText='Changed native description'
for i=1,4 do key('script_F2') end
assert(last():find('Changed native description',1,true),last())
-- Regression: plain diagnostic rows flatten native CR/LF one-for-one.
-- These input variants reproduce the 0.6.1 mismatch while printing identically.
local store_tip='tree.child2.child0.child0.child1.child1.child1.child10.child0'
for _, breaks in ipairs({'\r\n','\n\n','\r\r'}) do
    start(nil,campaign_fixture)
    nodes[store_tip].data.GetTooltipText=nodes[store_tip].data.GetTooltipText:gsub('  Left',breaks..'Left',1)
    choose_continue(); key('script_F4'); assert(last():find('Continue. Press again',1,true),last())
    key('script_F4'); assert(#dispatches==1 and dispatches[1]==continue_key)
    assert(contents('native-ui-graphics-preview.log'):find('campaign.tooltip.escaped',1,true))
end
for _, breaks in ipairs({'\r','\n'}) do
    start(nil,campaign_fixture)
    local description='tree.child2.child0.child0.child1.child0.child0.child0'
    nodes[description].data.GetStateText=nodes[description].data.GetStateText:gsub('At the','At'..breaks..'the',1)
    choose_continue(); key('script_F4'); key('script_F4'); assert(#dispatches==1 and dispatches[1]==continue_key)
end
-- Exact raw strings still guard a pending confirmation, even when log rows match.
start(nil,campaign_fixture)
nodes[store_tip].data.GetTooltipText=nodes[store_tip].data.GetTooltipText:gsub('  Left','\r\nLeft',1)
choose_continue(); key('script_F4'); assert(last():find('Press again',1,true))
nodes[store_tip].data.GetTooltipText=nodes[store_tip].data.GetTooltipText:gsub('\r\n','\n\n')
key('script_F4'); no_dispatch('Byte-level line break change during confirmation')
-- 0.6.60: text that differs from this PC's recording (another PC, language,
-- DLC) is not a reason to refuse; a change between the two presses still is.
for _, replacement in ipairs({' Left','\t\tLeft','  Changed'}) do
    start(nil,campaign_fixture)
    nodes[store_tip].data.GetTooltipText=nodes[store_tip].data.GetTooltipText:gsub('  Left',replacement,1)
    choose_continue(); key('script_F4'); key('script_F4'); assert(#dispatches==1,'Other text on another PC')
    start(nil,campaign_fixture); choose_continue(); key('script_F4')
    nodes[store_tip].data.GetTooltipText=nodes[store_tip].data.GetTooltipText:gsub('  Left',replacement,1)
    key('script_F4'); no_dispatch('Text change during confirmation')
    if replacement=='\t\tLeft' then assert(contents('native-ui-graphics-preview.log'):find('\\u0009',1,true)) end
end
start(nil,campaign_fixture); choose_continue(); key('script_F4'); nodes[continue_key].data.CurrentState='active\n'; key('script_F4'); no_dispatch('No state normalization')
start(nil,campaign_fixture); choose_continue(); key('script_F4'); nodes[continue_key].data.Id='button_next\n'; key('script_F4'); no_dispatch('No ID normalization')
start(); choose_graphics(); key('script_F4'); nodes[graphics_key].data.GetTooltipText='\r\n'; key('script_F4'); no_dispatch('No main-menu text normalization')
-- Actual returned main has Tooltip child4 and browser child5, not the reverse.
local returned_main=dofile('tests/fixtures/frontend_menu_tooltip_0_6_1.lua')
start(nil,returned_main); key('script_F2'); assert(says('New Campaign','1 of 22'))
key('script_F4'); assert(last():find('New Campaign. Press again',1,true),last())
click_hook=function() install_scene(campaign_fixture) end
key('script_F4'); assert(#dispatches==1 and dispatches[1]==campaign_key)
key('script_F2'); assert(says('1 of 17'))
assert(contents('native-ui-graphics-preview.log'):find('activation.observed_result\tstring\tNew Campaign',1,true))
start(nil,returned_main); choose_graphics(); key('script_F4'); key('script_F4'); assert(#dispatches==1 and dispatches[1]==graphics_key)
-- A caption on a hidden, noninteractive, non-target Tooltip is not control data.
start(nil,returned_main); choose_campaign(); key('script_F4'); nodes['tree.child4'].data.GetStateText='Previously hovered control'
key('script_F4'); assert(#dispatches==1 and dispatches[1]==campaign_key)
for _, property in ipairs({'Id','Visible','IsInteractive','GetTooltipText','ChildCount','CurrentState'}) do
    start(nil,returned_main); choose_campaign(); key('script_F4')
    nodes['tree.child4'].data[property]=property=='Visible' and true or property=='IsInteractive' and true or property=='ChildCount' and 3 or 'changed'
    key('script_F4'); no_dispatch('Returned-main Tooltip must remain observed and hidden: '..property)
end
start(nil,returned_main); choose_campaign(); key('script_F4'); nodes['tree.child5'].data.Visible=true; key('script_F4'); no_dispatch('Visible browser on returned main')
start(nil,returned_main); choose_campaign(); key('script_F4'); nodes[campaign_key].address=newproxy(); key('script_F4'); no_dispatch('Returned-main native identity')
start(nil,returned_main); choose_campaign(); key('script_F4'); nodes.tree.data.ChildCount=7; key('script_F4'); no_dispatch('Returned-main extra popup')
-- Root-child changes must refresh cached main navigation before arming input.
start(); key('script_F2'); install_scene(returned_main); key('script_F2')
assert(says('New Campaign','1 of 22'))
assert(contents('native-ui-graphics-preview.log'):find('tree.nodes\tnumber\t87',1,true))
key('script_F4'); key('script_F4'); assert(#dispatches==1 and dispatches[1]==campaign_key)
-- Opt-in timer transport exercises the same native handlers, not a keyboard event.
local function auto_status()
    local result={}
    for value in contents('automation-status.tsv'):gmatch('[^\t\n]+') do result[#result+1]=value end
    assert(#result==16,'Complete automation status required: '..contents('automation-status.tsv'))
    return result
end
local function auto_request(action,overrides)
    local status=auto_status()
    local request={'WH2REQ1',string.rep('a',32),status[3],tostring(tonumber(status[6])+1),status[4],status[5],action,status[9],tostring(now+5)}
    if overrides then for key,value in pairs(overrides) do request[key]=value end end
    local raw=table.concat(request,'\t')..'\n'
    files[automation_base .. 'automation-request.tsv']={raw}
    assert(automation_poll,'Automation callback active'); automation_poll()
    return auto_status(),raw
end
start(); assert(automation_poll==nil and contents('automation-status.tsv')=='','Default stays uninstrumented')
start(nil,fixture,true); assert(automation_poll,'Verified timer callback registered')
local status=auto_status(); assert(status[14]=='1' and status[15]=='1' and status[6]=='0')
status=auto_request('next'); assert(status[8]=='main' and status[11]=='22' and status[10]=='New Campaign')
assert(not contents('native-ui-graphics-preview.log'):find('shortcut.seen',1,true),'Do not fake physical key events')
status=auto_request('previous'); assert(status[10]=='Quit')
status=auto_request('next'); assert(status[10]=='New Campaign')
local _,captures=contents('native-ui-graphics-preview.log'):gsub('capture.COMPLETE',''); assert(captures==1)
-- Two separate accepted activation requests are mandatory, even through the driver.
status=auto_request('activate'); assert(status[7]=='armed' and status[12]==campaign_key); no_dispatch('Automation first confirm only')
local armed=contents('automation-request.tsv'); automation_poll(); no_dispatch('Unchanged request is not retried')
files[automation_base .. 'automation-request.tsv']={armed:gsub('activate','previous')}; automation_poll(); no_dispatch('Same sequence different payload is not rerun')
click_hook=function() install_scene(campaign_fixture) end
status=auto_request('activate'); assert(status[7]=='input-sent' and #dispatches==1 and dispatches[1]==campaign_key)
status=auto_request('next'); assert(status[8]=='campaign_selection' and status[11]=='17')
assert(contents('native-ui-graphics-preview.log'):find('activation.observed_result\tstring\tNew Campaign',1,true))
-- Continue uses the same live Vortex validation and still needs both confirmations.
status=auto_request('next'); status=auto_request('next'); assert(status[10]=='Continue, button')
status=auto_request('activate'); assert(status[7]=='armed' and #dispatches==1)
click_hook=function() install_scene(unknown_setup) end
status=auto_request('activate'); assert(status[7]=='input-sent' and #dispatches==2 and dispatches[2]==continue_key)
status=auto_request('next'); assert(status[8]=='unknown' and status[11]=='0')
status=auto_request('activate'); assert(status[7]=='blocked' and #dispatches==2)
-- Valid owned requests with stale/expired/unsupported data are consumed and rejected.
for _,case in ipairs({{5,'999','generation'},{6,'999','revision'},{8,'tree.wrong','selection'},{9,'999','expired'},{9,'1006','expired'},{7,'loadstring','action'}}) do
    start(nil,fixture,true); status=auto_request('next',{[case[1]]=case[2]})
    assert(status[6]=='1' and status[7]=='rejected:'..case[3]); no_dispatch('Rejected driver request: '..case[3])
end
-- Other owners/sessions, malformed input and out-of-order requests cannot act.
for _,case in ipairs({{2,string.rep('b',32)},{3,'old game session'},{4,'3'},{4,'NaN'}}) do
    start(nil,fixture,true); status=auto_request('next',{[case[1]]=case[2]})
    assert(status[6]=='0' and status[11]=='0'); no_dispatch('Unowned or unordered input')
end
for _,raw in ipairs({'return os.execute("bad")\n','WH2REQ1\tbroken\n',string.rep('x',4097)..'\n','WH2REQ1\nnext\n'}) do
    start(nil,fixture,true); files[automation_base .. 'automation-request.tsv']={raw}; automation_poll()
    assert(auto_status()[6]=='0'); no_dispatch('Never evaluate malformed data')
end
-- Native UI readiness and lifecycle/revision changes reject queued commands.
start(nil,fixture,true); ready=false; status=auto_request('next'); assert(status[7]=='rejected:not-ready'); no_dispatch('Not ready')
start(nil,fixture,true); status=auto_request('next')
local old_generation,old_revision=status[4],status[5]; created()
status=auto_request('activate',{[5]=old_generation,[6]=old_revision}); assert(status[7]=='rejected:generation'); no_dispatch('Stale lifecycle')
start(nil,fixture,true); status=auto_request('next'); old_revision=status[5]; key('script_F3')
status=auto_request('activate',{[6]=old_revision}); assert(status[7]=='rejected:revision'); no_dispatch('Physical navigation intervened')
-- Confirmations cannot be borrowed between physical keyboard and automation.
start(nil,fixture,true); status=auto_request('next'); key('script_F4'); automation_poll()
status=auto_request('activate'); assert(status[7]=='blocked',status[7]); no_dispatch('Physical arm cannot be completed by driver')
start(nil,fixture,true); status=auto_request('next'); status=auto_request('activate'); key('script_F4'); no_dispatch('Driver arm cannot be completed by keyboard')
-- After an uncertain native click, duplicates must never repeat it.
start(nil,fixture,true); status=auto_request('next'); status=auto_request('activate')
click_hook=function() error('fixture error after native input') end
status,armed=auto_request('activate'); assert(status[7]=='error-after-input' and #dispatches==1)
automation_poll(); assert(#dispatches==1)
files[automation_base .. 'automation-request.tsv']={armed:gsub('activate','next')}; automation_poll(); assert(#dispatches==1)
-- Lost status output after input is also not a reason to repeat the command.
start(nil,fixture,true); status=auto_request('next'); status=auto_request('activate')
local before=auto_status()
files[automation_base .. 'automation-request.tsv']={table.concat({'WH2REQ1',string.rep('a',32),before[3],tostring(tonumber(before[6])+1),before[4],before[5],'activate',before[9],tostring(now+5)},'\t')..'\n'}
automation_status_failure=true; automation_poll(); assert(#dispatches==1)
automation_status_failure=false; automation_poll(); assert(#dispatches==1 and auto_status()[7]=='error-after-input')
-- Lease expiry/deletion revokes the channel and cancels its pending confirmation.
for _,remove in ipairs({false,true}) do
    start(nil,fixture,true); status=auto_request('next'); status=auto_request('activate')
    if remove then files[automation_base .. 'automation-enabled.tsv']=nil else now=1061 end
    automation_poll(); status=auto_status(); assert(status[15]=='0' and status[12]=='-' and automation_poll==nil)
    no_dispatch('Revoked automation lease')
end
local saved_pcall=pcall
pcall=function(fn,...) local ok,err=saved_pcall(fn,...); if not ok then return false,err end; return true end
start(nil,fixture,true)
pcall=saved_pcall
assert(automation_poll,'Channel initialization must not depend on pcall forwarding return values')
status=auto_request('next'); assert(status[10]=='New Campaign')
start(nil,fixture,true,false,true); assert(automation_poll,'Reuse the working output directory when later environment lookup is unavailable')
status=auto_request('next'); assert(status[10]=='New Campaign')
start(nil,fixture,true)
get_tm=function() return false end
files[automation_base .. 'automation-enabled.tsv']=nil; automation_poll()
files[automation_base .. 'automation-enabled.tsv']={'WH2LEASE1\t' .. string.rep('a',32) .. '\t1060\n'}
created()
assert(automation_poll,'Frontend real timers do not need the unavailable model timer manager')
status=auto_request('next'); assert(status[10]=='New Campaign')
start(nil,fixture,true,false,false,true)
assert(automation_poll==nil and not listeners['warhammer_accessibility_automation_real_timer'],'Failed timer setup removes its listener')
start(nil,fixture,true)
local unchanged=contents('automation-status.tsv')
fire('RealTimeTrigger',{string='unrelated_timer'})
assert(contents('automation-status.tsv')==unchanged and automation_poll,'Unrelated real timer event cannot consume a request')
automation_timer_failure=true
status=auto_request('next')
assert(status[7]=='timer-error' and status[15]=='0' and automation_poll==nil,'Rearm failure disables transport')
no_dispatch('Timer error during read-only navigation')
start(nil,fixture,true)
status=auto_request('next'); status=auto_request('activate')
automation_timer_failure=true
status=auto_request('activate')
assert(#dispatches==1 and status[7]=='error-after-input' and status[15]=='0' and automation_poll==nil,'Timer rearm failure after input is uncertain and cannot retry')
start(nil,fixture,true,true); assert(automation_poll==nil,'Failed setup removes its timer and cannot accept commands')
-- Real protocol bytes: accept Windows/Unix lines and reject incomplete or
-- ambiguous framing before any timer or native action can be enabled.
local lease_prefix='WH2LEASE1\t' .. string.rep('a',32) .. '\t1060'
for _,ending in ipairs({'\n','\r\n'}) do
    start(nil,fixture,lease_prefix .. ending)
    assert(automation_poll,'Complete LF/CRLF lease must enable transport')
    no_dispatch('Lease parsing must never send input')
end
for _,raw in ipairs({lease_prefix,lease_prefix .. '\n\n',lease_prefix .. '\r\r\n',
    '\239\187\191' .. lease_prefix .. '\n',lease_prefix .. '\textra\n',
    'WH2LEASE1\t' .. string.rep('a',31) .. 'g\t1060\n',
    'WH2LEASE1\t' .. string.rep('a',32) .. '\t1e3\n'}) do
    start(nil,fixture,raw)
    assert(automation_poll==nil,'Malformed lease cannot enable transport')
    no_dispatch('Malformed lease cannot send input')
end
start('campaign',fixture,true); assert(automation_poll==nil and next(listeners)==nil)
start('battle',fixture,true); assert(automation_poll==nil and next(listeners)==nil)
-- Campaign and battle contexts do not initialize any frontend listener or output.
for _, mode in ipairs({'campaign','battle'}) do
    start(mode); assert(next(listeners)==nil and next(files)==nil)
end
-- Contemporary Unix times must retain exact lease seconds and a real four
-- second confirmation despite the host's rounded os.time numeric result.
start(); now=1793250000; choose_graphics(); key('script_F4')
local rounded_time=os.time(); now=now+5
assert(os.time()==rounded_time,'Precision regression requires an unchanged rounded epoch')
key('script_F4'); no_dispatch('Five actual seconds expire a four-second confirmation')
start(nil,fixture,'WH2LEASE1\t' .. string.rep('a',32) .. '\t1793250060\n',false,false,false,1793250000)
assert(automation_poll,'Exact modern epoch lease must be accepted')
status=auto_request('next'); assert(status[16]=='1793250060' and status[10]=='New Campaign')
status=auto_request('activate'); assert(status[13]=='1793250004','Published confirmation deadline is exact Unix text')
now=now+5; status=auto_request('activate'); assert(status[7]=='blocked'); no_dispatch('Modern epoch confirmation expiry')
start(); now=1793318398; choose_graphics(); key('script_F4'); now=now+4; key('script_F4')
assert(#dispatches==1,'Confirmation remains valid across UTC midnight at exactly four seconds')
-- Read-only breadth-first discovery has an independent budget and covers a
-- complete synthetic 417-node tree without changing the proven scanner.
local function finish_lord_discovery()
    local state
    for page=1,32 do
        state=auto_request('discover')
        if state[7]~='discovery-page' then return state end
    end
    error('Discovery did not stop at its bounded page budget')
end
start(nil,lord_fixture,true)
status=finish_lord_discovery()
assert(status[7]=='discovery-complete' and status[8]=='lord_discovery')
assert(contents('native-ui-lord-discovery.jsonl'):find('Synthetic Lord 99',1,true))
local expected_scoped=0
for prefix in pairs(lord_fixture) do
    if prefix=='tree.child2' or prefix:find('tree.child2.',1,true)==1 then expected_scoped=expected_scoped+1 end
end
assert(contents('native-ui-lord-discovery.jsonl'):find('"total":' .. expected_scoped,1,true),'Every node in the selected panel must be examined')
assert(not contents('native-ui-graphics-preview.log'):find('capture.ENTER',1,true),'Discovery must not invoke or flood the legacy scanner')
local saw_start=false
for index=1,20 do
    status=auto_request('next')
    if status[10]=='Start Campaign' then saw_start=true; break end
end
assert(saw_start)
status=auto_request('activate'); assert(status[7]=='blocked')
key('script_F4'); no_dispatch('Start Campaign is read only in lord discovery')
start(nil,lord_fixture,true); status=auto_request('next')
assert(status[8]=='lord_discovery' and contents('bridge.jsonl'):find('Select Lord.',1,true))
no_dispatch('F2 lord discovery is read only')
start(nil,fixture,true); status=auto_request('discover'); assert(status[7]=='blocked')
assert(contents('native-ui-lord-discovery.jsonl')=='')
status=auto_request('next'); assert(status[10]=='New Campaign' and status[11]=='22')
start(nil,lord_fixture,true)
nodes['tree.child2.child0'].data.Visible=false
read_hook=function(node,method)
    if node.prefix:find('tree.child2.child0.child',1,true) then error('Hidden descendant must not be read') end
end
status=finish_lord_discovery(); assert(status[7]=='discovery-complete')
assert(not contents('native-ui-lord-discovery.jsonl'):find('Synthetic Lord',1,true))
read_hook=nil
start(nil,lord_fixture,true); status=auto_request('discover')
nodes=build_nodes(lord_fixture)
status=auto_request('discover')
assert(contents('native-ui-lord-discovery.jsonl'):find('"kind":"begin","run":2',1,true),'Recreated identities start a new read-only run')
nodes=build_nodes(fixture); status=auto_request('next')
assert(status[8]=='main' and status[10]=='New Campaign')
start(nil,lord_fixture,true); nodes['tree.child4'].data.Visible=true
status=auto_request('discover'); assert(status[7]=='blocked','Visible browser overlay blocks discovery')
start(nil,lord_fixture,true)
nodes['tree.child2.child0.child1.child0'].data.ChildCount=101
status=finish_lord_discovery(); assert(status[7]=='discovery-limited')
no_dispatch('Oversized child list cannot authorize actions')
start(nil,lord_fixture,true)
nodes['tree.child2.child1'].faults.GetStateText='function'
status=finish_lord_discovery(); assert(status[7]=='discovery-limited')
assert(contents('native-ui-lord-discovery.jsonl'):find('"text_type":"function"',1,true))
start(nil,lord_fixture,true); lord_write_failure=true
status=auto_request('discover'); assert(status[7]=='error')
key('script_F4'); no_dispatch('Discovery log failure cannot authorize actions')
-- Normal users have no automation lease: F2 itself must advance through
-- discovery pages, including breadth-first pages that add no readable text.
start(nil,lord_fixture,false)
local paged_by_f2=false
for step=1,600 do
    key('script_F2')
    if contents('native-ui-lord-discovery.jsonl'):find('"complete":true',1,true) then paged_by_f2=true; break end
end
assert(paged_by_f2 and contents('native-ui-lord-discovery.jsonl'):find('Synthetic Lord 99',1,true),'F2 must complete discovery without the developer Discover command')
no_dispatch('Keyboard-only discovery paging remains read only')
-- Labels operate on captured data only; no fresh native field watcher.
local lord_live=dofile('tests/fixtures/lord_reader_live.lua')
start(nil,lord_live,true); status=finish_lord_discovery()
-- 34 text entries plus 19 visible lord portraits in this 0.6.14 capture,
-- minus the folded check box label/description and two combo box labels.
local lord_total=49
assert(status[7]=='discovery-complete' and status[11]==tostring(lord_total))
local named={}
for n=1,lord_total do status=auto_request('next'); named[status[10]]=true end
for _,name in ipairs({'Selected lord: Tyrion','Race: High Elves','Faction: Eataine',
    'Campaign difficulty: Normal','Battle difficulty: Normal',
    'Faction effect: Diplomatic relations: +20 with High Elves',
    'Lord effect: Recruit rank: +3 for Lothern Sea Guard units ( Lord\'s army)'}) do assert(named[name],name) end
local saw_intro=false
for name in pairs(named) do if name:find('Campaign introduction: selected.',1,true)==1 then saw_intro=true end end
assert(saw_intro); no_dispatch('Captured semantic presentation is read only')
start(nil,lord_live,true); status=finish_lord_discovery()
nodes['tree.child2.child0.child2.child0.child4'].data.GetStateText='Synthetic changed lord'
status=auto_request('discover'); assert(status[7]=='discovery-page' and status[9]=='-','Explicit refresh clears the old selection')
status=finish_lord_discovery()
local refreshed=false
for n=1,lord_total do status=auto_request('next'); if status[10]=='Selected lord: Synthetic changed lord' then refreshed=true end end
assert(refreshed); no_dispatch('Explicit snapshot refresh never dispatches')
start(nil,lord_live,false)
local match_before=string.match; string.match=nil
for n=1,100 do key('script_F2') end
string.match=match_before
assert(not contents('native-ui-graphics-preview.log'):find('navigation.ERROR',1,true),'Captured labels do not depend on string.match')
no_dispatch('Host-compatible read-only semantic labels')
-- 0.6.18: in-game, the first s:find(p,1,true) on captured Lord text was
-- followed by s:sub() returning a non-string. Simulate that fault.
local real_find, real_sub = string.find, string.sub
local function restore_strings() string.find, string.sub = real_find, real_sub end
string.find=function(s,...)
    if type(s)=='string' and real_sub(s,1,5)=='lord:' then string.sub=function() return 0 end end
    return real_find(s,...)
end
start(nil,lord_live,true); status=finish_lord_discovery()
local labelled={}
for n=1,lord_total do status=auto_request('next'); labelled[status[10]]=true end
restore_strings()
assert(string.sub('abc',1,1)=='a','Lord labels never call string.find on captured keys')
assert(labelled['Race attribute: Intrigue: Influence can be spent on superior Lords, or used to affect diplomacy between factions.'],'Race attribute label')
assert(labelled['Selected lord: Tyrion'] and labelled['Faction: Eataine'])
assert(not contents('native-ui-graphics-preview.log'):find('ERROR',1,true))
no_dispatch('Labels avoid string.find')
-- If a string call does break mid-navigation, the report is logged plainly
-- and the request still completes.
start(nil,lord_live,false)
-- Pass the shortcut trace's 64-sample cap so only navigation logs remain.
for n=1,70 do key('script_F2') end
read_hook=function() read_hook=nil; string.sub=function() return 0 end end
key('script_F2')
restore_strings()
local trace=contents('native-ui-graphics-preview.log')
assert(trace:find('navigation.REPORT_FAILED	string	after-success',1,true),'Broken report is logged plainly')
no_dispatch('Navigation report guard')
-- The string.find probe runs only when its flag file exists.
start(nil,lord_live,false)
assert(not contents('native-ui-graphics-preview.log'):find('probe.',1,true),'Probe is off by default')
probe_flag=true; start(nil,lord_live,false); probe_flag=false
trace=contents('native-ui-graphics-preview.log')
assert(trace:find('probe.find	string	ok number 1',1,true) and trace:find('probe.sub_method	string	ok string',1,true)
    and trace:find('probe.tostring	string	ok string',1,true),'Probe results logged')
no_dispatch('Opt-in string probe')
-- 0.6.19: a manual change to a watched named field restarts discovery on the
-- next browse; unchanged fields never do.
start(nil,lord_live,true); status=finish_lord_discovery()
for n=1,5 do status=auto_request('next') end
assert(not contents('native-ui-lord-discovery.jsonl'):find('"kind":"stale"',1,true),'Unchanged fields are not stale')
nodes['tree.child2.child0.child2.child0.child4'].data.GetStateText='Synthetic changed lord'
status=auto_request('next')
assert(status[7]=='completed' and contents('native-ui-lord-discovery.jsonl'):find('"kind":"stale"',1,true),'Change detected')
assert(says('Screen updated. ',', 1 of'),'Change is announced from entry 1')
local fresh=false
for n=1,40 do status=auto_request('next'); if status[10]=='Selected lord: Synthetic changed lord' then fresh=true; break end end
assert(fresh,'New lord is read after the automatic refresh'); no_dispatch('Manual change refresh is read only')
start(nil,lord_live,false)
for n=1,40 do key('script_F2') end
assert(not contents('native-ui-lord-discovery.jsonl'):find('"kind":"stale"',1,true))
nodes['tree.child2.child0.child2.child2.child3'].data.Visible=false
key('script_F3')
assert(says('Screen updated. ',', 1 of'),'Hidden watched field restarts from entry 1 even on F3')
assert(not contents('native-ui-graphics-preview.log'):find('navigation.ERROR',1,true))
no_dispatch('Hidden field refresh is read only')
-- 0.6.20: a rejected Lord context logs its reason once, without acting.
start(nil,lord_live,false)
nodes['tree.child4'].data.Visible=true
key('script_F2'); key('script_F2')
local rejects=0
for _ in contents('native-ui-graphics-preview.log'):gmatch('lord%.context_reject	string	extra 4 id=browser visible=true') do rejects=rejects+1 end
assert(rejects==1,'Rejection reason logged once per distinct reason')
nodes['tree.child4'].data.Visible=false
key('script_F2')
assert(says('Select Lord.'),'Reader resumes once the layer hides')
no_dispatch('Context diagnostics are read only')
-- 0.6.20 live: selecting a lord leaves a hidden tooltip_campaign_select_lord
-- root layer; a resting mouse shows Tooltip. Neither may disable the reader.
local tooltip_layout={}
for prefix,row in pairs(lord_live) do local copy={}; for k,v in pairs(row) do copy[k]=v end; tooltip_layout[prefix]=copy end
tooltip_layout['tree'].ChildCount=7
tooltip_layout['tree.child5']={Id='tooltip_campaign_select_lord',Visible=false,ChildCount=0,GetStateText='',GetTooltipText='',CurrentState='',IsInteractive=false}
tooltip_layout['tree.child6']={Id='Tooltip',Visible=true,ChildCount=0,GetStateText='Teclis',GetTooltipText='',CurrentState='',IsInteractive=false}
start(nil,tooltip_layout,true); status=finish_lord_discovery()
assert(status[7]=='discovery-complete' and status[11]==tostring(lord_total),'Tooltip layers do not block discovery')
status=auto_request('next'); assert(status[8]=='lord_discovery' and status[10]=='Select Lord')
assert(not contents('native-ui-graphics-preview.log'):find('lord.context_reject',1,true))
no_dispatch('Tooltip layers are read only')
-- 0.6.22: double-confirmed lord selection from lord-choice entries only.
local portrait='tree.child2.child0.child1.child0.child1.child0.child0.child1'
local tyrion_portrait='tree.child2.child0.child1.child0.child1.child0.child0.child0'
local function browse_to(label, limit)
    for n=1,(limit or 200) do key('script_F2'); if last():find(label,1,true) then return true end end
    return false
end
local function capture_complete() return contents('native-ui-lord-discovery.jsonl'):find('"complete":true',1,true) end
-- Keyboard: complete capture, arm, confirm; observed result from the fresh capture.
start(nil,lord_live,false)
for n=1,lord_total+5 do key('script_F2') end
assert(capture_complete(),'Capture completes before selection tests')
assert(browse_to('Teclis, radio button, not checked'),'Portraits are spoken as lord choices')
assert(not last():find('read only',1,true),'Lord choices are actionable, not read only')
key('script_F4'); assert(says('Select Teclis. Press again to confirm.')); no_dispatch('First F4 only arms')
click_hook=function()
    nodes[tyrion_portrait].data.CurrentState='active'; nodes[portrait].data.CurrentState='selected'
    nodes['tree.child2.child0.child2.child0.child4'].data.GetStateText='Teclis'
end
key('script_F4'); assert(#dispatches==1 and dispatches[1]==portrait,'Second F4 selects exactly the chosen portrait')
assert(says('Teclis chosen.'))
click_hook=nil
key('script_F2')
assert(contents('native-ui-graphics-preview.log'):find('activation.observed_result\tstring\tlord-match:Teclis',1,true),'Selection observed from the fresh capture')
assert(says('Teclis is now selected. ',', 1 of'),'Confirmation spoken with the first fresh entry')
-- The selected lord and read-only entries never dispatch.
assert(browse_to('Teclis, radio button, checked'))
key('script_F4'); assert(says('Teclis is already selected.'))
assert(browse_to('Selected lord: Teclis'))
key('script_F4'); assert(says('Selected lord: Teclis'),'F4 on text is silent')
assert(#dispatches==1,'No further dispatch')
-- If the game ignores the click, the fresh capture says so.
start(nil,lord_live,false)
for n=1,lord_total+5 do key('script_F2') end
assert(browse_to('Teclis, radio button, not checked'))
key('script_F4'); key('script_F4'); assert(#dispatches==1)
key('script_F2')
assert(contents('native-ui-graphics-preview.log'):find('activation.observed_result\tstring\tlord-mismatch:Tyrion',1,true))
assert(last():find('Selection not confirmed: the selected lord is Tyrion.',1,true),'Mismatch is spoken')
-- Browsing between F4 presses cancels; expiry and identity changes block.
start(nil,lord_live,false)
for n=1,lord_total+5 do key('script_F2') end
assert(browse_to('Teclis, radio button, not checked'))
key('script_F4'); key('script_F3'); assert(browse_to('Teclis, radio button, not checked'))
key('script_F4'); assert(last():find('Press again',1,true),'Browsing cancelled the first confirmation'); no_dispatch('Cancelled confirmation')
now=now+5
key('script_F4'); assert(says('Confirmation timed out')); no_dispatch('Expired confirmation')
key('script_F4'); assert(last():find('Press again',1,true))
nodes[portrait].data.Id='Teclis impostor'
key('script_F4'); assert(says('The screen changed. Press F2 and try again.') and contents('native-ui-graphics-preview.log'):find('activation.lord_unverified\tstring\tidentity',1,true)); no_dispatch('Changed identity')
-- A changed watched field blocks before arming.
start(nil,lord_live,false)
for n=1,lord_total+5 do key('script_F2') end
assert(browse_to('Teclis, radio button, not checked'))
nodes['tree.child2.child0.child2.child2.child1.child3'].data.GetStateText='Synthetic faction'
key('script_F4'); assert(says('The screen changed. Press F2 and try again.')); no_dispatch('Stale capture')
-- A lord choice from an incomplete capture cannot be selected.
start(nil,lord_live,false)
local early=false
for n=1,200 do
    key('script_F2')
    if last():find('Teclis, radio button',1,true) then early=not capture_complete(); break end
end
if early then key('script_F4'); assert(says('Still reading this screen')); no_dispatch('Incomplete capture') end
-- A capture that hit a safety limit cannot be used to choose a lord.
local limited_layout={}
for prefix,row in pairs(lord_live) do local copy={}; for k,v in pairs(row) do copy[k]=v end; limited_layout[prefix]=copy end
limited_layout['tree.child2.child0.child2.child0.child4'].GetStateText=string.rep('x',1200)
start(nil,limited_layout,false)
assert(browse_to('Teclis, radio button, not checked'),contents('native-ui-graphics-preview.log'):match('navigation%.ERROR[^\n]*') or last())
assert(contents('native-ui-lord-discovery.jsonl'):find('"limited":true',1,true))
key('script_F4'); assert(says('This screen could not be read completely, so choosing is unavailable.'),last()); no_dispatch('Limited capture')
-- Automation needs two separately accepted requests, like the keyboard.
start(nil,lord_live,true); status=finish_lord_discovery()
local choice_key
for n=1,lord_total do status=auto_request('next'); if status[10]=='Lord choice: Teclis' then choice_key=status[9]; break end end
assert(choice_key=='lord:' .. portrait .. ':choice')
status=auto_request('activate'); assert(status[7]=='armed' and status[12]==choice_key); no_dispatch('Automation first confirm')
status=auto_request('activate'); assert(status[7]=='input-sent' and #dispatches==1 and dispatches[1]==portrait)
-- 0.6.28: Start Campaign always needs a second, separately accepted request.
start(nil,lord_live,true); status=finish_lord_discovery()
for n=1,lord_total do status=auto_request('next'); if status[10]=='Start Campaign' then break end end
assert(status[10]=='Start Campaign')
status=auto_request('activate'); assert(status[7]=='armed'); no_dispatch('First request only asks')
status=auto_request('activate'); assert(status[7]=='input-sent' and #dispatches==1 and dispatches[1]=='tree.child2.child1.child0','Second request starts')
-- 0.6.24: NVDA-style speech. Exact announcements pin the format.
local function spoken() return (last():match('"text":"(.-)"}$') or ''):gsub('\\"','"') end
local function no_engine_words(text)
    return not text:find('read only',1,true) and not text:find(', active',1,true) and not text:find('NewState',1,true)
        and not text:find('Lord choice:',1,true) and not text:find('campaign choice',1,true)
end
-- 0.6.61: "ready" is spoken once the key timer ticks steadily (the intro
-- movies stop the game's timers), not at load.
local ready_text='Warhammer accessibility 0.6.64 ready. Arrow keys move, Enter activates.'
local function ready_count()
    local n,from=0,1
    local bridge=contents('bridge.jsonl')
    while true do local a,b=bridge:find(ready_text,from,true); if not a then return n end; n=n+1; from=b+1 end
end
local function ticks(count) for n=1,count do assert(keys_poll,'Key timer active'); keys_poll() end end
start()
assert(ready_count()==0,'Not spoken at load, while movies may play')
ticks(14); assert(ready_count()==0,'Not before 15 steady ticks')
ticks(1); assert(ready_count()==1,'Short startup message after steady ticks')
ticks(40); assert(ready_count()==1,'Spoken once')
assert(contents('native-ui-graphics-preview.log'):find('startup.ready	string	ticks=15',1,true))
-- A pause of two seconds or more (a movie between ticks) starts the count again.
start()
ticks(10); now=now+3; ticks(14); assert(ready_count()==0,'Count restarts after a pause')
ticks(1); assert(ready_count()==1,'Spoken after 15 ticks since the pause')
-- Ticks a second apart are steady (the clock has whole seconds).
start()
for n=1,15 do now=now+1; ticks(1) end; assert(ready_count()==1,'One-second steps do not restart the count')
-- A clock that cannot be read falls back to counting ticks.
start()
local saved_date=os.date; os.date=function() error('fixture clock failure') end
ticks(15); os.date=saved_date; assert(ready_count()==1,'Unreadable clock still announces')
-- Without the key timer (no frontend key channel) it is spoken at load, as before.
start(); assert(ready_count()==0)
local saved_timer=real_timer; real_timer=nil; dofile('diagnostics/graphics_preview.lua'); real_timer=saved_timer
assert(ready_count()==1,'Spoken at load without the key timer')
start()
ticks(15)
key('script_F2'); assert(spoken()=='Main menu. New Campaign, button, 1 of 22',spoken())
key('script_F2'); assert(spoken()=='Continue Campaign, button, unavailable, 2 of 22',spoken())
key('script_F3'); assert(spoken()=='New Campaign, button, 1 of 22','Screen name is spoken once')
start(nil,campaign_fixture)
key('script_F2'); assert(spoken()=='Select Campaign. The Eye of the Vortex, radio button, checked, 1 of 17',spoken())
key('script_F2'); assert(spoken()=='Mortal Empires, radio button, not checked, 2 of 17',spoken())
key('script_F2'); assert(spoken()=='Continue, button, 3 of 17',spoken())
-- Lord setup: roles, states, merged check box, combo boxes, no duplicates.
start(nil,lord_live,false)
local heard={}
for n=1,lord_total+5 do key('script_F2'); local text=spoken(); heard[#heard+1]=text; assert(no_engine_words(text),text) end
local function heard_exact(pattern)
    for _,text in ipairs(heard) do if text:match(pattern) then return true end end
    return false
end
assert(heard[1]=='Select Lord. Select Lord, heading, 1 of ' .. lord_total,heard[1])
assert(heard_exact('^Start Campaign, button, %d+ of 49$'),'Start Campaign is a button')
assert(heard_exact('^Enable campaign introduction, check box, checked, %d+ of 49, Start the campaign with additional introductory content'),'One check box with its description')
assert(heard_exact('^Campaign difficulty, combo box, Normal, %d+ of 49$') and heard_exact('^Battle difficulty, combo box, Normal, %d+ of 49$'))
assert(heard_exact('^Race Attributes, heading, %d+ of 49$') and heard_exact('^Map, tab, selected, %d+ of 49$') and heard_exact('^Movie, tab, %d+ of 49$'))
assert(heard_exact('^Settings, button, %d+ of 49$') and heard_exact('^Selected lord: Tyrion, %d+ of 49$'))
assert(heard_exact('^Tyrion, radio button, checked, %d+ of 49$') and heard_exact('^Teclis, radio button, not checked, %d+ of 49$'))
assert(not heard_exact('^Campaign, %d+ of') and not heard_exact('^Battle, %d+ of') and not heard_exact('^Enable campaign introduction, %d+ of'),'No repeated labels')
-- F4 on a button the mod does not support says so; F4 on text stays silent.
assert(browse_to('Start Campaign, button'))
key('script_F4'); assert(spoken()=='Start the campaign as Tyrion, High Elves, Eataine? Press Enter again to start.',spoken()); no_dispatch('Start Campaign asks first')
key('script_F3'); assert(browse_to('Start Campaign, button'))
key('script_F4'); assert(spoken()=='Start the campaign as Tyrion, High Elves, Eataine? Press Enter again to start.','Moving away cancelled the first press'); no_dispatch('Cancelled start')
assert(browse_to('Selected lord: Tyrion'))
key('script_F4'); assert(spoken():find('Selected lord: Tyrion',1,true)==1,'F4 on text is silent'); no_dispatch('Text is not actionable')
-- 0.6.50: the intro check box toggles with one press (the tutorial locks End Turn).
assert(browse_to('Enable campaign introduction, check box'))
key('script_F4'); assert(spoken()=='Enable campaign introduction. Press again to confirm.',spoken()); no_dispatch('Confirm option asks first')
key('script_F4'); assert(spoken()=='Enable campaign introduction, not checked',spoken())
assert(#dispatches==1 and dispatches[1]:find('child',1,true),'One click on the check box')
key('script_F4'); assert(spoken()=='Enable campaign introduction. Press again to confirm.','Enter right after toggling stays on the check box: '..spoken())
key('script_F2'); assert(not spoken():find(', 1 of 49',1,true) and not spoken():find('No item selected',1,true),'Arrow continues after the check box: '..spoken())
-- Many automatic refreshes in one session never exhaust the discovery log.
start(nil,lord_live,false)
key('script_F2')
for n=1,80 do
    nodes['tree.child2.child0.child2.child0.child4'].data.GetStateText=(n%2==0) and 'Tyrion' or 'Teclis'
    key('script_F2')
end
assert(not contents('native-ui-graphics-preview.log'):find('navigation.ERROR',1,true),'Refreshes keep working')
assert(says('Screen updated. '),last())
no_dispatch('Refresh loop is read only')
-- 0.6.25 live: a resting mouse leaves a portrait in "hover"; it stays listed
-- and choosable, and refusals name their reason in the log.
local hover_layout={}
for prefix,row in pairs(lord_live) do local copy={}; for k,v in pairs(row) do copy[k]=v end; hover_layout[prefix]=copy end
hover_layout[portrait].CurrentState='hover'
start(nil,hover_layout,false)
assert(browse_to('Teclis, radio button, not checked'),'Hovered portrait is still listed')
key('script_F4'); key('script_F4'); assert(#dispatches==1 and dispatches[1]==portrait,'Hovered portrait can be chosen')
start(nil,lord_live,false)
assert(browse_to('Teclis, radio button, not checked'))
nodes[portrait].data.CurrentState='down'
key('script_F4'); assert(says('The screen changed. Press F2 and try again.'))
assert(contents('native-ui-graphics-preview.log'):find('activation.lord_blocked\tstring\tstate:down',1,true)); no_dispatch('Pressed state blocks')
-- 0.6.26: single press by default (no confirm-activations.flag).
single_press=true
start(); key('script_F2'); assert(says('New Campaign, button'))
click_hook=function() install_scene(campaign_fixture) end
key('script_F4'); assert(#dispatches==1 and dispatches[1]==campaign_key,'One press activates')
assert(spoken()=='New Campaign activated.',spoken()); click_hook=nil
start(nil,lord_live,false)
assert(browse_to('Teclis, radio button, not checked'))
key('script_F4'); assert(#dispatches==1 and dispatches[1]==portrait and spoken()=='Teclis chosen.','One press chooses a lord')
start(nil,lord_live,true); status=finish_lord_discovery()
for n=1,lord_total do status=auto_request('next'); if status[10]=='Lord choice: Teclis' then break end end
status=auto_request('activate'); assert(status[7]=='input-sent' and #dispatches==1,'One automation request activates')
start(nil,lord_live,false)
assert(browse_to('Start Campaign, button'))
key('script_F4'); assert(spoken()=='Start the campaign as Tyrion, High Elves, Eataine? Press Enter again to start.',spoken()); no_dispatch('Start Campaign asks even with single press')
key('script_F4'); assert(#dispatches==1 and dispatches[1]=='tree.child2.child1.child0','Second press starts the campaign')
assert(spoken()=='Starting the campaign. An intro movie plays first; press Escape to skip it.',spoken())
assert(contents('native-ui-graphics-preview.log'):find('activation.dispatch\tstring\tStart Campaign',1,true))
-- 0.6.62: Select Lord on another PC (no exact counts). Only a visible or
-- unreadable extra root layer blocks; the chosen element is re-checked.
local function lord_variant(change)
    local layout={}
    for prefix,row in pairs(lord_live) do local copy={}; for k,v in pairs(row) do copy[k]=v end; layout[prefix]=copy end
    change(layout); return layout
end
local function starts_here(layout, message)
    start(nil,layout,false)
    assert(browse_to('Start Campaign, button'),message .. ': Start Campaign listed')
    key('script_F4'); assert(spoken()=='Start the campaign as Tyrion, High Elves, Eataine? Press Enter again to start.',message .. ': ' .. spoken())
    key('script_F4'); assert(#dispatches==1 and dispatches[1]=='tree.child2.child1.child0',message .. ': started')
end
starts_here(lord_variant(function(l) l['tree'].ChildCount=4; l['tree.child4']=nil end),'No browser layer')
starts_here(lord_variant(function(l)
    l['tree'].ChildCount=7
    l['tree.child5']={Id='dlc_popup',Visible=false,ChildCount=0,GetStateText='',GetTooltipText='',CurrentState='',IsInteractive=false}
    l['tree.child6']={Id='browser',Visible=false,ChildCount=0,GetStateText='',GetTooltipText='',CurrentState='',IsInteractive=false}
end),'Hidden extra layers and a second browser')
starts_here(lord_variant(function(l)
    l['tree.child2'].ChildCount=7
    l['tree.child2.child6']={Id='dlc_banner',Visible=false,ChildCount=0,GetStateText='',GetTooltipText='',CurrentState='',IsInteractive=false}
end),'Extra hidden panel child')
local dialog_layout=lord_variant(function(l)
    l['tree'].ChildCount=6
    l['tree.child5']={Id='dialogue_box',Visible=true,ChildCount=0,GetStateText='',GetTooltipText='',CurrentState='',IsInteractive=true}
end)
start(nil,dialog_layout,false); key('script_F2'); key('script_F4'); key('script_F4')
assert(not last():find('Select Lord',1,true),'A visible dialog layer is not read as Select Lord'); no_dispatch('Visible dialog blocks')
assert(contents('native-ui-graphics-preview.log'):find('lord.context_reject\tstring\textra 5 id=dialogue_box visible=true',1,true))
start(nil,lord_live,false); nodes['tree.child4'].faults.Visible='throw'; key('script_F2')
assert(contents('native-ui-graphics-preview.log'):find('lord.context_reject\tstring\textra 4 unreadable',1,true))
key('script_F4'); key('script_F4'); no_dispatch('Unreadable layer blocks')
-- A dialog appearing between the confirmation and the start cancels it.
start(nil,lord_variant(function(l)
    l['tree'].ChildCount=6
    l['tree.child5']={Id='dialogue_box',Visible=false,ChildCount=0,GetStateText='',GetTooltipText='',CurrentState='',IsInteractive=true}
end),false)
assert(browse_to('Start Campaign, button'),'A hidden dialog layer does not block'); key('script_F4')
nodes['tree.child5'].data.Visible=true
key('script_F4'); no_dispatch('Dialog after the first press stops the start')
assert(says('The screen changed. Press F2 and try again.'),last())
-- Timeout and a changed lord stop the start.
start(nil,lord_live,false)
assert(browse_to('Start Campaign, button'))
key('script_F4'); now=now+11
key('script_F4'); assert(spoken()=='Confirmation timed out. Press Enter again.'); no_dispatch('Timed-out start')
key('script_F4'); assert(spoken()=='Start the campaign as Tyrion, High Elves, Eataine? Press Enter again to start.')
nodes['tree.child2.child0.child2.child0.child4'].data.GetStateText='Teclis'
key('script_F4'); assert(says('The screen changed. Press F2 and try again.')); no_dispatch('Changed lord stops the start')
nodes['tree.child2.child0.child2.child0.child4'].data.GetStateText='Tyrion'
start(nil,lord_live,false)
assert(browse_to('Start Campaign, button'))
nodes['tree.child2.child1.child0'].data.CurrentState='inactive'
key('script_F4'); assert(says('The screen changed. Press F2 and try again.')); no_dispatch('Unavailable Start Campaign button')
assert(contents('native-ui-graphics-preview.log'):find('activation.lord_blocked\tstring\tstate:inactive',1,true))
-- Companion keys: same handlers, bound to session and UI generation.
local function reader_state()
    local text=contents('reader-state.tsv')
    local values={}
    for value in text:gmatch('[^\t\n]+') do values[#values+1]=value end
    return values
end
local key_files_seq=0
local function send_keys(owner, actions, session_value, generation_value)
    local state=reader_state()
    local lines={'WH2KEYS1\t' .. owner .. '\t' .. (session_value or state[2]) .. '\t' .. (generation_value or state[3])}
    for _,action in ipairs(actions) do key_files_seq=key_files_seq+1; lines[#lines+1]=key_files_seq .. '\t' .. action end
    files[automation_base .. 'keys.tsv']={table.concat(lines,'\n') .. '\n'}
    assert(keys_poll,'Key timer active'); keys_poll()
end
start()
assert(keys_poll and automation_poll==nil,'Key timer runs without an automation lease')
local state=reader_state()
assert(state[1]=='WH2READER1' and state[4]=='1','Reader state published in the frontend')
send_keys('companion-a',{'next','next'})
assert(not contents('bridge.jsonl'):find('New Campaign, button',1,true),'Backlog from before the reader saw this companion is skipped')
send_keys('companion-a',{'next'}); assert(spoken()=='Main menu. New Campaign, button, 1 of 22',spoken())
send_keys('companion-a',{'previous'}); assert(spoken()=='Quit, button, 22 of 22',spoken())
send_keys('companion-a',{'first'}); assert(spoken()=='New Campaign, button, 1 of 22',spoken())
send_keys('companion-a',{'last'}); assert(spoken()=='Quit, button, 22 of 22',spoken())
send_keys('companion-a',{'first','letter:q'}); assert(says('Quest Battle, button'),spoken())
send_keys('companion-a',{'letter:q'}); assert(says('Quick Battle, button'),spoken())
send_keys('companion-a',{'letter:q'}); assert(says('Quit, button'),spoken())
send_keys('companion-a',{'letter:q'}); assert(says('Quest Battle, button'),'First-letter navigation wraps')
local before=spoken()
send_keys('companion-a',{'letter:z'}); assert(spoken()==before,'No match stays silent')
send_keys('companion-a',{'next'},'another-session'); assert(spoken()==before,'Other session ignored')
send_keys('companion-a',{'next'},nil,'99'); assert(spoken()==before,'Other UI generation ignored')
send_keys('companion-a',{'bogus','letter:1'}); assert(spoken()==before)
assert(contents('native-ui-graphics-preview.log'):find('keys.rejected\tstring\taction',1,true))
send_keys('companion-b',{'next'}); assert(spoken()==before,'A restarted companion starts fresh')
local queued={}
for n=1,10 do queued[n]='next' end
send_keys('companion-b',queued)
assert(contents('native-ui-graphics-preview.log'):find('keys.skipped\tstring\tmore than eight pending',1,true))
send_keys('companion-b',{'first'}); assert(spoken()=='New Campaign, button, 1 of 22')
click_hook=function() install_scene(campaign_fixture) end
send_keys('companion-b',{'activate'}); assert(#dispatches==1 and dispatches[1]==campaign_key,'Enter activates through the same handler')
click_hook=nil
send_keys('companion-b',{'next'}); assert(spoken()=='Select Campaign. The Eye of the Vortex, radio button, checked, 1 of 17',spoken())
assert(reader_state()[5]=='campaign_selection','Reader state follows the screen')
single_press=false
-- Observed retained DLC header hover is bounded to its exact native node.
local dlc_header='tree.child2.child1.child0.child0.child3.child0'
start(); nodes[dlc_header].data.CurrentState='hover'; choose_campaign(); key('script_F4'); key('script_F4')
assert(#dispatches==1 and dispatches[1]==campaign_key,'Observed unrelated DLC header hover permits verified New Campaign')
-- 0.6.60: an unrelated element's state or ID on another PC does not block;
-- a change between the two presses does.
for _,state in ipairs({'inactive','pressed','selected'}) do
    start(); nodes[dlc_header].data.CurrentState=state; choose_campaign(); key('script_F4'); key('script_F4')
    assert(#dispatches==1,'Unrelated header state on another PC')
    start(); choose_campaign(); key('script_F4'); nodes[dlc_header].data.CurrentState=state; key('script_F4')
    no_dispatch('Header state changed between presses')
end
start(); nodes[dlc_header].data.CurrentState='hover'; nodes[dlc_header].data.Id='unknown_header'
choose_campaign(); key('script_F4'); key('script_F4'); assert(#dispatches==1,'Unrelated header ID on another PC')
start(); nodes[dlc_header].data.CurrentState='hover'; choose_campaign(); key('script_F4')
nodes[dlc_header].data.CurrentState='active'; key('script_F4'); no_dispatch('A changed raw header state cancels confirmation')
-- 0.6.42: with saves present, Continue/Load Campaign are enabled; New Campaign still opens.
single_press=true
start()
for _,prefix in ipairs({'tree.child2.child1.child0.child0.child0.child0.child2','tree.child2.child1.child0.child0.child0.child0.child2.child0',
    'tree.child2.child1.child0.child0.child0.child0.child3','tree.child2.child1.child0.child0.child0.child0.child3.child0'}) do
    nodes[prefix].data.CurrentState='active'
end
key('script_F2'); assert(says('New Campaign, button'))
key('script_F2'); assert(says('Continue Campaign, button, 2 of 22') and not says('unavailable'),last())
key('script_F3')
click_hook=function() install_scene(campaign_fixture) end
key('script_F4'); assert(#dispatches==1 and dispatches[1]==campaign_key,'New Campaign opens with saves present')
click_hook=nil; single_press=false
-- 0.6.60 (first outside trial): another PC's main menu differs from the one
-- recorded here (extra element, other text); New Campaign and Continue
-- Campaign open with one press; Load Campaign is not supported yet.
single_press=true
local other_pc={}
for prefix,row in pairs(fixture) do other_pc[prefix]={}; for k,v in pairs(row) do other_pc[prefix][k]=v end end
local banner='tree.child2.child1.child0.child0'
other_pc[banner .. '.child9']={Id='news_ticker',Visible=true,IsInteractive=false,GetStateText='Latest news',GetTooltipText='',CurrentState='NewState',ChildCount=0}
other_pc[banner].ChildCount=10
other_pc['tree.child2.child1.child0.child0.child3.child0'].GetStateText='Other DLC banner'
start(nil,other_pc)
key('script_F2'); assert(says('New Campaign, button, 1 of 22'),last())
click_hook=function() install_scene(campaign_fixture) end
key('script_F4'); assert(#dispatches==1 and dispatches[1]==campaign_key and says('New Campaign activated.'),'Other PC: '..last())
click_hook=nil
assert(not contents('bridge.jsonl'):find('Could not verify',1,true))
local continue_campaign='tree.child2.child1.child0.child0.child0.child0.child2'
start(nil,other_pc)
key('script_F2'); key('script_F2'); assert(says('Continue Campaign, button, unavailable'),last())
key('script_F4'); assert(#dispatches==0 and says('Continue Campaign is unavailable.'),last())
start(nil,other_pc)
nodes[continue_campaign].data.CurrentState='active'; nodes[continue_campaign .. '.child0'].data.CurrentState='active'
key('script_F2'); key('script_F2'); assert(says('Continue Campaign, button, 2 of 22'),last())
key('script_F4'); assert(#dispatches==1 and dispatches[1]==continue_campaign and says('Continue Campaign activated.'),last())
start(nil,other_pc)
for n=1,3 do key('script_F2') end; assert(says('Load Campaign'),last())
key('script_F4'); assert(#dispatches==0 and says('Not supported yet.'),last())
-- A replaced or hidden Continue Campaign between selection and press is refused.
start(nil,other_pc); nodes[continue_campaign].data.CurrentState='active'
key('script_F2'); key('script_F2'); nodes[continue_campaign].address=newproxy()
key('script_F4'); assert(#dispatches==0 and says('The screen changed. Press F2 and try again.'),last())
single_press=false
-- 0.6.64 (trial run 3): Select Lord as a sequence of choices: race, lord,
-- campaign setup (difficulty lists, details, Start Campaign); Backspace goes back.
single_press, flat_lords = true, false
local function ticks_until(n) for _=1,n do assert(keys_poll,'Key timer active'); keys_poll() end end
local function back_key() send_keys('companion-steps',{'back'}) end
local tyrion='tree.child2.child0.child1.child0.child1.child0.child0.child0'
local teclis='tree.child2.child0.child1.child0.child1.child0.child0.child1'
local dropdown='tree.child2.child0.child2.child2.child3.child2.child0'
local function steps_start(layout)
    start(nil,layout or lord_live,false)
    send_keys('companion-steps',{}) -- the companion connects (no backlog)
end
steps_start()
key('script_F2'); assert(spoken()=='Select Lord. Choose a race. High Elves, 3 lords, 1 of 6',spoken())
for _,expected in ipairs({'Lizardmen, 2 lords, 2 of 6','Dark Elves, 3 lords, 3 of 6','Skaven, 3 lords, 4 of 6',
    'Vampire Coast, 4 lords, 5 of 6','Tomb Kings, 4 lords, 6 of 6','High Elves, 3 lords, 1 of 6'}) do
    key('script_F2'); assert(spoken()==expected,spoken())
end
back_key(); assert(spoken()=='This is the first step. Escape returns to Select Campaign.',spoken())
key('script_F2'); key('script_F4'); assert(spoken()=='Lizardmen. Lord Mazdamundi, radio button, not checked, 1 of 3',spoken()); no_dispatch('Entering a race only reads')
key('script_F3'); assert(spoken()=='Back, button, 3 of 3',spoken())
key('script_F4'); assert(spoken()=='Choose a race. Lizardmen, 2 lords, 2 of 6',spoken())
key('script_F3'); key('script_F4'); assert(spoken()=='High Elves. Tyrion, radio button, checked, 1 of 4',spoken())
back_key(); assert(spoken()=='Choose a race. High Elves, 3 lords, 1 of 6',spoken())
key('script_F4'); key('script_F2'); assert(spoken()=='Teclis, radio button, not checked, 2 of 4',spoken())
-- Choosing a lord: one press, then the setup is read once the game shows it.
click_hook=function()
    nodes[tyrion].data.CurrentState='active'; nodes[teclis].data.CurrentState='selected'
    nodes['tree.child2.child0.child2.child0.child4'].data.GetStateText='Teclis'
end
key('script_F4'); assert(#dispatches==1 and dispatches[1]==teclis and spoken()=='Teclis chosen.',spoken()); click_hook=nil
ticks_until(5)
assert(spoken()=='Teclis is now selected. Campaign setup. Lord: Teclis, High Elves, Eataine, button, 1 of 6',spoken())
for _,expected in ipairs({'Campaign difficulty, combo box, Normal, 2 of 6','Battle difficulty, combo box, Normal, 3 of 6'}) do
    key('script_F2'); assert(spoken()==expected,spoken())
end
key('script_F2'); assert(says('Enable campaign introduction, check box') and says('4 of 6'),spoken())
key('script_F2'); assert(spoken()=='Lord and faction details, button, 5 of 6',spoken())
key('script_F2'); assert(spoken()=='Start Campaign, button, 6 of 6',spoken())
-- Details: everything else on the screen, without the choices; Back returns.
key('script_F3'); key('script_F4'); assert(says('Lord and faction details. ') and says(', 1 of '),spoken())
local details=0
for _=1,60 do
    key('script_F2'); details=details+1
    assert(not says('radio button') and not says('Start Campaign') and not says('combo box'),'Details hold no choices: '..spoken())
    if says('Back, button') then break end
end
assert(details>10,'Details read the rest of the screen')
key('script_F4'); assert(spoken()=='Campaign setup. Lord and faction details, button, 5 of 6',spoken())
-- Backspace from the setup returns to the chosen lord's race.
back_key(); assert(spoken()=='High Elves. Teclis, radio button, checked, 2 of 4',spoken())
key('script_F4'); assert(spoken()=='Teclis is already selected. Campaign setup. Lord: Teclis, High Elves, Eataine, button, 1 of 6',spoken())
assert(#dispatches==1,'An already chosen lord is not clicked again')
-- Start Campaign from the setup still asks first.
key('script_F3'); key('script_F4'); assert(spoken()=='Start the campaign as Teclis, High Elves, Eataine? Press Enter again to start.',spoken())
key('script_F4'); assert(#dispatches==2 and dispatches[2]=='tree.child2.child1.child0',spoken())
-- The summary goes back to the race choice.
steps_start(); key('script_F2'); key('script_F4'); key('script_F4')
assert(spoken()=='Tyrion is already selected. Campaign setup. Lord: Tyrion, High Elves, Eataine, button, 1 of 6',spoken())
key('script_F4'); assert(spoken()=='Choose a race. High Elves, 3 lords, 1 of 6',spoken())
-- Difficulty: Enter opens the game's list, the options are read, Enter chooses one.
local function with_popup(layout)
    local copy={}
    for prefix,row in pairs(layout) do local c={}; for k,v in pairs(row) do c[k]=v end; copy[prefix]=c end
    copy[dropdown .. '.child1']={Id='popup_menu',Visible=false,ChildCount=1,GetStateText='',GetTooltipText='',CurrentState='NewState',IsInteractive=true}
    copy[dropdown .. '.child1.child0']={Id='popup_list',Visible=true,ChildCount=5,GetStateText='',GetTooltipText='',CurrentState='NewState',IsInteractive=true}
    for i,label in ipairs({'Easy','Normal','Hard','Very Hard','Legendary'}) do
        copy[dropdown .. '.child1.child0.child' .. (i-1)]={Id='option' .. (i-1),Visible=true,ChildCount=0,GetStateText=label,
            GetTooltipText='',CurrentState='active',IsInteractive=true}
    end
    return copy
end
local popup_lord=with_popup(lord_live)
steps_start(popup_lord); key('script_F2'); key('script_F4'); key('script_F4')
key('script_F2'); assert(spoken()=='Campaign difficulty, combo box, Normal, 2 of 6',spoken())
click_hook=function() nodes[dropdown .. '.child1'].data.Visible=true end
key('script_F4'); assert(#dispatches==1 and dispatches[1]==dropdown,'Enter opens the difficulty list'); click_hook=nil
ticks_until(5); assert(spoken()=='Campaign difficulty, list. Normal, selected, 2 of 6',spoken())
key('script_F2'); assert(spoken()=='Hard, 3 of 6',spoken())
click_hook=function()
    nodes[dropdown .. '.child1'].data.Visible=false
    nodes[dropdown .. '.child0'].data.GetStateText='Hard'
end
key('script_F4'); assert(#dispatches==2 and dispatches[2]==dropdown .. '.child1.child0.child2','Enter chooses the option'); click_hook=nil
ticks_until(5); assert(spoken()=='Campaign difficulty, combo box, Hard, 2 of 6',spoken())
-- Backspace in the open list closes it in the game (the combo box again).
click_hook=function() nodes[dropdown .. '.child1'].data.Visible=true end
key('script_F4'); click_hook=nil; ticks_until(5); assert(says('Campaign difficulty, list.'),spoken())
click_hook=function() nodes[dropdown .. '.child1'].data.Visible=false end
back_key(); assert(#dispatches==4 and dispatches[4]==dropdown,'Backspace closes the list'); click_hook=nil
ticks_until(5); assert(spoken()=='Campaign difficulty, combo box, Hard, 2 of 6',spoken())
-- An option that changes before the press is not clicked.
steps_start(popup_lord); key('script_F2'); key('script_F4'); key('script_F4'); key('script_F2')
click_hook=function() nodes[dropdown .. '.child1'].data.Visible=true end
key('script_F4'); click_hook=nil; ticks_until(5); key('script_F2')
nodes[dropdown .. '.child1.child0.child2'].data.Id='other'
key('script_F4'); assert(#dispatches==1 and says('The screen changed. Press F2 and try again.'),spoken())
-- A key before the delayed read: the key reads the screen and the timer stays quiet.
steps_start(); key('script_F2'); key('script_F4'); key('script_F2')
click_hook=function()
    nodes[tyrion].data.CurrentState='active'; nodes[teclis].data.CurrentState='selected'
    nodes['tree.child2.child0.child2.child0.child4'].data.GetStateText='Teclis'
end
key('script_F4'); click_hook=nil; key('script_F2')
assert(says('Teclis is now selected. Campaign setup. Lord: Teclis'),spoken())
local heard=spoken(); ticks_until(8); assert(spoken()==heard,'No second reading from the timer')
-- A race without a known lord is "Other lords".
local unknown_race={}
for prefix,row in pairs(lord_live) do local c={}; for k,v in pairs(row) do c[k]=v end; unknown_race[prefix]=c end
for _,index in ipairs({15,16,17}) do unknown_race['tree.child2.child0.child1.child0.child1.child0.child0.child' .. index].Id='New lord ' .. index end
steps_start(unknown_race); key('script_F2'); key('script_F2'); key('script_F2'); assert(spoken()=='Other lords, 3 lords, 3 of 6',spoken())
-- lord-list-flat.flag keeps the single list.
flat_lords=true; steps_start(); key('script_F2'); assert(spoken()=='Select Lord. Select Lord, heading, 1 of 49',spoken()); flat_lords=false
-- Intro movies: announced when the script loads at game start, not on a later reload.
local real_clock=os.clock
os.clock=function() return 25 end; start(); os.clock=real_clock
assert(contents('bridge.jsonl'):find('Intro movies playing. Press Escape to skip them.',1,true),'Movies announced at start')
os.clock=function() return 600 end; start(); os.clock=real_clock
assert(not contents('bridge.jsonl'):find('Intro movies playing',1,true),'No movie notice after a campaign')
-- One repeating key timer, registered once and never from its callback
-- (0.6.64: re-registering inside the callback silenced the reader live).
repeating_timer=true
steps_start(popup_lord)
assert(timer_registrations==1,'Registered once at start')
key('script_F2'); key('script_F4'); key('script_F4'); key('script_F2')
click_hook=function() nodes[dropdown .. '.child1'].data.Visible=true end
key('script_F4'); click_hook=nil
ticks_until(6); assert(spoken()=='Campaign difficulty, list. Normal, selected, 2 of 6',spoken())
send_keys('companion-steps',{'next'}); assert(spoken()=='Hard, 3 of 6',spoken())
assert(timer_registrations==1,'Never registered again from the callback')
assert(contents('native-ui-graphics-preview.log'):find('keys.enabled	string	companion key channel, repeating timer',1,true))
repeating_timer=false
single_press, flat_lords = false, true
io=real_io; os.time=real_time; os.date=real_date
print('PASS: '..scenarios..' frontend scenarios; 86-node/22-control capture, cached wraparound, four allowlisted frontend targets and observed-result checks, confirmations, stale identities, native failures, template/panel changes, lifecycle, clocks and blocked game contexts')
