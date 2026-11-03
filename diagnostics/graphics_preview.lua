-- Campaign setup discovery preview, built around the proven diagnostic traversal.
-- Do not overwrite frontend evidence when campaign/battle creates a Lua context.
if core:is_campaign() or core:is_battle() then return end
local sequence, runs = 0, 0
local interaction_revision, activation_outcome, activation_origin = 0, 'blocked', 'keyboard'
local start_automation
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
local session = 'graphics-preview:' .. tostring({}) .. ':' .. tostring(os.clock())
local log_path, bridge_path
local log_failed, log_bytes = false, 0
local generation, captured, browse_snapshot, latest_snapshot = 0, false, nil, nil
local pending, scan_active, scan_valid = nil, false, false
local scan_nodes, scan_parts, scan_reads = {}, {}, {}
local snapshot_node_count = 0
local lord_discovery
local announce_prefix = ''
-- After toggling the intro check box the screen is read again; the reader
-- returns to the check box so Enter or an arrow continues from it.
local lord_resume_key, quiet_announce = nil, false
local last_screen -- screen whose title was last spoken
local nav_target -- 'first', 'last' or {letter=x} for the next announcement
local lord_awaiting -- lord name sent by the last selection, until observed
-- 0.6.64: Select Lord as a sequence of choices (trial run 3: one list of 50
-- items was hard to use). Steps: races -> lords -> setup; setup leads to
-- details and to a difficulty's options. Backspace goes back a step.
local lord_step, lord_step_race, lord_step_field = 'races', nil, nil
local lord_focus, lord_step_prefix = nil, '' -- position and words for the next read
local lord_reread_at, lord_reread_left = nil, 0 -- key-timer tick for a read after a click
local function lord_steps_reset()
    lord_step, lord_step_race, lord_step_field, lord_focus, lord_step_prefix = 'races', nil, nil, nil, ''
    lord_reread_at, lord_reread_left = nil, 0
end
local screen_kind, awaiting_result = 'unknown', nil
local function cancel() pending = nil end
local function invalidate()
    interaction_revision = interaction_revision + 1
    cancel(); controls, control_index = {}, 0
    lord_discovery=nil; announce_prefix=''
    captured, browse_snapshot = false, nil
    screen_kind = 'unknown'
end
local verified_layout = {
    ["tree"] = {["ChildCount"] = "number:5", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:root", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child0"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:layout", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:movie", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:watermark_square", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2"] = {["ChildCount"] = "number:4", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:main", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:v1.12.1  Build 20428.3256712 (modded)", ["GetTooltipText"] = "string:", ["Id"] = "string:version_number", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:banner_clip", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:fe_banner", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0"] = {["ChildCount"] = "number:4", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:menu", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child0"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:min", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:campaigns_frame", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child0.child0"] = {["ChildCount"] = "number:6", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:holder", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child0.child0.child0"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_header_campaigns", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child0.child0.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:Campaigns", ["GetTooltipText"] = "string:", ["Id"] = "string:title", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child0.child0.child0.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:icon_new_content_alert", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child1.child0.child0.child0.child0.child1"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_new_campaign", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child0.child0.child1.child0"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:New Campaign", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child0.child0.child1.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:icon_new_campaign_alert", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child1.child0.child0.child0.child0.child2"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:inactive", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_start_campaign", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child0.child0.child2.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:inactive", ["GetStateText"] = "string:Continue Campaign", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child0.child0.child3"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:inactive", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_load_campaign", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child0.child0.child3.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:inactive", ["GetStateText"] = "string:Load Campaign", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child0.child0.child4"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_multiplayer_campaign", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child0.child0.child4.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Multiplayer Campaign", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child0.child0.child5"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_movie_player", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child0.child0.child5.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Movie Viewer", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:min", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:battles_frame", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0"] = {["ChildCount"] = "number:8", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:holder", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child0"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_header_battles", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:Battles", ["GetTooltipText"] = "string:", ["Id"] = "string:title", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child0.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:icon_new_content_alert", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child1"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_quest_battle", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child1.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Quest Battle", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child2"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_practice_battle", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child2.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Custom Battle", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child3"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_multiplayer_battle", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child3.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Multiplayer Battle", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child4"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_quick_battle", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child4.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Quick Battle", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child5"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_leaderboards", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child5.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Leaderboards", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child6"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:inactive", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_replays", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child6.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:inactive", ["GetStateText"] = "string:Replays", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child7"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_lab_battle", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child7.child0"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:The Laboratory", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child7.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:icon_new_content_alert", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child1.child0.child7.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:icon_new_content_alert", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child1.child0.child0.child2"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:min", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:options_frame", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0"] = {["ChildCount"] = "number:8", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:holder", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child0"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_header_options", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:Options", ["GetTooltipText"] = "string:", ["Id"] = "string:title", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child1"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_graphics", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child1.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Graphics", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child2"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string: button_audio", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child2.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Sound", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child3"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_controls", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child3.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Controls", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child4"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_ui", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child4.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Game Settings", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child5"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_gamma", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child5.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Brightness and Gamma", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child6"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_credits", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child6.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Credits", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child7"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_support", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child2.child0.child7.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Support", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child3"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:min", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:dlc_frame", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child3.child0"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_header_dlc", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child3.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Downloadable Content", ["GetTooltipText"] = "string:", ["Id"] = "string:title", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0.child3.child0.child1"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:default", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:content_menu", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child1.child0.child1"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:dlc_button_parent", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child1.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Previous theme", ["Id"] = "string:button_prev_theme", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child1.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Next theme", ["Id"] = "string:button_next_theme", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child1.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:The Silence & The Fury", ["GetTooltipText"] = "string:", ["Id"] = "string:dlc_label", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:false"},
    ["tree.child2.child2"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:logo_holder", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child2.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:logo", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child2.child1"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:mask", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child2.child1.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:wipe", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child3"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:inagame_messaging", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child3"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:sp_frame", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child3.child0"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:menu_bar", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child3.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Total War Academy", ["Id"] = "string:button_tw_academy", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child3.child0.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Patch Notes", ["Id"] = "string:button_tw_blog", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child3.child1"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:frame_BL", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child3.child1.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:inactive", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Return to main menu", ["Id"] = "string:button_home", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child3.child2"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:frame_BR", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child3.child2.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Quit", ["Id"] = "string:button_quit", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child4"] = {["ChildCount"] = "number:7", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:browser", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
}

-- Actual 0.6.1 Escape return: a hidden Tooltip occupies child4 and the
-- hidden browser moves to child5. Main-menu input paths remain at child2.
local verified_main_tooltip_layout = {}
for prefix, expected in pairs(verified_layout) do
    local key = prefix == 'tree.child4' and 'tree.child5' or prefix
    local row = {}
    for method, value in pairs(expected) do row[method] = value end
    if prefix == 'tree' then row.ChildCount = 'number:6' end
    verified_main_tooltip_layout[key] = row
end
verified_main_tooltip_layout['tree.child4'] = {
    Id='string:Tooltip', Visible='boolean:false', IsInteractive='boolean:false',
    ChildCount='number:2', CurrentState='string:NewState', GetTooltipText='string:'}
-- Its hidden caption is unrelated to the input targets and may name the
-- previously hovered control. Every actionable field/identity stays exact.
local verified_basic_layout = {
    ["tree"] = {["ChildCount"] = "number:5", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:root", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child0"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:layout", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:movie", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:watermark_square", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:options_graphics", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child0"] = {["ChildCount"] = "number:12", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:panel_advanced", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child1"] = {["ChildCount"] = "number:7", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:basic_options", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:checkbox_windowed", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:Run in window", ["GetTooltipText"] = "string:", ["Id"] = "string:label_txt", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child1"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:title_plaque", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child1.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:Graphics", ["GetTooltipText"] = "string:", ["Id"] = "string:title", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child2"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:ok_cancel_buttongroup", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child2.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Accept changes", ["Id"] = "string:button_ok", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child2.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Cancel changes", ["Id"] = "string:button_cancel", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child3"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_advanced_options", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child3.child0"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:smoke_clip_parent", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child3.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:wh2", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:smoke_overlay", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child3.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Advanced", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child4"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_recommended", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child4.child0"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:smoke_clip_parent", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child4.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:wh2", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:smoke_overlay", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child4.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Recommended", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child5"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:dropdown_resolution", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child5.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:1280x720", ["GetTooltipText"] = "string:", ["Id"] = "string:dy_selected_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child5.child1"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:popup_menu", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:false"},
    ["tree.child2.child1.child5.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:Resolution", ["GetTooltipText"] = "string:", ["Id"] = "string:label_txt", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child6"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:dropdown_quality", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child6.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:Low", ["GetTooltipText"] = "string:", ["Id"] = "string:dy_selected_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child6.child1"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:popup_menu", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:false"},
    ["tree.child2.child1.child6.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:Quality", ["GetTooltipText"] = "string:", ["Id"] = "string:label_txt", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child2"] = {["ChildCount"] = "number:6", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:resolution_popup", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:false"},
    ["tree.child3"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:sp_frame", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child3.child0"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:menu_bar", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child3.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Total War Academy", ["Id"] = "string:button_tw_academy", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child3.child0.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Patch Notes", ["Id"] = "string:button_tw_blog", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child3.child1"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:frame_BL", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child3.child1.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Return to main menu", ["Id"] = "string:button_home", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child3.child2"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:frame_BR", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child3.child2.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Quit", ["Id"] = "string:button_quit", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child4"] = {["ChildCount"] = "number:7", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:browser", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
}

-- Exact named-node fields from the observed Vortex selection. Empty smoke
-- particles are checked separately as noninteractive, text-free leaf nodes.
local verified_campaign_layout = {
    ["tree"] = {["ChildCount"] = "number:5", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:root", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child0"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:layout", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:movie", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:watermark_square", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:campaign_select", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child0"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:docker", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:details", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child0"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:movie_parent", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:movie_panel", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child0.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:movie_fader", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child0.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:movie_frame", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:text_panel", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child0"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:State", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:campaign_description", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child0.child0"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:MainState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:TextView", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child0.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:MainState", ["GetStateText"] = "string:At the heart of the Elven homeland the Great Vortex coils, syphoning the excess magic that spills from the Realm of Chaos; but now, after many millennia, it falters. The Vortex is vulnerable and while some seek to control its great power, others see an opportunity, a chance to prosper and vanquish foes in an unstable, war-ravaged world. Choose a Legendary Lord, fight for all that they desire and lead them to glory!", ["GetTooltipText"] = "string:", ["Id"] = "string:Text", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child0.child0.child1"] = {["ChildCount"] = "number:5", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:vslider", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child0.child1"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:header", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child0.child1.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:The Eye of the Vortex", ["GetTooltipText"] = "string:", ["Id"] = "string:label_campaign_name", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:State", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:playable_races", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child0"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:header", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:Playable Races", ["GetTooltipText"] = "string:", ["Id"] = "string:tx_header", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1"] = {["ChildCount"] = "number:12", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:faction_list", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child0"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:High Elves", ["Id"] = "string:wh2_main_hef_eataine", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:new_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child0.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:free_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child0.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:content_alert_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child1"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Lizardmen", ["Id"] = "string:wh2_main_lzd_hexoatl", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child1.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:new_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child1.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:free_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child1.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:content_alert_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child10"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Greenskins", ["Id"] = "string:wh2_dlc15_grn_broken_axe", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child10.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Expand your Total War: WARHAMMER II experience with: The Warden & The Paunch  Left-click to go to your client's store page.", ["Id"] = "string:new_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child10.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:free_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child10.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:content_alert_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child11"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Wood Elves", ["Id"] = "string:wh2_dlc16_wef_sisters_of_twilight", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child11.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Expand your Total War: WARHAMMER II experience with: The Twisted & The Twilight  Left-click to go to your client's store page.", ["Id"] = "string:new_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child11.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:free_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child11.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:content_alert_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child2"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Dark Elves", ["Id"] = "string:wh2_main_def_naggarond", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child2.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:new_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child2.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:free_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child2.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:content_alert_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child3"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Skaven", ["Id"] = "string:wh2_main_skv_clan_mors", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child3.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:new_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child3.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:free_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child3.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:content_alert_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child4"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Vampire Coast", ["Id"] = "string:wh2_dlc11_cst_vampire_coast", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child4.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:new_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child4.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:free_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child4.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:content_alert_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child5"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Tomb Kings", ["Id"] = "string:wh2_dlc09_tmb_khemri", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child5.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:new_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child5.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:free_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child5.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:content_alert_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child6"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:The Empire", ["Id"] = "string:wh2_dlc13_emp_the_huntmarshals_expedition", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child6.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Expand your Total War: WARHAMMER II experience with: The Hunter & The Beast  Left-click to go to your client's store page.", ["Id"] = "string:new_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child6.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:free_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child6.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:content_alert_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child7"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Bretonnia", ["Id"] = "string:wh2_dlc14_brt_chevaliers_de_lyonesse", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child7.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:new_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child7.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Expand your Total War: WARHAMMER II experience with: Repanse[[col:yellow]] (FREE CONTENT)[[/col]]  Left-click to go to your client's store page.", ["Id"] = "string:free_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child7.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:content_alert_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child8"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Beastmen Warherds", ["Id"] = "string:wh2_dlc17_bst_taurox", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child8.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Expand your Total War: WARHAMMER II experience with: The Silence & The Fury  Left-click to go to your client's store page.", ["Id"] = "string:new_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child8.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:free_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child8.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:content_alert_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child9"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Dwarfs", ["Id"] = "string:wh2_dlc17_dwf_thorek_ironbrow", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child9.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:new_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child1.child9.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Expand your Total War: WARHAMMER II experience with: Thorek Ironbrow[[col:yellow]] (FREE CONTENT)[[/col]]  Left-click to go to your client's store page.", ["Id"] = "string:free_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child0.child1.child1.child1.child9.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:New content available", ["Id"] = "string:content_alert_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child0.child1.child1.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:overlay", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child1"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:list_parent", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child1.child0"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:hover", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:wh2_main_great_vortex", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child1.child0.child0"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:selected_FX", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child1.child0.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:glow", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child1.child0.child0.child1"] = {["ChildCount"] = "number:61", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:smoke_particle_emitter", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child1.child0.child0.child1.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:template_particle", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child1.child0.child1"] = {["ChildCount"] = "number:4", ["CurrentState"] = "string:selected", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_campaign_entry", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child1.child0.child1.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:The Eye of the Vortex", ["GetTooltipText"] = "string:", ["Id"] = "string:label_name", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child1.child0.child1.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Additional content available!", ["Id"] = "string:content_alert_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child1.child0.child1.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:new_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child1.child0.child1.child3"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:free_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child1.child1"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:hover", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:main_warhammer", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child1.child1.child0"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:selected_FX", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child1.child1.child1"] = {["ChildCount"] = "number:4", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_campaign_entry", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child1.child1.child1.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:Mortal Empires", ["GetTooltipText"] = "string:", ["Id"] = "string:label_name", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child1.child1.child1.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Additional content available!", ["Id"] = "string:content_alert_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child0.child1.child1.child1.child2"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:new_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child0.child1.child1.child1.child3"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:free_content_icon", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child1"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:title_plaque", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child1.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:Select Campaign", ["GetTooltipText"] = "string:", ["Id"] = "string:tx_header", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child2"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_frame", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child2.child0"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_next", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child2.child2.child0.child0"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:smoke_clip_parent", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child2.child0.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:wh2", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:smoke_overlay", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child2.child0.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:Continue", ["GetTooltipText"] = "string:", ["Id"] = "string:button_txt", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child2.child2.child1"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_purchase", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child2.child2.child2"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:button_download_free", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
    ["tree.child3"] = {["ChildCount"] = "number:3", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:sp_frame", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child3.child0"] = {["ChildCount"] = "number:2", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:menu_bar", ["IsInteractive"] = "boolean:false", ["Visible"] = "boolean:true"},
    ["tree.child3.child0.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Total War Academy", ["Id"] = "string:button_tw_academy", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child3.child0.child1"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Patch Notes", ["Id"] = "string:button_tw_blog", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child3.child1"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:frame_BL", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child3.child1.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Return to main menu", ["Id"] = "string:button_home", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child3.child2"] = {["ChildCount"] = "number:1", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:frame_BR", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child3.child2.child0"] = {["ChildCount"] = "number:0", ["CurrentState"] = "string:active", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:Quit", ["Id"] = "string:button_quit", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:true"},
    ["tree.child4"] = {["ChildCount"] = "number:7", ["CurrentState"] = "string:NewState", ["GetStateText"] = "string:", ["GetTooltipText"] = "string:", ["Id"] = "string:browser", ["IsInteractive"] = "boolean:true", ["Visible"] = "boolean:false"},
}

local function quote(v)
    return '"' .. tostring(v):gsub('[%z\1-\31\\"]', function(c)
        return string.format('\\u%04x', string.byte(c))
    end) .. '"'
end
local function append(path, line)
    local mode = 'a'
    if path == log_path then
        log_bytes = log_bytes + #line + 2 -- conservatively include Windows CRLF
        if log_bytes > 2097152 then
            -- 0.6.64: start the log again at its cap (as the campaign reader
            -- does) instead of treating a full log as unavailable: a long
            -- session (live: repeated re-reads) refused every activation.
            local header = 'WH2 native UI diagnostic (restarted at 2 MiB)\n'
            line = header .. 'log.restarted\tstring\tcap\n' .. line
            log_bytes, mode = #line + 2, 'w'
        end
    end
    local f = io.open(path, mode)
    if not f then if path == log_path then log_failed = true end; return end
    local written = f:write(line .. '\n'); local closed = f:close()
    if path == log_path and (not written or closed == nil) then log_failed = true end
end
-- Keep the proven logger free of scanner/selection bookkeeping. An error in
-- a capture hook must not also break the diagnostic error-reporting path.
local function log(stage, value)
    if log_path then append(log_path, stage .. '\t' .. type(value) .. '\t' .. tostring(value):sub(1,1000):gsub('[\r\n]', ' ')) end
end
local function speak(text)
    sequence = sequence + 1
    if bridge_path then append(bridge_path, '{"version":1,"session":' .. quote(session)
        .. ',"sequence":' .. sequence .. ',"context":"frontend","generation":' .. generation .. ',"kind":"speech","text":' .. quote(text) .. '}') end
end
local bases = {}
if os.getenv and os.getenv('LOCALAPPDATA') then bases[1] = os.getenv('LOCALAPPDATA') .. '/WarhammerAccess/' end
bases[#bases + 1] = ''
for _, base in ipairs(bases) do
    local path = base .. 'native-ui-graphics-preview.log'
    local f = io.open(path, 'w')
    if f then
        local header = 'WH2 native UI diagnostic 0.6.73-nvda-automation-preview\n'
        f:write(header); f:close(); log_bytes = #header + 1
        log_path = path; bridge_path = base .. (base == '' and 'warhammer_access.jsonl' or 'bridge.jsonl')
        local bridge = io.open(bridge_path, 'w'); if bridge then bridge:close() end
        break
    end
end
log('runtime.string_match', type(string.match))
log('runtime.string_find', type(string.find))
-- Every failed 0.6.15-0.6.17 candidate called s:find(p,1,true) on captured
-- text; 0.6.14 never calls string.find. After the first such call in-game,
-- the next s:sub() returned a non-string. Use string.sub prefix checks only.
local function starts_with(s, prefix)
    return type(s) == 'string' and string.sub(s, 1, #prefix) == prefix
end
-- Fallback that formats nothing, for logging after a failed string call.
local function plain_log(stage, text)
    if log_path then append(log_path, stage .. '\tstring\t' .. (type(text) == 'string' and text or ('non-string ' .. type(text)))) end
end
-- Activation is a single press, as in any program. A confirm-activations.flag
-- beside the log restores press-twice confirmation for every action.
local confirm_activations = false
if log_path then
    local flag = io.open(string.sub(log_path, 1, #log_path - #'native-ui-graphics-preview.log') .. 'confirm-activations.flag', 'r')
    if flag then flag:close(); confirm_activations = true end
end
-- 0.6.64: Select Lord is read as steps (race, lord, setup). A
-- lord-list-flat.flag beside the log restores the single list of 0.6.63.
local lord_flat = false
if log_path then
    local flag = io.open(string.sub(log_path, 1, #log_path - #'native-ui-graphics-preview.log') .. 'lord-list-flat.flag', 'r')
    if flag then flag:close(); lord_flat = true end
end
-- Opt-in confirmation probe, off unless string-find-probe.flag sits beside
-- the log. It may break later string calls, so run it in a separate launch.
if log_path then
    local flag = io.open(string.sub(log_path, 1, #log_path - #'native-ui-graphics-preview.log') .. 'string-find-probe.flag', 'r')
    if flag then
        flag:close()
        local ok, found = pcall(string.find, 'lord:tree.a.b', 'lord:tree.', 1, true)
        plain_log('probe.find', (ok and 'ok ' or 'error ') .. type(found) .. ' ' .. (type(found) == 'number' and (found .. '') or ''))
        local sok, piece = pcall(string.sub, 'abc', 1, 1)
        plain_log('probe.sub_function', (sok and 'ok ' or 'error ') .. type(piece))
        local mok, method = pcall(function() return ('abc'):sub(1, 1) end)
        plain_log('probe.sub_method', (mok and 'ok ' or 'error ') .. type(method))
        local tok, text = pcall(function() return tostring('abc') end)
        plain_log('probe.tostring', (tok and 'ok ' or 'error ') .. type(text))
    end
end
local function observe(name, fn)
    log(name .. '.START', true)
    local value
    local ok, err = pcall(function() value = fn() end)
    -- Store a flat observation; interpret it only after native traversal ends.
    if scan_active then scan_reads[name] = {ok = ok, value = value} end
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
local graphics_panel = 'tree.child2'
local basic_panel = graphics_panel .. '.child1'
local function captured_value(prefix, method)
    local read = scan_reads[prefix .. '.' .. method]
    if read and read.ok then return read.value end
    return nil
end
local function visible_id(prefix, id)
    return captured_value(prefix, 'Id') == id and captured_value(prefix, 'Visible') == true
end
local function captured_text(prefix, id)
    if not visible_id(prefix, id) then return '' end
    return clean(captured_value(prefix, 'GetStateText'))
end
-- Select Campaign: the shell around the campaign list (0.6.60: tolerant of
-- other PCs; activation checks the Continue button itself).
local campaign_entries = 'tree.child2.child0.child1'
local campaign_continue_key = 'tree.child2.child2.child0'
-- 0.6.60: other PCs add root children (news browser, tooltips); only a
-- visible or unreadable extra panel (a dialog on top) blocks.
local function no_extra_panel()
    local count = captured_value('tree', 'ChildCount')
    if type(count) ~= 'number' or count < 5 then return false end
    for index = 5, count - 1 do
        local prefix = 'tree.child' .. index
        local id, visible = captured_value(prefix, 'Id'), captured_value(prefix, 'Visible')
        if type(id) ~= 'string' or type(visible) ~= 'boolean' then return false end
        if visible and id ~= 'Tooltip' and id ~= 'browser' then return false end
    end
    return true
end
local function campaign_shell_supported() return no_extra_panel() end
local function scope_campaign_controls()
    controls = {}
    screen_kind = 'campaign_overlay'
    if not campaign_shell_supported() then return end
    screen_kind = 'campaign_selection'
    for i, id in ipairs({'wh2_main_great_vortex','main_warhammer'}) do
        local prefix = campaign_entries .. '.child' .. (i-1)
        local button = prefix .. '.child1'
        if visible_id(prefix,id) and visible_id(button,'button_campaign_entry') then
            local name = captured_text(button .. '.child0','label_name')
            local state = captured_value(button,'CurrentState')
            if name ~= '' then controls[#controls+1] = {key=button, name=name .. ', campaign choice',
                state=type(state)=='string' and state or 'state unavailable', read_only=true,
                label=name, role='radio button', engine_state=state} end
        end
    end
    if visible_id(campaign_continue_key,'button_next') then
        local name = captured_text(campaign_continue_key .. '.child1','button_txt')
        local state = captured_value(campaign_continue_key,'CurrentState')
        if name ~= '' then controls[#controls+1] = {key=campaign_continue_key, name=name .. ', button',
            state=type(state)=='string' and state or 'state unavailable', read_only=false,
            label=name, role='button', engine_state=state} end
    end
    local description = 'tree.child2.child0.child0.child1.child0.child0.child0'
    local text = captured_text(description,'Text')
    if text ~= '' then controls[#controls+1] = {key=description,name='Campaign description: ' .. text,state='',read_only=true} end
    local races = 'tree.child2.child0.child0.child1.child1.child1'
    local ids = {'wh2_main_hef_eataine','wh2_main_lzd_hexoatl','wh2_main_def_naggarond','wh2_main_skv_clan_mors',
        'wh2_dlc11_cst_vampire_coast','wh2_dlc09_tmb_khemri','wh2_dlc13_emp_the_huntmarshals_expedition',
        'wh2_dlc14_brt_chevaliers_de_lyonesse','wh2_dlc17_bst_taurox','wh2_dlc17_dwf_thorek_ironbrow',
        'wh2_dlc15_grn_broken_axe','wh2_dlc16_wef_sisters_of_twilight'}
    for i,id in ipairs(ids) do
        local prefix = races .. '.child' .. (i-1)
        if visible_id(prefix,id) then
            local name = clean(captured_value(prefix,'GetTooltipText'))
            if name ~= '' then controls[#controls+1] = {key=prefix,name='Listed race: ' .. name,state='',read_only=true} end
        end
    end
    if visible_id('tree.child3.child1.child0','button_home') then
        local name = clean(captured_value('tree.child3.child1.child0','GetTooltipText'))
        if name ~= '' then controls[#controls+1] = {key='tree.child3.child1.child0',name=name .. ', use Escape',state='',read_only=true,
            label=name, role='button'} end
    end
end
local advanced_panel = graphics_panel .. '.child0'
local function scope_advanced_controls()
    screen_kind = 'graphics_advanced'
    local specs = {
        {path = '.child0', id = 'button_benchmarks', label_path = '.child2', label_id = 'button_txt', role = 'button'},
        {path = '.child1.child0', id = 'checkbox_unlimited_memory', label_path = '.child0', label_id = 'label_txt', role = 'checkbox'},
        {path = '.child1.child1', id = 'checkbox_v_sync', label_path = '.child0', label_id = 'label_txt', role = 'checkbox'},
        {path = '.child1.child2', id = 'checkbox_vignette', label_path = '.child0', label_id = 'label_txt', role = 'checkbox'},
        {path = '.child1.child3', id = 'checkbox_proximity_fade', label_path = '.child0', label_id = 'label_txt', role = 'checkbox'},
        {path = '.child1.child5', id = 'checkbox_battery_meter', label_path = '.child0', label_id = 'label_txt', role = 'checkbox'},
        {path = '.child1.child6', id = 'checkbox_ssao', label_path = '.child0', label_id = 'label_txt', role = 'checkbox'},
        {path = '.child1.child7', id = 'checkbox_sharpen', label_path = '.child0', label_id = 'label_txt', role = 'checkbox'},
        {path = '.child2.child0', id = 'dropdown_directx', role = 'dropdown'},
        {path = '.child2.child1', id = 'dropdown_aliasing', role = 'dropdown'},
        {path = '.child2.child2', id = 'dropdown_texture_quality', role = 'dropdown'},
        {path = '.child2.child3', id = 'dropdown_filtering', role = 'dropdown'},
        {path = '.child2.child4', id = 'dropdown_shadows', role = 'dropdown'},
        {path = '.child2.child5', id = 'dropdown_water', role = 'dropdown'},
        {path = '.child2.child7', id = 'dropdown_particle_effects', role = 'dropdown'},
        {path = '.child2.child8', id = 'dropdown_grass', role = 'dropdown'},
        {path = '.child2.child9', id = 'dropdown_trees', role = 'dropdown'},
        {path = '.child2.child10', id = 'dropdown_terrain', role = 'dropdown'},
        {path = '.child2.child11', id = 'dropdown_unit_detail', role = 'dropdown'},
        {path = '.child2.child12', id = 'dropdown_building_detail', role = 'dropdown'},
        {path = '.child2.child13', id = 'dropdown_dop', role = 'dropdown'},
        {path = '.child2.child14', id = 'dropdown_unit_size', role = 'dropdown'},
        {path = '.child2.child15', id = 'dropdown_reflections', role = 'dropdown'},
        {path = '.child2.child16', id = 'dropdown_porthole', role = 'dropdown'},
        {path = '.child2.child18', id = 'dropdown_fog', role = 'dropdown'},
        {path = '.child2.child20', id = 'dropdown_hide_bodies', role = 'dropdown'},
        {path = '.child3', id = 'graphics_card', label_path = '.child0', label_id = 'label_txt', value_path = '.child1', value_id = 'button_txt', role = 'information'},
        {path = '.child4', id = 'video_memory', label_path = '.child0', label_id = 'label_txt', value_path = '.child1', value_id = 'button_txt', role = 'information'},
        {path = '.child7.child0', id = 'button_accept', role = 'button'},
        {path = '.child7.child1', id = 'button_close', role = 'button'},
        {path = '.child10', id = 'resolution_scale_parent', label_path = '.child1', label_id = 'label_tx', value_path = '.child2', value_id = 'label_resolution_scale', role = 'slider'},
        {path = '.child11', id = 'ui_scale', label_path = '.child1', label_id = 'label_tx', value_path = '.child2', value_id = 'scale_percentage_tx', role = 'slider'},
        {path = '.child11.child3', id = 'button_apply_ui_scale', label_path = '.child1', label_id = 'button_txt', role = 'button'}
    }
    -- If the entry capture observes an expanded dropdown, do not read the
    -- underlying Advanced controls as though the popup were closed.
    for _, spec in ipairs(specs) do
        if spec.role == 'dropdown' and captured_value(advanced_panel .. spec.path .. '.child1', 'Visible') == true then
            screen_kind = 'graphics_advanced_overlay'; return
        end
    end
    for _, spec in ipairs(specs) do
        local prefix = advanced_panel .. spec.path
        if visible_id(prefix, spec.id) then
            local name
            if spec.role == 'dropdown' then name = captured_text(prefix .. '.child2', 'label_txt')
            elseif spec.label_path then name = captured_text(prefix .. spec.label_path, spec.label_id)
            else name = clean(captured_value(prefix, 'GetTooltipText')) end
            if name ~= '' then
                local label, value = name, nil
                if spec.role == 'checkbox' then
                    -- Report native state separately; selected/active alone
                    -- has not established the checkbox's checked semantics.
                    name = name .. ', checkbox, checked state unavailable'
                elseif spec.role == 'dropdown' then
                    value = captured_text(prefix .. '.child0', 'dy_selected_txt')
                    name = name .. ', ' .. (value ~= '' and value or 'value unavailable') .. ', dropdown'
                elseif spec.role == 'slider' or spec.role == 'information' then
                    value = captured_text(prefix .. spec.value_path, spec.value_id)
                    name = name .. ', ' .. (value ~= '' and value or 'value unavailable') .. ', ' .. spec.role
                else name = name .. ', button' end
                local state = ''
                if spec.role ~= 'information' then
                    local state_prefix = spec.role == 'slider' and prefix .. '.child0' or prefix
                    state = captured_value(state_prefix, 'CurrentState')
                    if type(state) ~= 'string' then state = 'state unavailable' end
                    if captured_value(state_prefix, 'IsInteractive') ~= true then state = state .. ', unavailable' end
                end
                local engine = spec.role ~= 'information' and captured_value(spec.role == 'slider' and prefix .. '.child0' or prefix, 'CurrentState') or nil
                local interactive = spec.role == 'information' or captured_value(spec.role == 'slider' and prefix .. '.child0' or prefix, 'IsInteractive') == true
                controls[#controls + 1] = {key = prefix, name = name, state = state, read_only = true,
                    label = label, role = spec.role, value = value and (value ~= '' and value or 'value unavailable') or nil, engine_state = engine, interactive = interactive}
            else log('advanced.label_unavailable', prefix) end
        end
    end
end

local function scope_controls()
    -- Back on another menu: Select Lord starts again at the race.
    if visible_id(graphics_panel, 'campaign_select') then lord_steps_reset(); scope_campaign_controls(); return end
    if visible_id(graphics_panel, 'main') then
        lord_steps_reset()
        screen_kind = 'main'
        return
    end
    -- Unknown frontend panels must not expose unrelated main-menu/footer buttons.
    controls = {}
    if not visible_id(graphics_panel, 'options_graphics') then screen_kind = 'unknown'; return end
    screen_kind = 'graphics_overlay'
    if visible_id(graphics_panel .. '.child0', 'panel_advanced') then
        -- Discovery is read-only even when the bounded traversal cannot reach
        -- later sibling panels. This reports a visible panel, not modal focus.
        scope_advanced_controls(); return
    end
    if captured_value(graphics_panel .. '.child2', 'Visible') ~= false then return end
    if not visible_id(basic_panel, 'basic_options')
        or captured_value(graphics_panel .. '.child0', 'Visible') ~= false
        or captured_value(graphics_panel .. '.child2', 'Visible') ~= false
        or captured_value(basic_panel .. '.child5.child1', 'Visible') ~= false
        or captured_value(basic_panel .. '.child6.child1', 'Visible') ~= false then return end
    screen_kind = 'graphics'
    local specs = {
        {path = '.child0', id = 'checkbox_windowed', label_path = '.child0', label_id = 'label_txt', role = 'checkbox'},
        {path = '.child2.child0', id = 'button_ok', role = 'button'},
        {path = '.child2.child1', id = 'button_cancel', role = 'button'},
        {path = '.child3', id = 'button_advanced_options', label_path = '.child1', label_id = 'button_txt', role = 'button'},
        {path = '.child4', id = 'button_recommended', label_path = '.child1', label_id = 'button_txt', role = 'button'},
        {path = '.child5', id = 'dropdown_resolution', label_path = '.child2', label_id = 'label_txt', role = 'dropdown'},
        {path = '.child6', id = 'dropdown_quality', label_path = '.child2', label_id = 'label_txt', role = 'dropdown'}
    }
    for _, spec in ipairs(specs) do
        local prefix = basic_panel .. spec.path
        if visible_id(prefix, spec.id) then
            local name
            if spec.label_path then name = captured_text(prefix .. spec.label_path, spec.label_id)
            else name = clean(captured_value(prefix, 'GetTooltipText')) end
            if name ~= '' then
                local label, value = name, nil
                if spec.role == 'dropdown' then
                    value = captured_text(prefix .. '.child0', 'dy_selected_txt')
                    name = name .. ', ' .. (value ~= '' and value or 'value unavailable') .. ', dropdown'
                elseif spec.role == 'checkbox' then
                    -- active/inactive is not evidence of a checkbox's checked value.
                    name = name .. ', checkbox, checked state unavailable'
                else name = name .. ', button' end
                local state = captured_value(prefix, 'CurrentState')
                if type(state) ~= 'string' then state = 'state unavailable' end
                if captured_value(prefix, 'IsInteractive') ~= true then state = state .. ', unavailable' end
                controls[#controls + 1] = {key = prefix, name = name, state = state, read_only = spec.id ~= 'button_advanced_options',
                    label = label, role = spec.role, value = value and (value ~= '' and value or 'value unavailable') or nil,
                    engine_state = captured_value(prefix, 'CurrentState'), interactive = captured_value(prefix, 'IsInteractive') == true}
            else log('graphics.label_unavailable', prefix) end
        end
    end
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
                controls[#controls + 1] = {key = label, name = name, state = state_ok and clean(state) or ''}
            end
        end)
        if classified then log(label .. '.classify.RESULT', true)
        else scan_valid = false; log(label .. '.classify.ERROR', classify_error) end
    end
    walk(root, 'tree', 0)
    snapshot_node_count = visited
    log('tree.nodes', visited)
    log('tree.controls', #controls)
end
local function capture(source)
    log('capture.ENTER', source)
    runs = runs + 1
    log('capture.sequence', runs)
    scan_active, scan_valid = true, true
    log('capture.collecting', true)
    scan_nodes, scan_parts, scan_reads = {}, {}, {}
    snapshot_node_count = 0
    log('capture.buffers', true)
    local began_generation = generation
    log('capture', runs); log('source', source)
    local completed, failure = pcall(function()
        local ok, ready = observe('core.is_ui_created', function() local v = core:is_ui_created(); return v end)
        if not ok or ready ~= true then error('Game UI is not ready') end
        local got, node = observe('core.get_ui_root', function() local v = core:get_ui_root(); return v end)
        if not got or not node then error('Game UI root unavailable') end
        sample('root', node, false)
        capture_tree(node)
    end)
    scan_active = false
    -- Interpret the captured values outside both the native observer and logger.
    -- The template is deliberately fixed to the successful 86-node main menu.
    local layout, layout_name, expected_nodes = verified_layout, 'main', 86
    if visible_id(graphics_panel, 'main') and captured_value('tree','ChildCount') == 6
        and captured_value('tree.child4','Id') == 'Tooltip'
        and captured_value('tree.child5','Id') == 'browser' then
        layout, expected_nodes = verified_main_tooltip_layout, 87
    end
    if visible_id(graphics_panel, 'options_graphics') then
        layout, layout_name, expected_nodes = verified_basic_layout, 'graphics_basic', 40
    end
    if visible_id(graphics_panel, 'campaign_select') then
        layout, layout_name = verified_campaign_layout, 'campaign_selection'
        expected_nodes = captured_value('tree','ChildCount') == 6 and 168 or 167
        if not campaign_shell_supported() then scan_valid = false end
        -- Preserve the original logger while making multiline text observable.
        log('campaign.tooltip.escaped', quote(captured_value('tree.child2.child0.child0.child1.child1.child1.child10.child0','GetTooltipText')))
        log('campaign.description.escaped', quote(captured_value('tree.child2.child0.child0.child1.child0.child0.child0','GetStateText')))
    end
    if snapshot_node_count ~= expected_nodes then scan_valid = false end
    for _, read in pairs(scan_reads) do if not read.ok then scan_valid = false end end
    for prefix, expected in pairs(layout) do
        local node = {}
        scan_nodes[prefix] = node
        for method in pairs(expected) do
            local read = scan_reads[prefix .. '.' .. method]
            node[method] = read
            if not read or not read.ok then scan_valid = false end
            if read then
                scan_parts[#scan_parts + 1] = quote(prefix .. '.' .. method) .. ':' .. quote(type(read.value)) .. ':' .. quote(read.value)
            end
        end
        local address = scan_reads[prefix .. '.Address']
        node.Address = address
        if not address or not address.ok then scan_valid = false
        else
            local kind, value = type(address.value), address.value
            if not (kind == 'userdata' or (kind == 'string' and value ~= '')
                or (kind == 'number' and value == value and value > 0)) then scan_valid = false end
            scan_parts[#scan_parts + 1] = quote(prefix .. '.Address') .. ':' .. quote(kind) .. ':' .. quote(value)
        end
    end
    if not completed then log('capture.ERROR', failure); scan_valid = false; controls = {} end
    if generation ~= began_generation then scan_valid = false; controls = {} end
    latest_snapshot = {valid = scan_valid and completed and not log_failed,
        layout = layout_name, nodes = scan_nodes, fingerprint = table.concat(scan_parts, '\n'), generation = began_generation}
    captured = completed and generation == began_generation
    if captured then scope_controls() else screen_kind = 'unknown' end
    latest_snapshot.panel_visibility = {
        captured_value(graphics_panel .. '.child0', 'Visible'),
        captured_value(graphics_panel .. '.child1', 'Visible'),
        captured_value(graphics_panel .. '.child2', 'Visible')}
    if captured and awaiting_result then
        if awaiting_result == 'New Campaign' and screen_kind == 'campaign_selection' then
            log('activation.observed_result', 'New Campaign')
        elseif awaiting_result == 'Continue' and screen_kind == 'campaign_selection' then
            log('activation.result_not_observed', 'Continue:' .. screen_kind)
        elseif awaiting_result == 'New Campaign' or awaiting_result == 'Continue' then
            log('activation.result_requires_mapping', awaiting_result .. ':' .. screen_kind)
        elseif (awaiting_result == 'Graphics' and screen_kind == 'graphics')
            or (awaiting_result == 'Advanced' and screen_kind == 'graphics_advanced') then
            log('activation.observed_result', awaiting_result)
        else log('activation.result_not_observed', awaiting_result .. ':' .. screen_kind) end
        awaiting_result = nil
    end
    latest_snapshot.screen = screen_kind
    log('capture.screen', screen_kind)
    log('capture.scoped_controls', #controls)
    log('capture.activation_eligible', latest_snapshot.valid)
    log('capture.valid', latest_snapshot.valid)
    log('capture.COMPLETE', runs)
    return latest_snapshot
end
-- Presentation of already captured values only. No native calls, retained
-- components, selection changes or activation eligibility are introduced.
local lord_names={
    ['lord:tree.child2.child0.child2.child0.child4:text']={id='dy_faction_leader',label='Selected lord'},
    ['lord:tree.child2.child0.child2.child1.child4.child0:text']={id='dy_race',label='Race'},
    ['lord:tree.child2.child0.child2.child2.child1.child3:text']={id='label_faction_name',label='Faction'},
    ['lord:tree.child2.child0.child2.child2.child3.child2.child0.child0:text']={id='dy_selected_txt',label='Campaign difficulty'},
    ['lord:tree.child2.child0.child2.child2.child3.child2.child1.child0:text']={id='dy_selected_txt',label='Battle difficulty'}
}
-- 0.6.64: the lord list has no race names, only blank separators between the
-- races. A group is named after a lord it contains; an unknown group is
-- "Other lords" (English names, as the game shows them).
local lord_races={}
for race,names in pairs({
    ['High Elves']={'Tyrion','Teclis','Alarielle the Radiant','Alith Anar','Eltharion the Grim','Imrik','Prince Imrik'},
    ['Lizardmen']={'Lord Mazdamundi','Kroq-Gar','Tehenhauin',"Tiktaq'to",'Lord Kroak','Nakai the Wanderer','Gor-Rok','Oxyotl'},
    ['Dark Elves']={'Malekith','Morathi','Crone Hellebron','Lokhir Fellheart','Malus Darkblade','Rakarth'},
    ['Skaven']={'Queek Headtaker','Lord Skrolk','Tretch Craventail','Ikit Claw','Deathmaster Snikch','Throt the Unclean'},
    ['Vampire Coast']={'Luthor Harkon','Count Noctilus','Aranessa Saltspite','Cylostra Direfin'},
    ['Tomb Kings']={'Settra the Imperishable','Grand Hierophant Khatep','High Queen Khalida','Arkhan the Black'},
    ['The Empire']={'Karl Franz','Balthasar Gelt','Volkmar the Grim','Markus Wulfhart'},
    ['Bretonnia']={'Louen Leoncoeur','Alberic de Bordeleaux','Fay Enchantress','Repanse de Lyonesse'},
    ['Beastmen']={'Khazrak the One-Eye','Malagor the Dark Omen','Morghur the Shadowgave','Taurox the Brass Bull'},
    ['Dwarfs']={'Thorgrim Grudgebearer','Ungrim Ironfist','Belegar Ironhammer','Grombrindal','Thorek Ironbrow'},
    ['Greenskins']={'Grimgor Ironhide','Azhag the Slaughterer','Skarsnik','Wurrzag','Grom the Paunch'},
    ['Wood Elves']={'Orion','Durthu','Drycha','Sisters of Twilight'},
    ['Vampire Counts']={'Mannfred von Carstein','Vlad von Carstein','Heinrich Kemmler','Isabella von Carstein','Helman Ghorst'},
    ['Warriors of Chaos']={'Archaon the Everchosen','Kholek Suneater','Prince Sigvald','Prince Sigvald the Magnificent'},
    ['Norsca']={'Wulfrik the Wanderer','Throgg'}}) do
    for _,name in ipairs(names) do lord_races[name]=race end
end
local function lord_spoken_name(item)
    local name=item.raw_name or item.name
    local field=lord_names[item.key]
    if field and field.id==item.id then return field.label .. ': ' .. name end
    if item.id=='checkbox_start_prelude' then return 'Campaign introduction: '
        .. (item.raw_state=='selected' and 'selected' or 'state ' .. item.raw_state) .. '. ' .. name end
    if item.id=='bullet' and starts_with(item.key,'lord:tree.child2.child0.child2.child1.child2.child1.') then
        return 'Race attribute: ' .. name
    end
    if item.id=='unit_category_icon' then return 'Starting unit: ' .. name end -- 0.6.65
    if starts_with(item.id,'lord_effect') and starts_with(item.key,'lord:tree.child2.child0.child2.child2.child1.child1.') then
        local group
        for _,other in ipairs((lord_discovery and lord_discovery.raw) or controls) do
            if other.raw_state=='faction_traits' then group='Faction effect'
            elseif other.raw_state=='lord_traits' then group='Lord effect' end
            if other==item then break end
        end
        if group and item.raw_state~='faction_traits' and item.raw_state~='lord_traits' then return group .. ': ' .. name end
    end
    return name
end
-- NVDA order: name, role, value, states, position, then description.
local screen_titles = {main='Main menu', campaign_selection='Select Campaign', lord_discovery='Select Lord',
    graphics='Graphics', graphics_advanced='Advanced graphics'}
local role_names = {checkbox='check box', dropdown='combo box', slider='slider', button='button',
    ['radio button']='radio button'}
local function engine_states(engine, interactive)
    if interactive == false or engine == 'inactive' then return {'unavailable'} end
    if engine == 'selected' then return {'selected'} end
    return {}
end
local function describe(item)
    if screen_kind == 'main' then return item.name, 'button', nil, engine_states(item.state) end
    if screen_kind == 'lord_discovery' then
        if item.view then return item.view, item.view_role, item.view_value, item.view_states or {}, item.view_description end
        local raw = item.raw_name or item.name
        local selected = item.raw_state == 'selected'
        if item.lord_choice then return item.id, 'radio button', nil, {selected and 'checked' or 'not checked'} end
        if item.id == 'checkbox_start_prelude' then
            return item.label or 'Campaign introduction', 'check box', nil, {selected and 'checked' or 'not checked'}, item.description
        end
        local field = lord_names[item.key]
        if field and field.id == item.id and item.id == 'dy_selected_txt' then return field.label, 'combo box', raw, {} end
        if item.id == 'tab_movie' or item.id == 'tab_map' then return raw, 'tab', nil, selected and {'selected'} or {} end
        if item.id == 'button_options' or item.parent_id == 'button_start_campaign' then return raw, 'button', nil, {} end
        if starts_with(item.id, 'tx_') or item.raw_state == 'faction_traits' or item.raw_state == 'lord_traits' then
            return raw, 'heading', nil, {}
        end
        return lord_spoken_name(item), nil, nil, {}
    end
    if item.role == 'radio button' then
        return item.label, 'radio button', nil, {item.engine_state == 'selected' and 'checked' or 'not checked'}
    end
    if item.role == 'information' then return item.label, nil, item.value, {} end
    if item.role then
        local states = engine_states(item.engine_state, item.interactive)
        if item.role == 'checkbox' and #states == 0 then states = {'state unknown'} end
        return item.label or item.name, role_names[item.role] or item.role, item.value, states
    end
    return item.label or item.name, nil, nil, {}
end
local function spoken_item(item, index, count)
    local name, role, value, states, description = describe(item)
    local parts = {name}
    if role then parts[#parts + 1] = role end
    if value and value ~= '' then parts[#parts + 1] = value end
    for _, state in ipairs(states or {}) do parts[#parts + 1] = state end
    parts[#parts + 1] = index .. ' of ' .. count
    if description and description ~= '' and description ~= name then parts[#parts + 1] = description end
    return table.concat(parts, ', ')
end
local function announce_control(step)
    cancel()
    if #controls == 0 then
        if screen_kind == 'campaign_overlay' then speak('This screen is not supported yet. Press Escape to go back.')
        elseif screen_kind == 'graphics_advanced' then speak('Advanced graphics. No readable controls.')
        elseif screen_kind == 'graphics_advanced_overlay' then speak('This list is not supported yet. Press Escape to close it.')
        elseif screen_kind == 'graphics_overlay' then speak('This dialog is not supported yet. Press Escape to go back.')
        else speak('This screen is not supported yet.') end
        return
    end
    local target = nav_target; nav_target = nil
    if target == 'first' then control_index = 1
    elseif target == 'last' then control_index = #controls
    elseif type(target) == 'number' then control_index = math.max(1, math.min(target, #controls)) -- a new Select Lord step
    elseif type(target) == 'table' then
        -- First-letter navigation: next item whose name starts with the
        -- letter, wrapping; no match leaves the focus where it is, silently.
        local found
        for offset = 1, #controls do
            local index = ((control_index - 1 + offset) % #controls) + 1
            local candidate = controls[index]
            local name = describe(candidate)
            if type(name) == 'string' and string.lower(string.sub(name, 1, 1)) == target.letter then found = index; break end
        end
        if not found then return end
        control_index = found
    elseif control_index == 0 then control_index = step > 0 and 1 or #controls
    else control_index = ((control_index - 1 + step) % #controls) + 1 end
    local item = controls[control_index]
    if screen_kind=='lord_discovery' then item.raw_name=item.raw_name or item.name; item.name=lord_spoken_name(item) end
    local prefix=announce_prefix; announce_prefix=''
    -- Like a screen reader entering a dialog: say the screen name once.
    local title = screen_titles[screen_kind]
    if screen_kind == 'lord_discovery' and lord_discovery and lord_discovery.kind == 'load' then title = 'Load Game' end
    if title and screen_kind ~= last_screen then
        -- Select Lord steps: "Select Lord. Choose a race. ..."
        if screen_kind == 'lord_discovery' and not lord_flat then prefix = title .. '. ' .. prefix
        else prefix = prefix .. title .. '. ' end
    end
    last_screen = screen_kind
    if quiet_announce then return end
    speak(prefix .. spoken_item(item, control_index, #controls))
end
local graphics_key = 'tree.child2.child1.child0.child0.child2.child0.child1'
local graphics_path = {
    {index = 2, id = 'main'}, {index = 1, id = 'banner_clip'},
    {index = 0, id = 'fe_banner'}, {index = 0, id = 'menu'},
    {index = 2, id = 'options_frame'}, {index = 0, id = 'holder'},
    {index = 1, id = 'button_graphics'}
}
local advanced_key = 'tree.child2.child1.child3'
local campaign_key = 'tree.child2.child1.child0.child0.child0.child0.child1'
local targets = {
    CampaignContinue = {name='Continue',key=campaign_continue_key,entry_name='Continue, button',layout='campaign_selection',path={
        {index=2,id='campaign_select'},{index=2,id='button_frame'},{index=0,id='button_next'}}},
    NewCampaign = {name = 'New Campaign', key = campaign_key, entry_name = 'New Campaign', layout = 'main', path = {
        {index = 2, id = 'main'}, {index = 1, id = 'banner_clip'},
        {index = 0, id = 'fe_banner'}, {index = 0, id = 'menu'},
        {index = 0, id = 'campaigns_frame'}, {index = 0, id = 'holder'},
        {index = 1, id = 'button_new_campaign'}}},
    Graphics = {name = 'Graphics', key = graphics_key, entry_name = 'Graphics', layout = 'main', path = graphics_path},
    Advanced = {name = 'Advanced', key = advanced_key, entry_name = 'Advanced, button', layout = 'graphics_basic', path = {
        {index = 2, id = 'options_graphics'}, {index = 1, id = 'basic_options'},
        {index = 3, id = 'button_advanced_options'}}}
}
local function same_layout(snapshot)
    if not snapshot or not snapshot.valid then log('layout.INVALID', 'Snapshot incomplete or unreadable'); return false end
    local layout = snapshot.layout == 'main' and snapshot.nodes['tree.child5'] and verified_main_tooltip_layout
        or snapshot.layout == 'campaign_selection' and verified_campaign_layout
        or snapshot.layout == 'graphics_basic' and verified_basic_layout or verified_layout
    local count = 0
    for prefix, node in pairs(snapshot.nodes) do
        count = count + 1
        local expected = layout[prefix]
        if not expected then log('layout.unverified_node', prefix); return false end
        for method, value in pairs(expected) do
            local read = node[method]
            -- The tester intentionally enabled windowed mode. Both native
            -- states were observed on this one checkbox; neither state is a
            -- requirement for opening Advanced. All other fields remain exact.
            local window_mode_variant = snapshot.layout == 'graphics_basic'
                and prefix == 'tree.child2.child1.child0' and method == 'CurrentState'
                and read and read.ok and type(read.value) == 'string'
                and (read.value == 'active' or read.value == 'selected')
            local campaign_root_variant = snapshot.layout == 'campaign_selection'
                and prefix == 'tree' and method == 'ChildCount' and read and read.ok
                and (read.value == 5 or read.value == 6)
            -- Observed in the live 0.6.30 main-menu capture: this one header
            -- retains hover after the pointer leaves. Identity, visibility and
            -- all other fields remain exact; raw confirmation still detects a
            -- change between active and hover.
            local dlc_header_hover = snapshot.layout == 'main'
                and prefix == 'tree.child2.child1.child0.child0.child3.child0'
                and method == 'CurrentState' and value == 'string:active'
                and read and read.ok and read.value == 'hover'
            -- The fixture was reconstructed from the plain diagnostic log,
            -- which replaces each CR/LF with one space. Compare campaign text
            -- using that same representation, not broader whitespace cleanup.
            -- The confirmation fingerprint and final native leaf comparison
            -- still retain the exact raw strings and detect byte-level changes.
            -- With saves present the game enables Continue Campaign and Load
            -- Campaign (seen live after a test autosave). Only their state and
            -- interactivity may differ; identities and labels stay exact.
            local save_prefix = prefix == 'tree.child2.child1.child0.child0.child0.child0.child2'
                or prefix == 'tree.child2.child1.child0.child0.child0.child0.child2.child0'
                or prefix == 'tree.child2.child1.child0.child0.child0.child0.child3'
                or prefix == 'tree.child2.child1.child0.child0.child0.child0.child3.child0'
            local saves_variant = snapshot.layout == 'main' and save_prefix and read and read.ok
                and ((method == 'CurrentState' and value == 'string:inactive' and (read.value == 'active' or read.value == 'hover'))
                    or (method == 'IsInteractive' and type(read.value) == 'boolean'))
            local diagnostic_text_variant = snapshot.layout == 'campaign_selection'
                and (method == 'GetStateText' or method == 'GetTooltipText')
                and read and read.ok and type(read.value) == 'string'
                and ('string:' .. read.value:gsub('[\r\n]', ' ')) == value
            if not read or not read.ok or (type(read.value) .. ':' .. tostring(read.value) ~= value
                and not window_mode_variant and not campaign_root_variant and not dlc_header_hover and not diagnostic_text_variant and not saves_variant) then
                log('layout.mismatch', prefix .. '.' .. method .. '; expected ' .. quote(value) .. '; got ' .. quote(read and (type(read.value) .. ':' .. tostring(read.value)) or 'missing'))
                return false
            end
        end
    end
    local expected_count = 0
    for _ in pairs(layout) do expected_count = expected_count + 1 end
    if count ~= expected_count then log('layout.node_count', count .. ' instead of ' .. expected_count); return false end
    return true
end
-- WH2 numbers round contemporary Unix seconds to 128-second buckets. Keep
-- epoch seconds as decimal text and confirmation arithmetic relative to a UTC
-- day, where every second remains exactly representable in a single float.
local function decimal_valid(value)
    if type(value)~='string' or #value==0 or #value>10 then return false end
    if #value>1 and string.byte(value,1)==48 then return false end
    for index=1,#value do
        local byte=string.byte(value,index)
        if byte<48 or byte>57 then return false end
    end
    return true
end
local function decimal_add(value,extra)
    local result,carry='',extra
    for index=#value,1,-1 do
        local digit=string.byte(value,index)-48+carry
        result=string.char(48+digit%10) .. result
        carry=math.floor(digit/10)
    end
    while carry>0 do
        result=string.char(48+carry%10) .. result; carry=math.floor(carry/10)
    end
    return result
end
local function decimal_multiply(value,factor)
    local result,carry='',0
    for index=#value,1,-1 do
        local digit=(string.byte(value,index)-48)*factor+carry
        result=string.char(48+digit%10) .. result
        carry=math.floor(digit/10)
    end
    while carry>0 do
        result=string.char(48+carry%10) .. result; carry=math.floor(carry/10)
    end
    return result
end
local function decimal_less(left,right)
    if #left~=#right then return #left<#right end
    return left<right
end
local cached_utc_day,cached_utc_serial,clock_anchor_day
local function utc_clock()
    local text=os.date('!%Y-%m-%d-%H-%M-%S') -- no rounded numeric timestamp argument
    if type(text)~='string' or #text~=19 then error('Confirmation UTC clock unavailable') end
    for _,index in ipairs({5,8,11,14,17}) do
        if string.byte(text,index)~=45 then error('Invalid UTC clock format') end
    end
    local function part(first,last)
        local value=0
        for index=first,last do
            local byte=string.byte(text,index)
            if byte<48 or byte>57 then error('Invalid UTC clock digit') end
            value=value*10+byte-48
        end
        return value
    end
    local year,month,day=part(1,4),part(6,7),part(9,10)
    local hour,minute,second=part(12,13),part(15,16),part(18,19)
    if year<1970 or month<1 or month>12 or hour>23 or minute>59 or second>59 then error('Invalid UTC clock value') end
    local leap=year%4==0 and (year%100~=0 or year%400==0)
    local lengths={31,leap and 29 or 28,31,30,31,30,31,31,30,31,30,31}
    if day<1 or day>lengths[month] then error('Invalid UTC calendar day') end
    local day_key=string.sub(text,1,10)
    if day_key~=cached_utc_day then
        local previous=year-1
        local days=(year-1970)*365+math.floor(previous/4)-math.floor(previous/100)+math.floor(previous/400)-477
        for index=1,month-1 do days=days+lengths[index] end
        cached_utc_day,cached_utc_serial=day_key,days+day-1
    end
    if not clock_anchor_day then clock_anchor_day=cached_utc_serial end
    local seconds=hour*3600+minute*60+second
    local relative=(cached_utc_serial-clock_anchor_day)*86400+seconds
    if relative<0 or relative>=16777216 then error('Confirmation clock precision unavailable') end
    local epoch=decimal_multiply(string.format('%d',cached_utc_serial),86400)
    epoch=decimal_add(epoch,seconds)
    return relative,epoch
end
local function clock_value()
    local value=utc_clock(); return value
end
local function unix_value()
    local _,value=utc_clock(); return value
end
local function resolve_target(snapshot, target)
    if core:is_campaign() or core:is_battle() or not core:is_ui_created() then error('Frontend UI is not ready') end
    local ok, node = observe('activation.root', function() local v = core:get_ui_root(); return v end)
    if not ok or not node then error('Fresh UI root unavailable') end
    local label = 'tree'
    local function check_ancestor(expected_id)
        local reads = snapshot.nodes[label]
        if not reads then error('UI path unavailable') end
        local id_ok, id = observe('activation.' .. label .. '.Id', function() local v = node:Id(); return v end)
        local visible_ok, visible = observe('activation.' .. label .. '.Visible', function() local v = node:Visible(true); return v end)
        local address_ok, address = observe('activation.' .. label .. '.Address', function() local v = node:Address(); return v end)
        if not id_ok or id ~= expected_id or not visible_ok or visible ~= true
            or not address_ok or tostring(address) ~= tostring(reads.Address.value) then error('UI identity or visibility changed') end
    end
    check_ancestor('root')
    for _, step in ipairs(target.path) do
        local found, address = observe('activation.' .. label .. '.Find', function() local v = node:Find(step.index); return v end)
        if not found or not address then error('UI path changed') end
        local converted, child = observe('activation.' .. label .. '.Convert', function() local v = UIComponent(address); return v end)
        if not converted or not child then error('UI conversion failed') end
        node = child
        label = label .. '.child' .. step.index
        check_ancestor(step.id)
    end
    local reads = snapshot.nodes[target.key]
    local interactive_ok, interactive = observe('activation.leaf.IsInteractive', function() local v = node:IsInteractive(); return v end)
    local state_ok, state = observe('activation.leaf.CurrentState', function() local v = node:CurrentState(); return v end)
    local text_ok, text = observe('activation.leaf.GetStateText', function() local v = node:GetStateText(); return v end)
    local tip_ok, tip = observe('activation.leaf.GetTooltipText', function() local v = node:GetTooltipText(); return v end)
    if not interactive_ok or interactive ~= true or not state_ok or state ~= 'active'
        or not text_ok or type(text) ~= 'string' or text ~= reads.GetStateText.value
        or not tip_ok or type(tip) ~= 'string' or tip ~= reads.GetTooltipText.value then error(target.name .. ' state or label changed') end
    if generation ~= snapshot.generation then error('UI recreated during validation') end
    return node
end
-- 0.6.73: the reader state says 'loading' while a campaign loads or the intro
-- movies play (the heartbeat stops then), so the companion does not say "The
-- game is busy." 'movies' clears at the first key tick; 'loading' stays.
local quiet_state
local publish_reader_state -- defined with the key channel below
local function publish_quiet(kind)
    quiet_state = kind
    if publish_reader_state then pcall(publish_reader_state, true) end
end
-- The only native click in the mod. Drops every selection and confirmation
-- before sending the single documented input.
local function send_click(node, name)
    invalidate()
    awaiting_result = name
    log('activation.dispatch', name)
    if log_failed then error('Diagnostic log unavailable before dispatch') end
    activation_outcome = 'input-sent'
    if name == 'Start Campaign' or name == 'Continue Campaign' or name == 'Load' then publish_quiet('loading') end
    -- Timers can stop as soon as the native click enters the loading screen.
    -- Write speech first so the companion can announce it independently.
    if name == 'Start Campaign' then
        speak('Loading campaign. Please wait. An intro movie may play; press Escape to skip it.')
    elseif name == 'Continue Campaign' or name == 'Load' then
        speak('Loading campaign. Please wait.')
    end
    node:SimulateLClick()
    log('activation.returned', true)
end
-- Main menu and Select Campaign (0.6.60): menus differ between PCs (DLC,
-- saves, news banner, language), so no whole-screen template. The selected
-- button is clicked when its ID is allowed and, read again now, it is the same
-- element: same IDs and addresses on its path, visible, same label, interactive
-- and active.
local player_targets = {
    main = {button_new_campaign = 'New Campaign', button_start_campaign = 'Continue Campaign', button_graphics = 'Graphics',
        button_load_campaign = 'Load Campaign'}, -- 0.6.65: opens the save list
    -- 0.6.64: the campaign radio buttons (The Eye of the Vortex, Mortal Empires).
    campaign_selection = {button_next = 'Continue', button_campaign_entry = 'Campaign'}
}
local function path_reads(key)
    local function value(prefix, method)
        local read = scan_reads[prefix .. '.' .. method]
        if read and read.ok then return read.value end
    end
    -- Split "tree.child2.child1" without pattern searches.
    local indices, digits, at = {}, nil, 1
    while at <= #key do
        if string.sub(key, at, at + 5) == '.child' then
            if digits then indices[#indices + 1] = tonumber(digits) end
            digits = ''; at = at + 6
        else
            if digits then digits = digits .. string.sub(key, at, at) end
            at = at + 1
        end
    end
    if digits and digits ~= '' then indices[#indices + 1] = tonumber(digits) end
    local steps, prefix = {{prefix = 'tree', id = value('tree', 'Id'), address = tostring(value('tree', 'Address')), visible = value('tree', 'Visible')}}, 'tree'
    for _, index in ipairs(indices) do
        prefix = prefix .. '.child' .. index
        steps[#steps + 1] = {prefix = prefix, index = index, id = value(prefix, 'Id'),
            address = tostring(value(prefix, 'Address')), visible = value(prefix, 'Visible')}
    end
    for _, step in ipairs(steps) do
        -- Every read on the path must have succeeded with the right type.
        local address = value(step.prefix, 'Address')
        step.readable = type(step.id) == 'string' and type(step.visible) == 'boolean'
            and type(value(step.prefix, 'ChildCount')) == 'number' and type(value(step.prefix, 'IsInteractive')) == 'boolean'
            and type(value(step.prefix, 'GetStateText')) == 'string' and type(value(step.prefix, 'GetTooltipText')) == 'string'
            and type(value(step.prefix, 'CurrentState')) == 'string'
            and (type(address) == 'userdata' or (type(address) == 'string' and address ~= '') or (type(address) == 'number' and address == address and address > 0))
    end
    local leaf = {text = value(key, 'GetStateText'), tip = value(key, 'GetTooltipText'),
        state = value(key, 'CurrentState'), interactive = value(key, 'IsInteractive')}
    return steps, leaf, prefix == key
end
-- Everything read from the screen, to compare the read at selection with the
-- read at activation (never with a recording from another PC): a panel
-- appearing (a DLC purchase panel beside Continue), a changed selection or
-- title cancels. Left out: visibility of unnamed particle effects (they
-- flicker), the contents of the tooltip and news layers, and per-read wrapper
-- objects (Find/Convert/root lookups).
local volatile_methods = {Find = true, Convert = true, object = true}
local function shown_signature()
    local function split(name)
        for at = #name, 1, -1 do
            if string.byte(name, at) == 46 then return string.sub(name, 1, at - 1), string.sub(name, at + 1) end
        end
        return name, ''
    end
    local function root_child(prefix)
        if string.sub(prefix, 1, 10) ~= 'tree.child' then return nil end
        local at = 11
        while at <= #prefix and string.byte(prefix, at) ~= 46 do at = at + 1 end
        return string.sub(prefix, 1, at - 1)
    end
    local parts = {}
    for name, read in pairs(scan_reads) do
        local prefix, method = split(name)
        local keep = string.sub(name, 1, 4) == 'tree' and not volatile_methods[method]
        if keep and method == 'Visible' then
            local id = scan_reads[prefix .. '.Id']
            if id and id.ok and id.value == '' then keep = false end
        end
        local top = keep and root_child(prefix)
        if top then
            local id = scan_reads[top .. '.Id']
            local layer = id and id.ok and (id.value == 'Tooltip' or id.value == 'browser')
            -- The layer's own caption follows the pointer; its contents too.
            if layer and (top ~= prefix or method == 'GetStateText') then keep = false end
        end
        if keep then parts[#parts + 1] = name .. '=' .. tostring(read.ok) .. ':' .. type(read.value) .. ':' .. tostring(read.value) end
    end
    table.sort(parts)
    return table.concat(parts, '|')
end
local function same_element(before_steps, before_leaf, after_steps, after_leaf)
    if #after_steps ~= #before_steps then return false end
    for i, step in ipairs(before_steps) do
        local now = after_steps[i]
        if not step.readable or not now.readable or now.id ~= step.id or now.address ~= step.address or now.visible ~= true then return false end
    end
    return type(before_leaf.text) == 'string' and type(before_leaf.tip) == 'string'
        and after_leaf.text == before_leaf.text and after_leaf.tip == before_leaf.tip
        and after_leaf.state == 'active' and after_leaf.interactive == true
end
local function resolve_element(steps, leaf)
    if core:is_campaign() or core:is_battle() or not core:is_ui_created() then error('Frontend UI is not ready') end
    local ok, node = observe('activation.root', function() local v = core:get_ui_root(); return v end)
    if not ok or not node then error('Fresh UI root unavailable') end
    for i, step in ipairs(steps) do
        if i > 1 then
            local found, address = observe('activation.' .. step.prefix .. '.Find', function() local v = node:Find(step.index); return v end)
            if not found or not address then error('UI path changed') end
            local converted, child = observe('activation.' .. step.prefix .. '.Convert', function() local v = UIComponent(address); return v end)
            if not converted or not child then error('UI conversion failed') end
            node = child
        end
        local id_ok, id = observe('activation.' .. step.prefix .. '.Id', function() local v = node:Id(); return v end)
        local visible_ok, visible = observe('activation.' .. step.prefix .. '.Visible', function() local v = node:Visible(true); return v end)
        local address_ok, address = observe('activation.' .. step.prefix .. '.Address', function() local v = node:Address(); return v end)
        if not id_ok or id ~= step.id or not visible_ok or visible ~= true or not address_ok or tostring(address) ~= step.address then
            error('UI identity or visibility changed')
        end
    end
    local interactive_ok, interactive = observe('activation.leaf.IsInteractive', function() local v = node:IsInteractive(); return v end)
    local state_ok, state = observe('activation.leaf.CurrentState', function() local v = node:CurrentState(); return v end)
    local text_ok, text = observe('activation.leaf.GetStateText', function() local v = node:GetStateText(); return v end)
    local tip_ok, tip = observe('activation.leaf.GetTooltipText', function() local v = node:GetTooltipText(); return v end)
    if not interactive_ok or interactive ~= true or not state_ok or state ~= 'active'
        or not text_ok or text ~= leaf.text or not tip_ok or tip ~= leaf.tip then error('Button state or label changed') end
    return node
end
local function activate_player_target(item)
    local before_steps, before_leaf, complete = path_reads(item.key)
    local leaf_id = before_steps[#before_steps].id
    local name = player_targets[screen_kind] and player_targets[screen_kind][leaf_id]
    if not complete or not name then cancel(); speak('Not supported yet.'); return end
    local radio = leaf_id == 'button_campaign_entry'
    if radio then
        name = item.label or name
        if before_leaf.state == 'selected' then cancel(); speak(name .. ' is already selected.'); return end
    end
    if before_leaf.state ~= 'active' or before_leaf.interactive ~= true then cancel(); speak(name .. ' is unavailable.'); return end
    if not no_extra_panel() then cancel(); speak('Could not read this screen. Press F2 and try again.'); return end
    local kind, selected_index, selected_generation = screen_kind, control_index, generation
    local before_shown = shown_signature()
    log('activation.player_target', leaf_id)
    capture('F4 revalidation')
    local after_steps, after_leaf = path_reads(item.key)
    if screen_kind ~= kind or generation ~= selected_generation or not no_extra_panel() or shown_signature() ~= before_shown
        or not same_element(before_steps, before_leaf, after_steps, after_leaf) then
        invalidate(); speak('The screen changed. Press F2 and try again.'); return
    end
    control_index = selected_index
    local node = resolve_element(after_steps, after_leaf)
    if confirm_activations then
        local now = clock_value()
        if pending and (now < pending.armed_at or now > pending.deadline) then
            cancel(); speak('Confirmation timed out. Press again.'); return
        end
        if not pending then
            pending = {target = item.key, armed_at = now, deadline = now + 4, generation = generation, origin = activation_origin}
            activation_outcome = 'armed'
            log('activation.armed', now)
            speak(name .. '. Press again to confirm.'); return
        end
        if pending.target ~= item.key or pending.generation ~= generation then
            invalidate(); speak('Cancelled: the screen changed.'); return
        end
    end
    if log_failed then invalidate(); speak('Accessibility log unavailable. Restart the game.'); return end
    send_click(node, name)
    if name ~= 'Continue Campaign' then speak(radio and (name .. ' selected.') or (name .. ' activated.')) end
end
local function activate_control()
    if screen_kind == 'graphics_advanced' or screen_kind == 'graphics_advanced_overlay' then cancel(); speak('Not supported yet.'); return end
    if (screen_kind == 'main' or screen_kind == 'campaign_selection') and captured and controls[control_index] then
        activate_player_target(controls[control_index]); return
    end
    if screen_kind == 'campaign_overlay' then cancel(); speak('Not supported yet.'); return end
    local item = controls[control_index]
    if screen_kind == 'campaign_selection' and (not item or item.key ~= campaign_continue_key) then cancel(); speak('Not supported yet.'); return end
    if not captured or not item then cancel(); speak('No item selected. Press F2 to move to an item.'); return end
    local target
    if screen_kind == 'campaign_selection' then target = targets.CampaignContinue
    elseif screen_kind == 'main' then target = item.key == campaign_key and targets.NewCampaign or targets.Graphics
    elseif screen_kind == 'graphics' and item.key == advanced_key then target = targets.Advanced
    else cancel(); speak('Not supported yet.'); return end
    if item.key ~= target.key or item.name ~= target.entry_name or item.state ~= 'active' then
        cancel(); speak('Not supported yet.'); return
    end
    local original = browse_snapshot
    if not original or original.layout ~= target.layout or not same_layout(original) then cancel(); speak('Could not verify this screen. Press F2 and try again.'); return end
    local selected_index, selected_generation = control_index, generation
    local fresh = capture('F4 revalidation')
    if fresh.layout ~= target.layout or not same_layout(fresh) or fresh.generation ~= selected_generation
        or fresh.fingerprint ~= original.fingerprint then
        invalidate(); speak('The screen changed. Press F2 and try again.'); return
    end
    local current = controls[selected_index]
    if not current or current.key ~= item.key or current.name ~= item.name or current.state ~= item.state then
        invalidate(); speak('The screen changed. Press F2 and try again.'); return
    end
    control_index = selected_index
    local node = resolve_target(fresh, target)
    if confirm_activations then
        local now = clock_value()
        if pending and (now < pending.armed_at or now > pending.deadline) then
            cancel(); speak('Confirmation timed out. Press again.'); return
        end
        if not pending then
            pending = {target = target.key, armed_at = now, deadline = now + 4, fingerprint = fresh.fingerprint, generation = generation, origin = activation_origin}
            activation_outcome = 'armed'
            log('activation.armed', now)
            speak(target.name .. '. Press again to confirm.'); return
        end
        if pending.target ~= target.key or pending.generation ~= generation or pending.fingerprint ~= fresh.fingerprint then
            invalidate(); speak('Cancelled: the screen changed.'); return
        end
    end
    if log_failed then invalidate(); speak('Accessibility log unavailable. Restart the game.'); return end
    send_click(node, target.name)
    speak(target.name .. ' activated.')
end
local function screen_still_current()
    -- Unknown setup screens can change descendants without replacing the panel.
    -- Recapture on an explicit browse key; never infer a campaign screen identity.
    if screen_kind == 'unknown' or screen_kind == 'campaign_overlay' then return false end
    if not browse_snapshot or not core:is_ui_created() then return false end
    local root_reads = browse_snapshot.nodes.tree
    local panel_reads = browse_snapshot.nodes['tree.child2']
    if not root_reads or not panel_reads or not root_reads.Address or not panel_reads.Address
        or not panel_reads.Id or not panel_reads.Visible then return false end
    local ok, node = observe('navigation.probe.root', function() local v = core:get_ui_root(); return v end)
    if not ok or not node then return false end
    local address_ok, root_address = observe('navigation.probe.root.Address', function() local v = node:Address(); return v end)
    if not address_ok or tostring(root_address) ~= tostring(root_reads.Address.value) then return false end
    local found, address = observe('navigation.probe.Find', function() local v = node:Find(2); return v end)
    if not found or not address then return false end
    local converted, panel = observe('navigation.probe.Convert', function() local v = UIComponent(address); return v end)
    if not converted or not panel then return false end
    local id_ok, id = observe('navigation.probe.Id', function() local v = panel:Id(); return v end)
    local visible_ok, visible = observe('navigation.probe.Visible', function() local v = panel:Visible(true); return v end)
    local panel_ok, panel_address = observe('navigation.probe.Address', function() local v = panel:Address(); return v end)
    if not (id_ok and id == panel_reads.Id.value and visible_ok and visible == true
        and panel_ok and tostring(panel_address) == tostring(panel_reads.Address.value)) then return false end
    if id == 'main' then
        local main_ok, main_same = observe('navigation.main.shell', function()
            local count = node:ChildCount()
            if count ~= root_reads.ChildCount.value then return false end
            -- Layers above the menu: a hover tooltip or the news browser may
            -- show (as activation allows); any other visible layer is a new
            -- screen. Requiring them hidden reset the focus to item 1 on
            -- every key while a tooltip showed (as on Select Campaign, 0.6.64).
            -- Index 3 is the menu's own frame (sp_frame), always visible.
            -- An unreadable layer does not reset the focus either: activation
            -- still refuses it (no_extra_panel).
            for index = 4, count - 1 do
                local readable, blocking = pcall(function()
                    local extra = UIComponent(node:Find(index))
                    local extra_id = extra:Id()
                    return extra:Visible(true) ~= false and extra_id ~= 'Tooltip' and extra_id ~= 'browser'
                        and not starts_with(extra_id, 'tooltip_')
                end)
                if readable and blocking then return false end
            end
            return true
        end)
        if not main_ok or main_same ~= true then return false end
    end
    if id == 'campaign_select' then
        local shell_ok, shell_same = observe('navigation.campaign.shell', function()
            local count = node:ChildCount()
            if count ~= root_reads.ChildCount.value then return false end
            -- 0.6.64: extra root layers must stay hidden, whatever their name.
            -- Back from Select Lord a hidden tooltip_campaign_select_lord layer
            -- sits here (seen live); requiring "Tooltip" made every arrow key
            -- re-read the screen from the first item.
            for index = 5, count - 1 do
                local extra = UIComponent(node:Find(index))
                if extra:Visible(true) ~= false then return false end
            end
            local count_panel = panel:ChildCount()
            return count_panel == panel_reads.ChildCount.value
        end)
        if not shell_ok or shell_same ~= true then return false end
        local probes = {
            {path={2,0,1,0,1},key=campaign_entries .. '.child0.child1',method='state'},
            {path={2,0,1,1,1},key=campaign_entries .. '.child1.child1',method='state'},
            {path={2,0,0,1,0,1,0},key='tree.child2.child0.child0.child1.child0.child1.child0',method='text'},
            {path={2,0,0,1,0,0,0},key='tree.child2.child0.child0.child1.child0.child0.child0',method='text'},
            {path={2,2,0},key=campaign_continue_key,method='state'},
            {path={2,2},key='tree.child2.child2',method='count'}}
        for _, spec in ipairs(probes) do
            local same_ok, same = observe('navigation.campaign.' .. spec.key, function()
                local current = node
                for _, index in ipairs(spec.path) do current = UIComponent(current:Find(index)) end
                local previous = browse_snapshot.nodes[spec.key]
                if not previous or current:Id() ~= previous.Id.value or current:Visible(true) ~= true
                    or tostring(current:Address()) ~= tostring(previous.Address.value) then return false end
                local value
                if spec.method == 'state' then value = current:CurrentState(); return value == previous.CurrentState.value
                elseif spec.method == 'text' then value = current:GetStateText(); return value == previous.GetStateText.value
                else value = current:ChildCount(); return value == previous.ChildCount.value end
            end)
            if not same_ok or same ~= true then return false end
        end
    end
    if id == 'options_graphics' then
        for i = 0, 2 do
            local found_child, child_address = observe('navigation.probe.panel.Find' .. i, function() local v = panel:Find(i); return v end)
            if not found_child or not child_address then return false end
            local converted_child, child = observe('navigation.probe.panel.Convert' .. i, function() local v = UIComponent(child_address); return v end)
            if not converted_child or not child then return false end
            local child_ok, child_visible = observe('navigation.probe.panel.Visible' .. i, function() local v = child:Visible(true); return v end)
            if not child_ok or type(child_visible) ~= 'boolean' or child_visible ~= browse_snapshot.panel_visibility[i + 1] then return false end
        end
    end
    return true
end
-- Separate, read-only breadth-first discovery. It never contributes an
-- activation snapshot, and leaves the proven depth-first scanner unchanged.
local lord_file_started,lord_file_bytes,lord_run=false,0,0
local function lord_read(fn)
    local value
    local ok,err=pcall(function() value=fn() end)
    return ok,value,err
end
local function lord_identity(value)
    local kind=type(value)
    if kind=='userdata' or (kind=='string' and value~='') then return tostring(value) end
    return nil
end
-- Log why the Lord context was rejected, once per distinct reason, so a
-- screen the reader refuses (overlay, tooltip, changed layout) is diagnosable.
local lord_last_reject
local function lord_reject(reason)
    if reason~=lord_last_reject then lord_last_reject=reason; plain_log('lord.context_reject',reason) end
    return nil
end
local function lord_context()
    if not core:is_frontend() or not core:is_ui_created() then return nil end
    local ok,root=lord_read(function() local v=core:get_ui_root(); return v end)
    if not ok or not root then return lord_reject('root-unavailable') end
    local _,id=lord_read(function() local v=root:Id(); return v end)
    local _,visible=lord_read(function() local v=root:Visible(true); return v end)
    local _,count=lord_read(function() local v=root:ChildCount(); return v end)
    -- 0.6.62: other PCs differ (seen on the main menu in the first outside
    -- trial), so no exact counts: extra root layers may be tooltips or
    -- anything hidden (the browser included); a visible or unreadable other
    -- layer (a dialog or web page on top) still blocks. Activation re-checks
    -- the chosen element.
    if id~='root' or visible~=true or type(count)~='number' or count<3 or count>32 then
        return lord_reject('root id=' .. tostring(id) .. ' visible=' .. tostring(visible) .. ' count=' .. tostring(count))
    end
    for index=4,count-1 do
        local _,extra_address=lord_read(function() local v=root:Find(index); return v end)
        if not extra_address then return lord_reject('extra ' .. index .. ' missing') end
        local extra_ok,extra=lord_read(function() local v=UIComponent(extra_address); return v end)
        if not extra_ok or not extra then return lord_reject('extra ' .. index .. ' unconvertible') end
        local _,extra_id=lord_read(function() local v=extra:Id(); return v end)
        local _,extra_visible=lord_read(function() local v=extra:Visible(true); return v end)
        -- Hover tooltips are non-interactive text layers; selecting a lord
        -- leaves a hidden tooltip_campaign_select_lord at the root (seen
        -- live in 0.6.20).
        if type(extra_id)~='string' or type(extra_visible)~='boolean' then
            return lord_reject('extra ' .. index .. ' unreadable')
        end
        local allowed=extra_id=='Tooltip' or starts_with(extra_id,'tooltip_')
        if extra_visible and not allowed then
            return lord_reject('extra ' .. index .. ' id=' .. extra_id .. ' visible=true')
        end
    end
    local _,address=lord_read(function() local v=root:Find(2); return v end)
    if not address then return lord_reject('panel missing') end
    local converted,panel=lord_read(function() local v=UIComponent(address); return v end)
    if not converted or not panel then return lord_reject('panel unconvertible') end
    local _,panel_id=lord_read(function() local v=panel:Id(); return v end)
    local _,panel_visible=lord_read(function() local v=panel:Visible(true); return v end)
    local _,panel_count=lord_read(function() local v=panel:ChildCount(); return v end)
    -- 0.6.66: the same bounded reader serves Load Game (load_save_game).
    local panel_kind=(panel_id=='sp_grand_campaign' and 'lord') or (panel_id=='load_save_game' and 'load') or nil
    if not panel_kind or panel_visible~=true or type(panel_count)~='number' or panel_count<1 then
        return lord_reject('panel id=' .. tostring(panel_id) .. ' visible=' .. tostring(panel_visible) .. ' count=' .. tostring(panel_count))
    end
    local _,root_address=lord_read(function() local v=root:Address(); return v end)
    local _,panel_address=lord_read(function() local v=panel:Address(); return v end)
    root_address,panel_address=lord_identity(root_address),lord_identity(panel_address)
    if not root_address or not panel_address then return lord_reject('identity unavailable') end
    lord_last_reject=nil
    return {root=root,root_address=root_address,panel_address=panel_address,generation=generation,kind=panel_kind,panel_id=panel_id}
end
local function lord_log(line)
    if not log_path then error('Lord discovery output unavailable') end
    local base=string.sub(log_path,1,#log_path-#'native-ui-graphics-preview.log')
    if lord_file_bytes+#line+2>2097152 then error('Lord discovery log budget reached') end
    local f=io.open(base .. 'native-ui-lord-discovery.jsonl',lord_file_started and 'a' or 'w')
    if not f then error('Lord discovery output could not be opened') end
    local written=f:write(line .. '\n'); local closed=f:close()
    if not written or closed==nil then error('Lord discovery output write failed') end
    lord_file_started=true; lord_file_bytes=lord_file_bytes+#line+2
end
-- Text fields are bounded to 1000 bytes (whole UTF-8 characters).
local function lord_truncate(value)
    if type(value)~='string' then return '' end
    if #value>1000 then return (string.sub(value,1,1000):gsub('[\192-\255][\128-\191]*$','')) end
    return value
end
local function lord_text(value)
    if type(value)=='string' and #value>1000 then lord_discovery.limited=true end
    return lord_truncate(value)
end
local function lord_begin(context)
    invalidate()
    if lord_file_bytes>1048576 then lord_file_started,lord_file_bytes=false,0 end
    lord_run=lord_run+1
    lord_discovery={root_address=context.root_address,panel_address=context.panel_address,
        generation=generation,queue={{path={2},label='tree.child2',ids={}}},head=1,
        visited=0,page=0,done=false,limited=false,errors=0,kind=context.kind or 'lord'}
    screen_kind='lord_discovery'; latest_snapshot=nil
    lord_log('{"kind":"begin","run":' .. lord_run .. ',"generation":' .. generation
        .. ',"panel":' .. quote(context.panel_id or 'sp_grand_campaign') .. ',"read_only":true,"page_budget":48,"node_budget":1536}')
    if awaiting_result then log('activation.result_requires_mapping',awaiting_result .. ':lord_discovery'); awaiting_result=nil end
end
local function lord_resolve(root,path)
    local node=root
    for _,index in ipairs(path) do
        local ok,visible=lord_read(function() local v=node:Visible(true); return v end)
        if not ok then return nil,'read-error' end
        if visible~=true then return nil,'hidden' end
        local found,address=lord_read(function() local v=node:Find(index); return v end)
        if not found or not address then return nil,'missing' end
        local converted,child=lord_read(function() local v=UIComponent(address); return v end)
        if not converted or not child then return nil,'read-error' end
        node=child
    end
    local ok,visible=lord_read(function() local v=node:Visible(true); return v end)
    if not ok then return nil,'read-error' end
    if visible~=true then return nil,'hidden' end
    return node
end
local function lord_page(announce)
    local context=lord_context()
    if not context then
        if lord_discovery then invalidate() end
        return 'blocked'
    end
    local d=lord_discovery
    if not d or d.generation~=generation or d.root_address~=context.root_address or d.panel_address~=context.panel_address then
        lord_begin(context); d=lord_discovery
    end
    if not d.done then
        d.page=d.page+1
        local examined=0
        while examined<48 and d.head<=#d.queue and d.visited<1536 do
            local item=d.queue[d.head]; d.head=d.head+1
            examined=examined+1; d.visited=d.visited+1
            -- Resolve the index path again from this request's fresh root.
            -- No native component or address is retained between requests.
            local node,reason=lord_resolve(context.root,item.path)
            if node then
                local values,types={},{}
                local getters={
                    Id=function() local v=node:Id(); return v end,
                    GetStateText=function() local v=node:GetStateText(); return v end,
                    GetTooltipText=function() local v=node:GetTooltipText(); return v end,
                    CurrentState=function() local v=node:CurrentState(); return v end,
                    ChildCount=function() local v=node:ChildCount(); return v end,
                    IsInteractive=function() local v=node:IsInteractive(); return v end}
                for _,method in ipairs({'Id','GetStateText','GetTooltipText','CurrentState','ChildCount','IsInteractive'}) do
                    local ok,value=lord_read(getters[method])
                    types[method]=ok and type(value) or 'error'
                    values[method]=value
                    local wanted=(method=='ChildCount' and 'number') or (method=='IsInteractive' and 'boolean') or 'string'
                    if not ok or type(value)~=wanted then d.errors=d.errors+1; d.limited=true end
                end
                local id,text,tip,state=lord_text(values.Id),lord_text(values.GetStateText),lord_text(values.GetTooltipText),lord_text(values.CurrentState)
                local count=values.ChildCount
                local valid_count=type(count)=='number' and count==count and count>=0 and count%1==0
                if not valid_count then count=0; d.limited=true end
                lord_log('{"kind":"node","run":' .. lord_run .. ',"page":' .. d.page
                    .. ',"path":' .. quote(item.label) .. ',"id":' .. quote(id)
                    .. ',"text":' .. quote(text) .. ',"tooltip":' .. quote(tip) .. ',"state":' .. quote(state)
                    .. ',"visible":true,"children":' .. count .. ',"interactive":' .. tostring(values.IsInteractive==true)
                    .. ',"text_type":' .. quote(types.GetStateText) .. ',"tooltip_type":' .. quote(types.GetTooltipText) .. '}')
                local name=clean(text)
                local tooltip=clean(tip)
                local parent_id=(item.ids or {})[#(item.ids or {})]
                local function entry(suffix,label)
                    if label=='' then return end
                    -- Fold the intro check box's label/description into one
                    -- check box entry; drop labels that repeat a combo box.
                    if parent_id=='checkbox_start_prelude' then
                        if suffix=='text' and d.checkbox_entry then d.checkbox_entry.label=label end
                        return
                    end
                    if id=='tx' and (parent_id=='dropdown_campaign' or parent_id=='dropdown_battle') then return end
                    if #controls>=512 then d.limited=true; return end
                    local key='lord:' .. item.label .. ':' .. suffix
                    local entry_item={key=key,name=label,
                        state=(state=='selected' or state=='inactive') and state or '',read_only=true,id=id,raw_state=state,parent_id=parent_id}
                    if id=='checkbox_start_prelude' then
                        entry_item.description=label; d.checkbox_entry=entry_item
                        -- The intro check box can be toggled (the tutorial locks End Turn).
                        if values.IsInteractive==true then
                            local path,ancestors={},{}
                            for part,value in ipairs(item.path) do path[part]=value end
                            for part,value in ipairs(item.ids or {}) do ancestors[part]=value end
                            entry_item.prelude,entry_item.choice_path,entry_item.choice_ids,entry_item.read_only=true,path,ancestors,false
                        end
                    end
                    if parent_id=='button_start_campaign' and suffix=='text' then
                        local ids=item.ids or {}
                        local path,ancestors={},{}
                        for part=1,#item.path-1 do path[part]=item.path[part] end
                        for part=1,#ids-1 do ancestors[part]=ids[part] end
                        entry_item.start_campaign,entry_item.choice_path,entry_item.choice_ids,entry_item.read_only=true,path,ancestors,false
                    end
                    -- Remember where the few named fields live so a later
                    -- browse can notice a manual lord/difficulty change.
                    local field=lord_names[key]
                    if suffix=='text' and field and field.id==id then
                        local path={}
                        for part,value in ipairs(item.path) do path[part]=value end
                        entry_item.watch_path,entry_item.watch_text=path,label
                        if lord_awaiting and field.label=='Selected lord' then
                            log('activation.observed_result',(label==lord_awaiting and 'lord-match:' or 'lord-mismatch:') .. label)
                            announce_prefix=label==lord_awaiting and (label .. ' is now selected. ')
                                or ('Selection not confirmed: the selected lord is ' .. label .. '. ')
                            lord_awaiting=nil
                        end
                    end
                    controls[#controls+1]=entry_item
                end
                entry('text',name)
                if tooltip~=name then entry('tooltip',tooltip) end
                -- Ancestor IDs travel with each queued path so lord portraits
                -- can be recognised and re-verified by their exact ID chain.
                local child_ids={}
                for part,value in ipairs(item.ids or {}) do child_ids[part]=value end
                child_ids[#child_ids+1]=id
                local ids,depth=item.ids or {},#(item.ids or {})
                local in_lord_list=depth>=4 and ids[depth]=='list_box' and ids[depth-1]=='list_clip' and ids[depth-2]=='list'
                    and ids[depth-3]=='lord_select_list'
                -- 0.6.64: the blank race_spacer entries separate the races in the lord list.
                if in_lord_list and id=='race_spacer' then d.spacers=d.spacers or {}; d.spacers[item.path[#item.path]]=true end
                if in_lord_list and id~='' and id~='race_spacer' and id~='show_all_dlc'
                    and (state=='active' or state=='selected' or state=='hover') and values.IsInteractive==true then
                    if #controls>=512 then d.limited=true else
                        local path={}
                        for part,value in ipairs(item.path) do path[part]=value end
                        controls[#controls+1]={key='lord:' .. item.label .. ':choice',name='Lord choice: ' .. id,
                            state=state=='selected' and 'selected' or '',read_only=false,id=id,raw_state=state,
                            lord_choice=true,choice_path=path,choice_ids=ids,list_index=item.path[#item.path]}
                    end
                end
                -- 0.6.66 Load Game: campaign rows (playthroughN), save rows
                -- (save_game), the Load button and the incompatible-saves box.
                -- The delete button is never recorded.
                if d.kind=='load' then
                    d.load=d.load or {playthroughs={},saves={},by_label={}}
                    local load=d.load
                    local function row(list)
                        local path={}; for part,value in ipairs(item.path) do path[part]=value end
                        local record={path=path,ids=ids,id=id,state=state,interactive=values.IsInteractive==true,
                            tooltip=tooltip,texts={},invalid=false,label=item.label}
                        list[#list+1]=record; load.by_label[item.label]=record
                    end
                    if depth>=2 and ids[depth]=='list_box' and starts_with(id,'playthrough') then row(load.playthroughs)
                    elseif depth>=2 and ids[depth]=='list_box' and id=='save_game' then row(load.saves)
                    elseif id=='button_confirm_load' or id=='checkbox_incompatible_saves' then
                        local path={}; for part,value in ipairs(item.path) do path[part]=value end
                        load[id]={path=path,ids=ids,id=id,state=state,interactive=values.IsInteractive==true,tooltip=tooltip}
                    elseif id=='tx_incompatible_saves' then load.incompatible_label,load.incompatible_tip=name,tooltip end
                    -- Texts inside a row (faction, campaign, date, name, difficulty...).
                    local parent_label
                    for at=#item.label,1,-1 do
                        if string.byte(item.label,at)==46 then parent_label=string.sub(item.label,1,at-1); break end
                    end
                    local owner=parent_label and load.by_label[parent_label]
                    if owner and name~='' then owner.texts[#owner.texts+1]={id=id,text=name} end
                    if owner and state=='invalid' then owner.invalid=true end
                end
                -- 0.6.64: the difficulty combo boxes and, while one is open, its list.
                local function copy_path() local path={}; for part,value in ipairs(item.path) do path[part]=value end; return path end
                if id=='dropdown_campaign' or id=='dropdown_battle' then
                    d.dropdowns=d.dropdowns or {}
                    d.dropdowns[id]={path=copy_path(),ids=ids,state=state,interactive=values.IsInteractive==true}
                end
                for part=1,depth do
                    local owner=ids[part]
                    -- Everything inside the combo box except its own value and label.
                    if (owner=='dropdown_campaign' or owner=='dropdown_battle')
                        and not (part==depth and (id=='dy_selected_txt' or id=='tx')) then
                        d.popup=d.popup or {}
                        local list=d.popup[owner] or {}; d.popup[owner]=list
                        list[#list+1]={path=copy_path(),ids=ids,id=id,text=name,label=item.label,interactive=values.IsInteractive==true,
                            state=state,children=count,parent_id=parent_id}
                        break
                    end
                end
                if #item.path>=16 and count>0 then d.limited=true
                else
                    if count>100 then d.limited=true end
                    for index=0,math.min(count,100)-1 do
                        if #d.queue>=2048 then d.limited=true; break end
                        local path={}
                        for part,value in ipairs(item.path) do path[part]=value end
                        path[#path+1]=index
                        d.queue[#d.queue+1]={path=path,label=item.label .. '.child' .. index,ids=child_ids}
                    end
                end
            else
                if reason~='hidden' then d.errors=d.errors+1; d.limited=true end
                lord_log('{"kind":"skip","run":' .. lord_run .. ',"page":' .. d.page
                    .. ',"path":' .. quote(item.label) .. ',"reason":' .. quote(reason) .. '}')
            end
        end
        d.done=d.head>#d.queue or d.visited>=1536
        if d.visited>=1536 and d.head<=#d.queue then d.limited=true end
        lord_log('{"kind":"page","run":' .. lord_run .. ',"page":' .. d.page
            .. ',"examined":' .. examined .. ',"total":' .. d.visited .. ',"remaining":' .. math.max(0,#d.queue-d.head+1)
            .. ',"entries":' .. #controls .. ',"errors":' .. d.errors .. ',"done":' .. tostring(d.done)
            .. ',"complete":' .. tostring(d.done and not d.limited) .. ',"limited":' .. tostring(d.limited) .. '}')
    end
    screen_kind='lord_discovery'
    local result=d.done and (d.limited and 'discovery-limited' or 'discovery-complete') or 'discovery-page'
    if announce and d.done then speak(d.limited and 'Screen read, but some content was skipped.' or 'Screen read again.') end
    return result
end
-- Re-read only the watched named fields (at most five short paths). Returns
-- the label of the first field that changed, vanished or failed to read.
local function lord_changed_field(context)
    for _,item in ipairs((lord_discovery and lord_discovery.raw) or controls) do
        if item.watch_path then
            local node=lord_resolve(context.root,item.watch_path)
            if not node then return item.watch_text end
            local ok,text=lord_read(function() local v=node:GetStateText(); return v end)
            if not ok or clean(lord_truncate(text))~=item.watch_text then return item.watch_text end
        end
    end
    return nil
end
-- 0.6.64: the steps are views over the same complete read (d.raw); choosing
-- still goes through the raw items and their checks.
local function lord_groups(d)
    local groups,current,last_index={},nil,nil
    for _,item in ipairs(d.raw) do
        if item.lord_choice then
            local split=not current
            if current and last_index and item.list_index then
                for index=last_index+1,item.list_index-1 do
                    if d.spacers and d.spacers[index] then split=true; break end
                end
            end
            if split then current={lords={}}; groups[#groups+1]=current end
            current.lords[#current.lords+1]=item
            last_index=item.list_index
            if item.raw_state=='selected' then current.selected=#current.lords end
        end
    end
    local unknown=0
    for _,group in ipairs(groups) do
        for _,lord in ipairs(group.lords) do
            if lord_races[lord.id] then group.name=lord_races[lord.id]; break end
        end
        if not group.name then unknown=unknown+1; group.name='Other lords' .. (unknown>1 and (' ' .. unknown) or '') end
    end
    return groups
end
local function lord_view_item(view,kind,extra)
    local item={key='view:' .. kind .. ':' .. ((extra and extra.tag) or view),view=view,view_kind=kind,read_only=false,state=''}
    for name,value in pairs(extra or {}) do item[name]=value end
    return item
end
-- 0.6.66 Load Game as two steps: choose a campaign, then a save and Load.
local function load_row_name(record)
    local by={}
    for _,text in ipairs(record.texts) do by[text.id]=by[text.id] or text.text end
    local parts={}
    local function add(value) if value and value~='' then parts[#parts+1]=value end end
    if by.name then -- a save row
        add(by.name); add(by.dy_difficulty)
        if by.turn then add('turn ' .. by.turn) end
        add(by.save_date)
    else -- a campaign row
        add(by.dy_faction); add(by.dy_campaign)
        if by.dy_date or by.dy_time then add(table.concat({by.dy_date or '',by.dy_time or ''},' '):gsub('^ +',''):gsub(' +$','')) end
        if by.dy_turns then add('turn ' .. by.dy_turns) end
    end
    if #parts==0 then for _,text in ipairs(record.texts) do add(text.text) end end
    return #parts>0 and table.concat(parts,', ') or record.id
end
local function load_build_view(d)
    local load=d.load or {playthroughs={},saves={}}
    local view={}
    if lord_step~='saves' then lord_step='playthroughs' end
    if lord_step=='playthroughs' then
        for position,record in ipairs(load.playthroughs) do
            view[#view+1]=lord_view_item(load_row_name(record),'playthrough',{view_role='list item',row=record,tag=tostring(position),
                view_states=record.state=='selected' and {'selected'} or {}})
        end
    else
        for position,record in ipairs(load.saves) do
            local states={}
            if record.state=='selected' then states[#states+1]='selected' end
            if record.invalid then states[#states+1]='unavailable' end
            view[#view+1]=lord_view_item(load_row_name(record),'save',{view_role='list item',row=record,tag=tostring(position),
                view_states=states,view_description=record.invalid and record.tooltip or nil})
        end
        local button=load.button_confirm_load
        if button then
            view[#view+1]=lord_view_item('Load','load_button',{view_role='button',tag='load',
                view_states=(button.state=='inactive' or not button.interactive) and {'unavailable'} or {}})
        end
        local box=load.checkbox_incompatible_saves
        if box then
            view[#view+1]=lord_view_item(load.incompatible_label~='' and load.incompatible_label or 'Enable all saves','incompatible',{view_role='check box',tag='incompatible',
                view_states={(box.state=='selected' or box.state=='selected_hover') and 'checked' or 'not checked'},view_description=load.incompatible_tip})
        end
        view[#view+1]=lord_view_item('Back','back',{view_role='button',tag='back'})
    end
    return view
end
local function lord_build_view(d)
    if d.kind=='load' then return load_build_view(d) end
    local raw=d.raw
    local groups=lord_groups(d); d.groups=groups
    local values={}
    for _,item in ipairs(raw) do
        local field=lord_names[item.key]
        if field and field.id==item.id and item.watch_text then values[field.label]=item.watch_text end
    end
    local view={}
    local function back() view[#view+1]=lord_view_item('Back','back',{view_role='button',tag='back'}) end
    if lord_step=='lords' and not groups[lord_step_race or 0] then lord_step='races' end
    if lord_step=='races' then
        for index,group in ipairs(groups) do
            local n=#group.lords
            view[#view+1]=lord_view_item(group.name .. ', ' .. n .. (n==1 and ' lord' or ' lords'),'race',{race=index,tag=tostring(index)})
        end
    elseif lord_step=='lords' then
        for _,lord in ipairs(groups[lord_step_race].lords) do view[#view+1]=lord end
        back()
    elseif lord_step=='setup' then
        local lord,race=values['Selected lord'],values['Race']
        for _,group in ipairs(groups) do
            if group.selected then
                lord=lord or group.lords[group.selected].id
                if not race and not starts_with(group.name,'Other lords') then race=group.name end
            end
        end
        local who={lord or 'none chosen'}
        if race then who[#who+1]=race end
        if values['Faction'] then who[#who+1]=values['Faction'] end
        view[#view+1]=lord_view_item('Lord: ' .. table.concat(who,', '),'summary',{view_role='button',tag='summary'})
        for _,spec in ipairs({{'Campaign difficulty','dropdown_campaign'},{'Battle difficulty','dropdown_battle'}}) do
            local dd=d.dropdowns and d.dropdowns[spec[2]]
            if dd or values[spec[1]] then
                local usable=dd and dd.interactive and dd.state~='inactive'
                view[#view+1]=lord_view_item(spec[1],'combo',{view_role='combo box',view_value=values[spec[1]] or 'value unavailable',
                    view_states=usable and {} or {'unavailable'},field=spec[2],tag=spec[2]})
            end
        end
        for _,item in ipairs(raw) do if item.id=='checkbox_start_prelude' then view[#view+1]=item; break end end
        view[#view+1]=lord_view_item('Lord and faction details','details',{view_role='button',tag='details'})
        for _,item in ipairs(raw) do if item.start_campaign then view[#view+1]=item; break end end
    elseif lord_step=='details' then
        local in_popup={}
        for _,list in pairs(d.popup or {}) do
            for _,node in ipairs(list) do in_popup['lord:' .. node.label .. ':text']=true; in_popup['lord:' .. node.label .. ':tooltip']=true end
        end
        -- Grouped like a document: each heading followed by its own text
        -- (the read is breadth-first, so headings came long before their text).
        -- An item outside the known sections keeps its place at the end.
        local sections={
            'lord:tree.child2.child0.child2.child1.child2',      -- race attributes
            'lord:tree.child2.child0.child2.child2.child1.child1', -- faction and lord effects
            'lord:tree.child2.child0.child2.child2.child2',      -- additional starting units
            'lord:tree.child2.child0.child2.child2.child5'}      -- recommended first campaign
        local function rank(item)
            for position,prefix in ipairs(sections) do
                local follows=string.sub(item.key,#prefix+1,#prefix+1)
                if starts_with(item.key,prefix) and (follows=='.' or follows==':') then return position end
            end
            return #sections+1
        end
        local chosen={}
        for _,item in ipairs(raw) do
            local field=lord_names[item.key]
            local named=field and field.id==item.id
            if not item.lord_choice and not item.start_campaign and item.id~='checkbox_start_prelude' and not named
                and item.id~='tx_header' and item.id~='tx_difficulty' and not in_popup[item.key] then
                chosen[#chosen+1]={item=item,rank=rank(item),order=#chosen+1}
            end
        end
        table.sort(chosen,function(a,b) if a.rank~=b.rank then return a.rank<b.rank end return a.order<b.order end)
        for _,entry in ipairs(chosen) do view[#view+1]=entry.item end
        back()
    elseif lord_step=='options' then
        local current=values[lord_step_field=='dropdown_battle' and 'Battle difficulty' or 'Campaign difficulty']
        for position,node in ipairs((d.popup and d.popup[lord_step_field]) or {}) do
            if node.text~='' then
                view[#view+1]=lord_view_item(node.text,'option',{node=node,tag=tostring(position),
                    view_states=node.text==current and {'selected'} or {}})
            end
        end
        back()
    end
    return view
end
-- Where to stand after a step change: a number, 'selected' (the chosen lord
-- or its race) or an item key.
local function lord_resolve_focus(d,view,focus)
    if type(focus)=='number' then return focus end
    for position,item in ipairs(view) do
        if focus=='selected' and ((item.view_kind=='race' and d.groups[item.race] and d.groups[item.race].selected)
            or (item.lord_choice and item.raw_state=='selected')
            or ((item.view_kind=='option' or item.view_kind=='playthrough' or item.view_kind=='save') and item.view_states[1]=='selected')) then
            return position
        end
        if item.key==focus then return position end
    end
    return 1
end
local function lord_browse(step)
    local context=lord_context()
    if not context then
        if lord_discovery then invalidate() end
        return false
    end
    local d=lord_discovery
    if d and d.generation==generation and d.root_address==context.root_address
        and d.panel_address==context.panel_address then
        local changed=lord_changed_field(context)
        if changed then
            lord_log('{"kind":"stale","run":' .. lord_run .. ',"field":' .. quote(changed) .. '}')
            lord_begin(context); d=lord_discovery
            announce_prefix='Screen updated. '; step=1
        end
    end
    if not d or d.root_address~=context.root_address or d.panel_address~=context.panel_address
        or d.generation~=generation or not d.done then
        -- Read the whole bounded Lord setup at once so positions and totals
        -- are final, as a screen reader expects. The node budget (1536 at 48
        -- per page) caps this at 32 pages; Discover stays one page per call.
        for _=1,40 do
            if lord_page(false)=='blocked' or not lord_discovery or lord_discovery.done then break end
        end
    end
    local view_d=lord_discovery
    if view_d and view_d.done and (not lord_flat or view_d.kind=='load') then
        view_d.raw=view_d.raw or controls
        if view_d.kind=='load' and lord_step~='playthroughs' and lord_step~='saves' then
            lord_step,lord_focus,lord_step_prefix='playthroughs','selected','Choose a campaign. ' -- arriving at Load Game
        elseif view_d.kind~='load' and lord_step=='races' and last_screen~='lord_discovery' and not lord_focus then
            lord_focus,lord_step_prefix='selected','Choose a race. ' -- arriving at Select Lord
        end
        controls=lord_build_view(view_d)
        if lord_focus then nav_target=lord_resolve_focus(view_d,controls,lord_focus); lord_focus=nil end
        if lord_step_prefix~='' then announce_prefix=announce_prefix .. lord_step_prefix; lord_step_prefix='' end
        if control_index>#controls then control_index=0 end
    end
    if #controls==0 then
        speak('This screen has no readable text.')
    else
        if lord_resume_key then
            for position,item in ipairs(controls) do
                if item.key==lord_resume_key then control_index=position end
            end
            lord_resume_key=nil
        end
        announce_control(step)
    end
    return true
end

-- Resolve a captured path from a fresh root, requiring every ancestor to be
-- visible and to have the exact captured ID, and the leaf to have leaf_id.
local function lord_resolve_checked(root,path,ids,leaf_id)
    if #path~=#ids+1 then return nil,'identity' end
    local node=root
    for step,index in ipairs(path) do
        local ok,visible=lord_read(function() local v=node:Visible(true); return v end)
        if not ok or visible~=true then return nil,'hidden' end
        local found,address=lord_read(function() local v=node:Find(index); return v end)
        if not found or not address then return nil,'missing' end
        local converted,child=lord_read(function() local v=UIComponent(address); return v end)
        if not converted or not child then return nil,'read-error' end
        local id_ok,id=lord_read(function() local v=child:Id(); return v end)
        local wanted=step<=#ids and ids[step] or leaf_id
        if not id_ok or id~=wanted then return nil,'identity' end
        node=child
    end
    local ok,visible=lord_read(function() local v=node:Visible(true); return v end)
    if not ok or visible~=true then return nil,'hidden' end
    return node
end
-- Double-confirmed lord selection. Only lord-choice entries from a complete,
-- still-current capture; every other Lord setup entry stays read only.
-- "Start the campaign as Tyrion, High Elves, Eataine?" from the captured fields.
local function start_prompt()
    local values={}
    for _,other in ipairs((lord_discovery and lord_discovery.raw) or controls) do
        local field=lord_names[other.key]
        if field and other.watch_text then values[field.label]=other.watch_text end
    end
    local parts={}
    for _,label in ipairs({'Selected lord','Race','Faction'}) do if values[label] then parts[#parts+1]=values[label] end end
    local who=#parts>0 and (' as ' .. table.concat(parts,', ')) or ''
    return 'Start the campaign' .. who .. '? Press Enter again to start.'
end
-- 0.6.64 steps: move between steps, open a difficulty list, choose an option.
local function lord_go(step,race,focus,prefix)
    lord_step,lord_focus,lord_step_prefix=step,focus or 1,prefix or ''
    if race then lord_step_race=race end
    lord_browse(0)
end
-- A read shortly after a click, from the key timer, so the result is spoken
-- without another key press (the click takes effect after this handler).
local function lord_schedule_reread() lord_reread_at,lord_reread_left=5,8 end
-- Click a recorded element after checking the screen and its ID chain again.
local function lord_click(d,path,ids,leaf,label)
    local context=lord_context()
    if not d or not d.done or d.limited then
        cancel(); speak(d and d.done and 'This screen could not be read completely, so choosing is unavailable.'
            or 'Still reading this screen. Press F2, then try again.'); return false
    end
    if not context or d.generation~=generation or context.root_address~=d.root_address or context.panel_address~=d.panel_address then
        log('activation.lord_blocked','context'); invalidate(); speak('The screen changed. Press F2 and try again.'); return false
    end
    local node,reason=lord_resolve_checked(context.root,path,ids,leaf)
    if not node then invalidate(); log('activation.lord_unverified',reason); speak('The screen changed. Press F2 and try again.'); return false end
    local interactive_ok,interactive=lord_read(function() local v=node:IsInteractive(); return v end)
    local state_ok,state=lord_read(function() local v=node:CurrentState(); return v end)
    if not interactive_ok or interactive~=true or not state_ok or state=='inactive' or type(state)~='string' then
        log('activation.lord_blocked','state:' .. tostring(state)); invalidate(); speak(label .. ' is unavailable.'); return false
    end
    if log_failed then invalidate(); speak('Accessibility log unavailable. Restart the game.'); return false end
    send_click(node,label)
    return true
end
local function lord_selected_group(d)
    for index,group in ipairs(d.groups or {}) do if group.selected then return index,group end end
end
local function lord_back()
    local d=lord_discovery
    if screen_kind~='lord_discovery' or not d then return false end
    if d.kind=='load' then
        if lord_step=='saves' then lord_go('playthroughs',nil,'selected','Choose a campaign. ')
        else speak('This is the first step. Escape returns to the main menu.') end
        return true
    end
    if lord_flat then return false end
    if lord_step=='races' then speak('This is the first step. Escape returns to Select Campaign.')
    elseif lord_step=='lords' then lord_go('races',nil,'view:race:' .. tostring(lord_step_race),'Choose a race. ')
    elseif lord_step=='setup' then
        local index,group=lord_selected_group(d)
        if index then lord_go('lords',index,'selected',group.name .. '. ') else lord_go('races',nil,'selected','Choose a race. ') end
    elseif lord_step=='details' then lord_go('setup',nil,'view:details:details','Campaign setup. ')
    elseif lord_step=='options' then
        -- The list is open in the game: close it by clicking the combo box again.
        local field=lord_step_field
        local dd=d.dropdowns and d.dropdowns[field]
        if dd and lord_click(d,dd.path,dd.ids,field,'Close list') then
            lord_step,lord_focus,lord_step_prefix='setup','view:combo:' .. field,''
            lord_schedule_reread()
        elseif not dd then lord_go('setup',nil,'view:combo:' .. tostring(field),'') end
    end
    return true
end
local function lord_view_activate(item)
    local d=lord_discovery
    local kind=item.view_kind
    if kind=='race' then
        local group=d and d.groups and d.groups[item.race]
        if group then lord_go('lords',item.race,'selected',group.name .. '. ') end
    elseif kind=='summary' then lord_go('races',nil,'selected','Choose a race. ')
    elseif kind=='details' then lord_go('details',nil,1,'Lord and faction details. ')
    elseif kind=='back' then lord_back()
    elseif kind=='playthrough' then
        -- A campaign: its saves are the next step (clicked first when not selected).
        if item.row.state=='selected' then lord_go('saves',nil,'selected','Saves. ')
        elseif lord_click(d,item.row.path,item.row.ids,item.row.id,'Campaign ' .. item.view) then
            lord_step,lord_focus,lord_step_prefix='saves','selected','Saves. '
            lord_schedule_reread()
        end
    elseif kind=='save' then
        if item.row.invalid then cancel(); speak('This save cannot be loaded. ' .. (item.row.tooltip or '')); return end
        if item.row.state=='selected' then lord_go('saves',nil,'view:load_button:load','')
        elseif lord_click(d,item.row.path,item.row.ids,item.row.id,'Save ' .. item.view) then
            lord_step,lord_focus,lord_step_prefix='saves','view:load_button:load',item.view .. ' selected. '
            lord_schedule_reread()
        end
    elseif kind=='load_button' then
        local button=d.load and d.load.button_confirm_load
        if not button or button.state=='inactive' then cancel(); speak('Load is unavailable. Choose a save first.'); return end
        lord_click(d,button.path,button.ids,button.id,'Load')
    elseif kind=='incompatible' then cancel(); speak('Not supported yet.')
    elseif kind=='combo' then
        local dd=d and d.dropdowns and d.dropdowns[item.field]
        if not dd then cancel(); speak('Not supported yet.'); return end
        if lord_click(d,dd.path,dd.ids,item.field,item.view .. ' list') then
            lord_step,lord_step_field,lord_focus,lord_step_prefix='options',item.field,'selected',item.view .. ', list. '
            lord_schedule_reread()
        end
    elseif kind=='option' then
        -- The text may sit on a child of the clickable option: use the nearest
        -- interactive element, the text node or its parent.
        local node=item.node
        local path,ids,leaf=node.path,node.ids,node.id
        if not node.interactive and #path>1 then
            path,ids={},{}
            for part=1,#node.path-1 do path[part]=node.path[part] end
            for part=1,#node.ids-1 do ids[part]=node.ids[part] end
            leaf=node.ids[#node.ids]
        end
        local field=lord_step_field
        if lord_click(d,path,ids,leaf,item.view) then
            lord_step,lord_focus,lord_step_prefix='setup','view:combo:' .. tostring(field),''
            lord_schedule_reread()
        end
    end
end
local function lord_activate()
    local item,d=controls[control_index],lord_discovery
    if item.view_kind then lord_view_activate(item); return end
    local starting=item.start_campaign==true
    local prelude=item.prelude==true
    if not starting and not prelude and item.raw_state=='selected' then
        cancel()
        if lord_flat then speak(item.id .. ' is already selected.')
        else lord_go('setup',nil,'view:summary:summary',item.id .. ' is already selected. Campaign setup. ') end
        return
    end
    if not d or not d.done or d.limited then
        cancel(); speak(d and d.done and 'This screen could not be read completely, so choosing is unavailable.'
            or 'Still reading this screen. Press F2, then try again.'); return
    end
    local context=lord_context()
    if not context or d.generation~=generation or context.root_address~=d.root_address or context.panel_address~=d.panel_address then
        log('activation.lord_blocked', 'context'); invalidate(); speak('The screen changed. Press F2 and try again.'); return
    end
    local changed = lord_changed_field(context)
    if changed then log('activation.lord_blocked', 'stale:' .. changed); invalidate(); speak('The screen changed. Press F2 and try again.'); return end
    local leaf=starting and 'button_start_campaign' or item.id
    local node,reason=lord_resolve_checked(context.root,item.choice_path,item.choice_ids,leaf)
    if not node then invalidate(); log('activation.lord_unverified', reason); speak('The screen changed. Press F2 and try again.'); return end
    local interactive_ok,interactive=lord_read(function() local v=node:IsInteractive(); return v end)
    local state_ok,state=lord_read(function() local v=node:CurrentState(); return v end)
    local clickable=state=='active' or state=='hover' or (prelude and (state=='selected' or state=='selected_hover'))
    if not interactive_ok or interactive~=true or not state_ok or not clickable then
        log('activation.lord_blocked', 'state:' .. tostring(state)); invalidate(); speak('The screen changed. Press F2 and try again.'); return
    end
    -- Starting a campaign always asks first, like a confirmation dialog:
    -- press again within ten seconds to start; moving away cancels.
    if starting or confirm_activations then
        local now=clock_value()
        if pending and (now<pending.armed_at or now>pending.deadline) then
            cancel(); speak('Confirmation timed out. Press Enter again.'); return
        end
        if not pending then
            pending={target=item.key,armed_at=now,deadline=now+(starting and 10 or 4),fingerprint=leaf,generation=generation,origin=activation_origin}
            activation_outcome='armed'
            log('activation.armed',now)
            speak(starting and start_prompt() or prelude and ((item.label or 'Campaign introduction') .. '. Press again to confirm.')
                or ('Select ' .. item.id .. '. Press again to confirm.')); return
        end
        if pending.target~=item.key or pending.generation~=generation or pending.fingerprint~=leaf then
            invalidate(); speak('Cancelled: the selection changed.'); return
        end
    end
    if log_failed then invalidate(); speak('Accessibility log unavailable. Restart the game.'); return end
    if starting then
        send_click(node,'Start Campaign')
        return
    end
    if prelude then
        local was_checked=state=='selected' or state=='selected_hover'
        send_click(node,'Campaign introduction')
        lord_resume_key=item.key
        speak((item.label or 'Campaign introduction') .. ', ' .. (was_checked and 'not checked' or 'checked'))
        return
    end
    lord_awaiting=item.id
    send_click(node,'Lord choice: ' .. item.id)
    speak(item.id .. ' chosen.')
    if not lord_flat then
        -- Next decision: the campaign setup, read once the choice shows.
        lord_step,lord_focus,lord_step_prefix='setup','view:summary:summary','Campaign setup. '
        lord_schedule_reread()
    end
end

local function lifecycle(name)
    generation = generation + 1
    invalidate(); last_screen = nil
    log(name, generation)
end
core:add_ui_created_callback(function() quiet_state = nil; lifecycle('lifecycle.created'); if start_automation then start_automation() end end)
core:add_ui_destroyed_callback(function() lifecycle('lifecycle.destroyed'); publish_quiet('loading') end)
-- These observed campaign-named notifications are supplementary cancellation
-- hooks; the captured frontend layout check is required independently of them.
for _, event in ipairs({'PanelOpenedCampaign', 'PanelClosedCampaign'}) do
    local event_name = event
    core:add_listener('graphics_preview_' .. event_name, event_name, true,
        function() lifecycle(event_name) end, true)
end
-- Record a bounded sample of engine shortcut events independently of whether
-- our navigation filter accepts them. This distinguishes missing/remapped keys
-- from callback errors without guessing about NVDA or keyboard interception.
local shortcut_samples = 0
core:add_listener('graphics_preview_shortcut_trace', 'ShortcutTriggered', true,
    function(c)
        if shortcut_samples >= 64 then return end
        shortcut_samples = shortcut_samples + 1
        local shortcut
        local ok, err = pcall(function() shortcut = c.string end)
        if ok then log('shortcut.seen', type(shortcut) .. ':' .. tostring(shortcut))
        else log('shortcut.ERROR', err) end
    end, true)
-- Both real keyboard input and the opt-in driver call these exact handlers.
-- The driver never synthesizes or reports a ShortcutTriggered event.
local function navigate(shortcut, source)
    interaction_revision = interaction_revision + 1
    lord_reread_at = nil -- this key reads the screen itself
    log('navigation.source', source)
    log('navigation.received', shortcut)
    log('navigation.cached', type(captured) .. ':' .. tostring(captured))
    log('navigation.runs', type(runs) .. ':' .. tostring(runs))
    local ok, err = pcall(function()
        cancel()
        if (lord_discovery or not captured or screen_kind=='unknown') and lord_browse(shortcut=='script_F2' and 1 or -1) then return end
        if captured and not screen_still_current() then
            log('navigation.screen_changed', true); invalidate()
        end
        if not captured then browse_snapshot = capture('browse') end
        if shortcut == 'script_F2' then announce_control(1) else announce_control(-1) end
    end)
    -- These calls sit outside the pcall above; if a string call broke the
    -- runtime, report it here instead of failing the automation request.
    local reported = pcall(function()
        if not ok then
            invalidate(); log('navigation.ERROR', err)
            speak('Could not read this screen.')
        else log('navigation.COMPLETE', shortcut) end
    end)
    if not reported then plain_log('navigation.REPORT_FAILED', ok and 'after-success' or 'after-error') end
    nav_target = nil
    return ok
end
local function request_activation(source)
    interaction_revision = interaction_revision + 1
    lord_reread_at = nil
    activation_origin, activation_outcome = source, 'blocked'
    if lord_resume_key and #controls==0 then
        -- Enter straight after toggling: read the screen again quietly, back on the check box.
        quiet_announce=true; pcall(lord_browse,0); quiet_announce=false
    end
    local lord_mode=lord_discovery or screen_kind=='lord_discovery'
    if lord_mode then
        local item=controls[control_index]
        if not (item and (item.lord_choice or item.start_campaign or item.prelude or item.view_kind)) then
            cancel()
            local _, role = describe(item or {})
            if item and role and role ~= 'heading' then speak('Not supported yet.') end
            return true,'blocked'
        end
    end
    log('activation.source', source); log('activation.received', 'script_F4')
    if pending and pending.origin ~= source then
        cancel(); log('activation.confirmation_source_changed', source)
        speak('Cancelled.'); return false, 'blocked'
    end
    local ok, err = pcall(function() if lord_mode then lord_activate() else activate_control() end end)
    if not ok then
        local after_input = activation_outcome == 'input-sent'
        invalidate(); log('activation.ERROR', err)
        activation_outcome = after_input and 'error-after-input' or 'error'
        speak('Could not activate.')
    end
    return ok, activation_outcome
end
core:add_listener('graphics_preview_navigation', 'ShortcutTriggered',
    function(c)
        local shortcut = c.string
        return shortcut == 'script_F2' or shortcut == 'script_F3'
    end,
    function(c) navigate(c.string, 'keyboard') end, true)
core:add_listener('graphics_preview_activation', 'ShortcutTriggered',
    function(c) return c.string == 'script_F4' end,
    function() request_activation('keyboard') end, true)

-- Development-only local channel. No marker means no timer, request read or
-- native action. Never execute received text or accept arbitrary component IDs.
-- The shipped timer_manager requires a Timers global absent in the live WH2
-- frontend. Use real_timer single shots and the native RealTimeTrigger event.
local auto_base, auto_owner, auto_expiry, auto_timer
local auto_running, auto_seq, auto_result, auto_last_request, auto_last_status = false, 0, 'ready', nil, nil
local auto_name = 'warhammer_accessibility_automation'
local function automation_log(stage,value)
    -- Keep transport diagnostics independent of the original UI logger's
    -- tostring/sub formatting. Metadata is already bounded by this protocol.
    local text='non-string metadata'
    if type(value)=='string' then text=value end
    if log_path then append(log_path,stage .. '\tstring\t' .. text) end
end
local function read_small(path, limit)
    local data, file_kind
    local ok = pcall(function()
        local f = io.open(path,'r')
        file_kind=type(f)
        if not f then return nil end
        data = f:read(limit+1); f:close()
        if type(data) ~= 'string' or #data > limit then data=nil end
    end)
    if not auto_running and path==auto_base .. 'automation-enabled.tsv' then
        automation_log('automation.read_file_type',file_kind or 'unavailable')
        automation_log('automation.read_result',ok and 'success' or 'failure')
        automation_log('automation.read_data_type',type(data))
        if type(data)=='string' then automation_log('automation.read_length','bytes:' .. #data) end
    end
    return ok and data or nil
end
local function fields(line, count)
    if type(line) ~= 'string' then return nil,'not-string' end
    local stop = #line
    if string.byte(line,stop) ~= 10 then return nil,'missing-newline' end
    stop = stop-1
    if string.byte(line,stop) == 13 then stop=stop-1 end
    local values, position = {}, 1
    -- Parse bounded protocol bytes directly. Keep substring reads separate
    -- from delimiter detection and preserve empty fields for strict counting.
    for index=1,stop do
        local byte=string.byte(line,index)
        if byte==10 or byte==13 then return nil,'embedded-newline' end
        if byte==9 then
            local value=string.sub(line,position,index-1)
            values[#values+1]=value
            if #values>=count then return nil,'extra-fields' end
            position=index+1
        end
    end
    local value=string.sub(line,position,stop)
    values[#values+1]=value
    if #values ~= count then return nil,'field-count' end
    return values
end
local function integer(value)
    if type(value) ~= 'string' or #value==0 or #value > 10 then return nil end
    for index=1,#value do
        local byte=string.byte(value,index)
        if byte<48 or byte>57 then return nil end
    end
    local number=0
    for index=1,#value do
        number=number*10+string.byte(value,index)-48
        if number>16777215 then return nil end
    end
    return number
end
local function lease()
    local raw=read_small(auto_base .. 'automation-enabled.tsv',256)
    local value,reason = fields(raw,3)
    if not value then return nil,nil,'format:' .. (reason or 'unknown') end
    if value[1] ~= 'WH2LEASE1' or #value[2] ~= 32 then return nil,nil,'header-or-owner' end
    for index=1,32 do
        local byte=string.byte(value[2],index)
        if not ((byte>=48 and byte<=57) or (byte>=97 and byte<=102)) then return nil,nil,'header-or-owner' end
    end
    local expiry,now=value[3],unix_value()
    if not decimal_valid(expiry) or decimal_less(expiry,now) or decimal_less(decimal_add(now,1800),expiry) then return nil,nil,'expiry' end
    return value[2], expiry
end
local function publish_status()
    local item = controls[control_index]
    local label = item and clean(item.name) or '-'
    if #label > 800 then label = label:sub(1,800):gsub('[\192-\255][\128-\191]*$','') end
    local deadline='0'
    if pending then deadline=decimal_add(unix_value(),math.max(0,pending.deadline-clock_value())) end
    local values = {'WH2STATUS1','0.6.73-nvda-automation-preview',session,tostring(generation),
        tostring(interaction_revision),tostring(auto_seq),auto_result,screen_kind,
        item and item.key or '-',label,tostring(#controls),pending and pending.target or '-',
        deadline,core:is_ui_created() and '1' or '0',
        auto_running and '1' or '0',tostring(auto_expiry or 0)}
    local line = table.concat(values,'\t') .. '\n'
    if line == auto_last_status then return end
    local f = io.open(auto_base .. 'automation-status.tsv','w')
    if not f then error('Automation status unavailable') end
    local written = f:write(line)
    local closed = f:close()
    if not written or closed == nil then error('Automation status write failed') end
    auto_last_status = line
end
local function poll_automation()
    if not auto_running then return end
    -- Catch every exception: timer_manager retries callbacks that escape with
    -- an error. Requests are consumed BEFORE action, never retried after input.
    local ok, err = pcall(function()
        local owner, expiry = lease()
        if not owner or owner ~= auto_owner or expiry ~= auto_expiry then
            auto_running = false; cancel(); interaction_revision = interaction_revision+1
            auto_result = 'disabled'; auto_timer:remove_callback(auto_name); publish_status(); return
        end
        publish_status()
        local raw = read_small(auto_base .. 'automation-request.tsv',4096)
        if not raw or raw == auto_last_request then return end
        auto_last_request = raw
        local request = fields(raw,9)
        if not request or request[1] ~= 'WH2REQ1' then automation_log('automation.rejected','malformed'); return end
        if request[2] ~= auto_owner or request[3] ~= session then automation_log('automation.rejected','owner/session'); return end
        local number, wanted_generation, wanted_revision, expires = integer(request[4]), integer(request[5]), integer(request[6]), request[9]
        if not number or not wanted_generation or not wanted_revision or not decimal_valid(expires) then automation_log('automation.rejected','numbers'); return end
        if number <= auto_seq then return end -- duplicate/replay: retain the prior acknowledgement
        if number ~= auto_seq+1 then automation_log('automation.rejected','out-of-order'); return end
        auto_seq = number -- consumed before any validation or native side effect
        local action, selected, now = request[7], controls[control_index], unix_value()
        local reason
        if decimal_less(expires,now) or decimal_less(decimal_add(now,5),expires) then reason='expired'
        elseif wanted_generation ~= generation then reason='generation'
        elseif wanted_revision ~= interaction_revision then reason='revision'
        elseif request[8] ~= (selected and selected.key or '-') then reason='selection'
        elseif not core:is_frontend() or not core:is_ui_created() then reason='not-ready'
        elseif action ~= 'next' and action ~= 'previous' and action ~= 'activate' and action ~= 'discover' then reason='action' end
        if reason then
            cancel(); interaction_revision=interaction_revision+1; auto_result='rejected:' .. reason
            automation_log('automation.rejected',reason); publish_status(); return
        end
        automation_log('automation.accepted',tostring(number) .. ':' .. action)
        if action == 'next' or action == 'previous' then
            auto_result = navigate(action == 'next' and 'script_F2' or 'script_F3','automation') and 'completed' or 'error'
        elseif action=='discover' then interaction_revision=interaction_revision+1; cancel(); if lord_discovery and lord_discovery.done then invalidate() end; auto_result=lord_page(true)
        else local _, result = request_activation('automation'); auto_result=result end
        publish_status()
    end)
    if not ok then
        cancel(); interaction_revision=interaction_revision+1
        auto_result = activation_outcome == 'input-sent' and 'error-after-input' or 'error'
        pcall(function() automation_log('automation.ERROR',type(err)=='string' and err or ('error type: '..type(err))); publish_status() end)
    end
end
local function frontend_callbacks()
    local api=real_timer
    if not api or type(api.register_singleshot)~='function' or type(api.unregister)~='function' then
        error('Frontend real_timer unavailable')
    end
    local listener_name=auto_name .. '_real_timer'
    -- 0.6.65: one repeating timer when the game offers it (as the key timer):
    -- never register from inside the callback.
    local repeating=type(api.register_repeating)=='function'
    local adapter={active=false}
    function adapter:remove_callback()
        self.active=false
        api.unregister(auto_name)
        core:remove_listener(listener_name)
    end
    function adapter:repeat_callback(callback,interval,name)
        if name~=auto_name then error('Unexpected automation timer name') end
        self.active=true
        core:add_listener(listener_name,'RealTimeTrigger',
            function(context) return context.string==auto_name end,
            function()
                if not self.active then return end
                local ok,err=pcall(function()
                    callback()
                    if not repeating and self.active and auto_running then api.register_singleshot(auto_name,interval) end
                end)
                if not ok then
                    auto_running=false; cancel(); interaction_revision=interaction_revision+1
                    auto_result=activation_outcome=='input-sent' and 'error-after-input' or 'timer-error'
                    pcall(function() self:remove_callback() end)
                    pcall(function()
                        automation_log('automation.timer_error',type(err)=='string' and err or type(err))
                        publish_status()
                    end)
                end
            end,true)
        api.unregister(auto_name)
        if repeating then api.register_repeating(auto_name,interval) else api.register_singleshot(auto_name,interval) end
    end
    return adapter
end
start_automation = function()
    if auto_running then return end
    -- Reuse the directory that successfully opened the diagnostic. Do not
    -- depend on a second environment lookup in the game's restricted context.
    local suffix = 'native-ui-graphics-preview.log'
    if type(log_path) ~= 'string' or log_path:sub(-#suffix) ~= suffix then return end
    auto_base = log_path:sub(1,#log_path-#suffix)
    automation_log('automation.setup_check', auto_base == '' and 'relative-output-directory' or 'diagnostic-output-directory')
    local owner, expiry, reason
    local lease_ok = pcall(function() owner, expiry, reason = lease() end)
    if not lease_ok then automation_log('automation.setup_check','lease-exception'); return end
    if not owner then automation_log('automation.setup_check',type(reason)=='string' and reason or 'lease-unavailable'); return end
    local ok, err = pcall(function()
        if not core:is_frontend() then error('Frontend timer unavailable outside frontend') end
        automation_log('automation.real_timer_type',type(real_timer))
        auto_timer=frontend_callbacks()
        auto_owner,auto_expiry,auto_seq,auto_result = owner,expiry,0,'ready'
        auto_last_request,auto_last_status,auto_running=nil,nil,true
        auto_timer:repeat_callback(poll_automation,250,auto_name)
        automation_log('automation.enabled','lease active; native handlers; keyboard delivery untested')
        publish_status()
    end)
    if not ok then
        auto_running=false
        pcall(function() if auto_timer then auto_timer:remove_callback(auto_name) end end)
        pcall(function() automation_log('automation.setup_error',type(err)=='string' and err or ('error type: '..type(err))) end)
    end
end
local unguarded_automation_start = start_automation
start_automation = function()
    local function failed(err)
        local trace = 'optional automation initialization failed'
        if debug and type(debug.traceback)=='function' then
            local value = debug.traceback('automation startup',2)
            if type(value)=='string' then trace=value end
        end
        pcall(function() append(log_path,'automation.setup_trace\tstring\t' .. trace) end)
        return err
    end
    -- Optional development transport must never prevent the normal keyboard
    -- reader and startup speech from loading when initialization fails.
    local ok = xpcall(unguarded_automation_start,failed)
    if not ok then
        auto_running=false
        pcall(function() if auto_timer then auto_timer:remove_callback(auto_name) end end)
    end
end
-- Standard screen reader keys from the companion (arrows, Tab, Home/End,
-- Enter/Space, letters). They call the same handlers as F2/F3/F4. Events are
-- bound to this game session and UI generation; any backlog present when the
-- reader first sees a companion is skipped, never replayed. The companion only
-- sends keys while reader-state.tsv (rewritten here every second) is fresh.
local keys_name = 'warhammer_accessibility_keys'
local keys_base, keys_owner, keys_seq, keys_running, keys_ticks, keys_errors, keys_state = nil, nil, 0, false, 0, 0, nil
publish_reader_state = function(force)
    if not keys_base then return end
    local screen = quiet_state and 'loading' or screen_kind
    local line = 'WH2READER1\t' .. session .. '\t' .. generation .. '\t' .. (core:is_frontend() and '1' or '0') .. '\t' .. screen .. '\n'
    if not force and line == keys_state and keys_ticks % 10 ~= 0 then return end
    local f = io.open(keys_base .. 'reader-state.tsv', 'w')
    if not f then return end
    f:write(line); f:close(); keys_state = line
end
local ready_spoken = false
local function key_action(action)
    ready_spoken = true
    if action == 'back' then
        interaction_revision = interaction_revision + 1; cancel(); lord_reread_at = nil
        local ok, err = pcall(lord_back)
        if not ok then invalidate(); plain_log('keys.back_error', type(err) == 'string' and err or type(err)); speak('Could not read this screen.') end
        return
    end
    if action == 'next' then navigate('script_F2', 'keys')
    elseif action == 'previous' then navigate('script_F3', 'keys')
    elseif action == 'first' then nav_target = 'first'; navigate('script_F2', 'keys')
    elseif action == 'last' then nav_target = 'last'; navigate('script_F3', 'keys')
    elseif action == 'activate' then request_activation('keys')
    elseif #action == 8 and string.sub(action, 1, 7) == 'letter:' then
        local letter = string.sub(action, 8, 8)
        local byte = string.byte(letter)
        if byte and byte >= 97 and byte <= 122 then nav_target = {letter = letter}; navigate('script_F2', 'keys')
        else plain_log('keys.rejected', 'letter') end
    else plain_log('keys.rejected', 'action') end
end
local poll_key_events
-- 0.6.61: "ready" waits for the main menu. The intro movies stop the game's
-- timers (no ticks for the whole cinematic, seen live), while the menu ticks
-- about ten times a second. So the message is spoken after 15 ticks with no
-- gap of two seconds or more between them; a key press before then counts as
-- ready. Without the key timer it is spoken at load, as before.
local ready_ticks, ready_last = 0, nil
local function announce_ready()
    if ready_spoken then return end
    ready_spoken = true
    plain_log('startup.ready', 'ticks=' .. ready_ticks)
    speak('Warhammer accessibility 0.6.73 ready. Arrow keys move, Enter activates.')
end
local function ready_tick()
    if ready_spoken then return end
    local ok, clock = pcall(function() local v = os.date('!*t'); return v end)
    if ok and type(clock) == 'table' and type(clock.hour) == 'number' and type(clock.min) == 'number' and type(clock.sec) == 'number' then
        local now = clock.hour * 3600 + clock.min * 60 + clock.sec
        if ready_last and (now - ready_last > 1 or now < ready_last) then ready_ticks = 0 end
        ready_last = now
    end
    ready_ticks = ready_ticks + 1
    if ready_ticks >= 15 then announce_ready() end
end
local function lord_reread_tick()
    if not lord_reread_at then return end
    lord_reread_at = lord_reread_at - 1
    if lord_reread_at > 0 then return end
    lord_reread_at = nil
    interaction_revision = interaction_revision + 1; cancel()
    local ok, shown = pcall(lord_browse, 0)
    if not ok then plain_log('lord.reread_error', type(shown) == 'string' and shown or type(shown)); return end
    -- Not readable yet (the game still changing the screen): try again shortly.
    if not shown and lord_reread_left > 0 then lord_reread_left = lord_reread_left - 1; lord_reread_at = 3 end
end
local function poll_keys()
    keys_ticks = keys_ticks + 1
    ready_tick()
    lord_reread_tick()
    poll_key_events()
    publish_reader_state(false) -- after the events, so screen changes show at once
end
poll_key_events = function()
    local raw = read_small(keys_base .. 'keys.tsv', 4096)
    if not raw then return end
    local lines, start = {}, 1
    for index = 1, #raw do
        if string.byte(raw, index) == 10 then lines[#lines + 1] = string.sub(raw, start, index); start = index + 1 end
    end
    local header = fields(lines[1], 4)
    if not header or header[1] ~= 'WH2KEYS1' then return end
    local events, newest = {}, 0
    for index = 2, math.min(#lines, 33) do
        local event = fields(lines[index], 2)
        local number = event and integer(event[1])
        if number then events[#events + 1] = {seq = number, action = event[2]}; if number > newest then newest = number end end
    end
    if header[2] ~= keys_owner then
        keys_owner, keys_seq = header[2], newest
        plain_log('keys.owner', 'companion connected; earlier events skipped')
        return
    end
    if header[3] ~= session then
        if newest > keys_seq then keys_seq = newest; plain_log('keys.skipped', 'other session') end
        return
    end
    local stale = header[4] ~= tostring(generation)
    table.sort(events, function(a, b) return a.seq < b.seq end)
    local handled = 0
    for _, event in ipairs(events) do
        if event.seq > keys_seq and handled < 8 then
            keys_seq = event.seq -- consumed before acting; never replayed
            handled = handled + 1
            if stale and (event.action == 'activate' or event.action == 'back') then
                plain_log('keys.skipped', 'activation from the previous screen')
                speak('The screen changed. Press again.')
            else key_action(event.action) end
        end
    end
    if newest > keys_seq then keys_seq = newest; plain_log('keys.skipped', 'more than eight pending') end
end
local function start_keys()
    if keys_running then publish_reader_state(true); return end
    local suffix = 'native-ui-graphics-preview.log'
    if type(log_path) ~= 'string' or string.sub(log_path, -#suffix) ~= suffix or not core:is_frontend() then return end
    local api = real_timer
    if not api or type(api.register_singleshot) ~= 'function' or type(api.unregister) ~= 'function' then
        plain_log('keys.setup', 'real_timer unavailable'); return
    end
    keys_base = string.sub(log_path, 1, #log_path - #suffix)
    keys_running = true
    -- 0.6.64: one repeating timer, registered once here. Registering the next
    -- single shot inside the callback (as before) can wipe the game's timer
    -- list while it dispatches timers: seen live when a difficulty list opened
    -- (the reader went silent for good), as with the campaign reader in 0.6.58.
    -- Single shots remain only where the game offers no repeating timer.
    local repeating = type(api.register_repeating) == 'function'
    core:add_listener(keys_name .. '_real_timer', 'RealTimeTrigger',
        function(context) return context.string == keys_name end,
        function()
            if not keys_running then return end
            if quiet_state == 'movies' then quiet_state = nil end
            local ok, err = pcall(poll_keys)
            if ok then keys_errors = 0 else
                keys_errors = keys_errors + 1
                if keys_errors <= 3 then plain_log('keys.ERROR', type(err) == 'string' and err or type(err)) end
                if keys_errors >= 20 then
                    keys_running = false; plain_log('keys.disabled', 'repeated errors')
                    if repeating then pcall(function() api.unregister(keys_name) end) end
                    return
                end
            end
            if not repeating then pcall(function() api.register_singleshot(keys_name, 100) end) end
        end, true)
    api.unregister(keys_name)
    if repeating then api.register_repeating(keys_name, 100) else api.register_singleshot(keys_name, 100) end
    publish_reader_state(true)
    plain_log('keys.enabled', repeating and 'companion key channel, repeating timer' or 'companion key channel, single-shot timer')
end
local function start_keys_guarded()
    local ok, err = pcall(start_keys)
    if not ok then keys_running = false; pcall(function() plain_log('keys.setup_error', type(err) == 'string' and err or type(err)) end) end
end
core:add_listener('graphics_preview_automation_init','FrontendScreenTransition',true,
    function() if start_automation then start_automation() end; start_keys_guarded() end,true)
start_automation()
start_keys_guarded()
if not keys_running then announce_ready()
else
    -- 0.6.64: the script loads during the splash, just before the intro
    -- movies; only at game start (about 25 s after launch, seen live), not when
    -- the menu reloads after a campaign. "ready" follows when the menu is up.
    local ok, seconds = pcall(function() local v = os.clock(); return v end)
    if ok and type(seconds) == 'number' and seconds == seconds and seconds >= 0 and seconds < 90 then
        plain_log('startup.movies', tostring(seconds))
        speak('Intro movies playing. Press Escape to skip them.')
        publish_quiet('movies')
    end
end

