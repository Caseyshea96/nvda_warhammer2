-- Read-only frontend diagnostic. Never activates UI or sends game shortcuts.
-- Do not overwrite frontend evidence when campaign/battle creates a Lua context.
if core:is_campaign() or core:is_battle() then return end
local sequence, runs = 0, 0
local controls, control_index = {}, 0
local control_ids = {
    button_new_campaign = true,
    button_start_campaign = true,
    button_load_campaign = true,
    button_multiplayer_campaign = true,
    button_movie_player = true,
    button_quest_battle = true,
    button_practice_battle = true,
    button_multiplayer_battle = true,
    button_quick_battle = true,
    button_leaderboards = true,
    button_replays = true,
    button_lab_battle = true,
    button_graphics = true,
    button_audio = true,
    [' button_audio'] = true,
    button_controls = true,
    button_ui = true,
    button_gamma = true,
    button_credits = true,
    button_support = true,
    button_tw_academy = true,
    button_tw_blog = true,
    button_quit = true
}
local session = 'diagnostic:' .. tostring({}) .. ':' .. tostring(os.clock())
local log_path, bridge_path
local log_failed = false
local function quote(v)
    return '"' .. tostring(v):gsub('[%z\1-\31\\"]', function(c)
        return string.format('\\u%04x', string.byte(c))
    end) .. '"'
end
local function append(path, line)
    local f = io.open(path, 'a')
    if not f then if path == log_path then log_failed = true end; return end
    local written = f:write(line .. '\n'); local closed = f:close()
    if path == log_path and (not written or closed == nil) then log_failed = true end
end
local function log(stage, value)
    if log_path then append(log_path, stage .. '\t' .. type(value) .. '\t' .. tostring(value):sub(1,1000):gsub('[\r\n]', ' ')) end
end
local function speak(text)
    sequence = sequence + 1
    if bridge_path then append(bridge_path, '{"version":1,"session":' .. quote(session)
        .. ',"sequence":' .. sequence .. ',"context":"frontend","generation":0,"kind":"speech","text":' .. quote(text) .. '}') end
end
local bases = {}
if os.getenv and os.getenv('LOCALAPPDATA') then bases[1] = os.getenv('LOCALAPPDATA') .. '/WarhammerAccess/' end
bases[#bases + 1] = ''
for _, base in ipairs(bases) do
    local path = base .. 'native-ui-diagnostic.log'
    local f = io.open(path, 'w')
    if f then
        f:write('WH2 native UI diagnostic 0.4.3-nvda-diagnostic\n'); f:close()
        log_path = path; bridge_path = base .. (base == '' and 'warhammer_access.jsonl' or 'bridge.jsonl')
        local bridge = io.open(bridge_path, 'w'); if bridge then bridge:close() end
        break
    end
end
local function observe(name, fn)
    log(name .. '.START', true)
    local value
    local ok, err = pcall(function() value = fn() end)
    if ok then log(name .. '.RESULT', value) else log(name .. '.ERROR', err) end
    return ok, value
end
local function id_adapter(node) local v = node:Id(); return v end
local function count_adapter(node) local v = node:ChildCount(); return v end
local function id_tail(node) return node:Id() end
local function count_tail(node) return node:ChildCount() end
local function sample(label, node, children)
    log(label .. '.object', node)
    observe(label .. '.Id.inline', function() local v = node:Id(); return v end)
    observe(label .. '.Id.adapter', function() local v = id_adapter(node); return v end)
    observe(label .. '.Id.tail', function() local v = id_tail(node); return v end)
    local ok, count = observe(label .. '.ChildCount.inline', function() local v = node:ChildCount(); return v end)
    observe(label .. '.ChildCount.adapter', function() local v = count_adapter(node); return v end)
    observe(label .. '.ChildCount.tail', function() local v = count_tail(node); return v end)
    observe(label .. '.ChildCount.nested', function()
        local value
        local success, err = pcall(function() value = node:ChildCount() end)
        if not success then error(err) end
        return value
    end)
    observe(label .. '.Visible', function() local v = node:Visible(true); return v end)
    observe(label .. '.IsInteractive', function() local v = node:IsInteractive(); return v end)
    observe(label .. '.GetStateText', function() local v = node:GetStateText(); return v end)
    observe(label .. '.CurrentState', function() local v = node:CurrentState(); return v end)
    observe(label .. '.Address', function() local v = node:Address(); return v end)
    if children and ok and type(count) == 'number' and count == count and count >= 0 and count % 1 == 0 then
        local limit = count
        if limit > 8 then limit = 8 end
        for i = 0, limit - 1 do
            local prefix = label .. '.child' .. i
            local found, address = observe(prefix .. '.Find', function() local v = node:Find(i); return v end)
            if found and address then
                local converted, child = observe(prefix .. '.Convert', function() local v = UIComponent(address); return v end)
                if converted and child then sample(prefix, child, false) end
            end
        end
    else log(label .. '.children.skipped', 'not requested or invalid count') end
end
local function clean(value)
    if type(value) ~= 'string' then return '' end
    return value:gsub('%[%[.-%]%]', ' '):gsub('<[^>]*>', ' ')
        :gsub('[%z\1-\31]', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
end
local function capture_tree(root)
    local visited = 0
    controls = {}
    local function descendant_label(node, depth)
        if depth <= 0 then return '' end
        local count_ok, count = pcall(function() return node:ChildCount() end)
        if not count_ok or type(count) ~= 'number' or count < 0 or count % 1 ~= 0 then return '' end
        if count > 12 then count = 12 end
        for i = 0, count - 1 do
            local ok, child = pcall(function() return UIComponent(node:Find(i)) end)
            if ok and child then
                local visible_ok, visible = pcall(function() return child:Visible(true) end)
                if visible_ok and visible == true then
                    local text_ok, text = pcall(function() return child:GetStateText() end)
                    text = text_ok and clean(text) or ''
                    if text ~= '' then return text end
                    local tip_ok, tip = pcall(function() return child:GetTooltipText() end)
                    tip = tip_ok and clean(tip) or ''
                    if tip ~= '' then return tip end
                    local nested = descendant_label(child, depth - 1)
                    if nested ~= '' then return nested end
                end
            end
        end
        return ''
    end
    local function walk(node, label, depth)
        if visited >= 200 or depth > 20 then log(label .. '.bounded', 'node or depth limit'); return end
        visited = visited + 1
        log(label .. '.object', node)
        local id_ok, id = observe(label .. '.Id', function() local v = node:Id(); return v end)
        local visible_ok, visible = observe(label .. '.Visible', function() local v = node:Visible(true); return v end)
        local interactive_ok, interactive = observe(label .. '.IsInteractive', function() local v = node:IsInteractive(); return v end)
        local text_ok, state_text = observe(label .. '.GetStateText', function() local v = node:GetStateText(); return v end)
        local tip_ok, tooltip = observe(label .. '.GetTooltipText', function() local v = node:GetTooltipText(); return v end)
        local state_ok, state = observe(label .. '.CurrentState', function() local v = node:CurrentState(); return v end)
        observe(label .. '.Address', function() local v = node:Address(); return v end)
        local count_ok, count = observe(label .. '.ChildCount', function() local v = node:ChildCount(); return v end)
        if not visible_ok or visible ~= true then log(label .. '.children.skipped', 'not visible'); return end
        if not count_ok or type(count) ~= 'number' or count ~= count or count < 0 or count % 1 ~= 0 then
            log(label .. '.children.skipped', 'invalid count'); return
        end
        local limit = count
        if limit > 100 then limit = 100 end
        for i = 0, limit - 1 do
            local child_label = label .. '.child' .. i
            local found, address = observe(child_label .. '.Find', function() local v = node:Find(i); return v end)
            if found and address then
                local converted, child = observe(child_label .. '.Convert', function() local v = UIComponent(address); return v end)
                if converted and child then walk(child, child_label, depth + 1) end
            end
        end
        log(label .. '.classify.START', true)
        local classified, classify_error = pcall(function()
            if id_ok and type(id) == 'string' and control_ids[id] == true
                and interactive_ok and interactive == true then
                local name = text_ok and clean(state_text) or ''
                if name == '' then name = tip_ok and clean(tooltip) or '' end
                if name == '' then name = descendant_label(node, 2) end
                if name == '' then name = id end
                controls[#controls + 1] = {name = name, state = state_ok and clean(state) or ''}
            end
        end)
        if classified then log(label .. '.classify.RESULT', true)
        else log(label .. '.classify.ERROR', classify_error) end
    end
    walk(root, 'tree', 0)
    log('tree.nodes', visited)
    log('tree.controls', #controls)
end
local function capture(source)
    if runs >= 1 then return end
    runs = runs + 1
    log('capture', runs); log('source', source)
    local completed, failure = pcall(function()
        local ok, ready = observe('core.is_ui_created', function() local v = core:is_ui_created(); return v end)
        if ok and ready == true then
            local got, node = observe('core.get_ui_root', function() local v = core:get_ui_root(); return v end)
            if got and node then sample('root', node, false); capture_tree(node) end
        else log('root.skipped', 'UI not ready') end
    end)
    if not completed then log('capture.ERROR', failure) end
    log('capture.COMPLETE', runs)
    if log_failed or not log_path then speak('Diagnostic file could not be saved. Check the game folder and AppData permissions.'); return end
end
local function announce_control(step)
    if #controls == 0 then speak('No menu controls found. Send native-ui-diagnostic.log. No game action was sent.'); return end
    if control_index == 0 then control_index = step > 0 and 1 or #controls
    else control_index = ((control_index - 1 + step) % #controls) + 1 end
    local item = controls[control_index]
    local state = item.state ~= '' and (', ' .. item.state) or ''
    speak('Controls, ' .. control_index .. ' of ' .. #controls .. ': ' .. item.name .. state .. '. Read only; no game action was sent.')
end
if not core:is_campaign() and not core:is_battle() then
    core:add_ui_created_callback(function() log('lifecycle.created', true) end)
    core:add_ui_destroyed_callback(function() log('lifecycle.destroyed', true) end)
    core:add_listener('warhammer_diagnostic_key', 'ShortcutTriggered',
        function(c) return c.string == 'script_F2' or c.string == 'script_F3' end,
        function(c)
            if runs == 0 then capture('shortcut') end
            if c.string == 'script_F2' then announce_control(1) else announce_control(-1) end
        end, true)
    speak('NVDA read-only keyboard browser 0.4.3 with quiet mode. In the main menu tap F2 for the next control or F3 for the previous control. No mouse, activation, or game command is used.')
else speak('This diagnostic only inspects the frontend. Return to the main menu.') end
