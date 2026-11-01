local files, listeners, created, destroyed = {}, {}
local ready, bad = true, false
local n, button = {}, {}
function n:Id() return "root" end
function n:ChildCount() if bad then return function() end end; return 1 end
function n:Find(i) assert(i == 0); return button end
function n:Visible() return true end
function n:IsInteractive() error("unsupported test method") end
function n:GetStateText() return "Menu" end
function n:GetTooltipText() return "Tooltip" end
function n:CurrentState() return "active" end
function n:Address() return newproxy() end
function button:Id() return "button_new_campaign" end
function button:ChildCount() return 0 end
function button:Visible() return true end
function button:IsInteractive() return true end
function button:GetStateText() return "Keyboard choice" end
function button:GetTooltipText() return "" end
function button:CurrentState() return "active" end
function button:Address() return newproxy() end
core = {
 is_campaign=function() return false end, is_battle=function() return false end,
 is_ui_created=function() return ready end,
 get_ui_root=function() assert(ready); return n end,
 add_ui_created_callback=function(_,fn) created=fn end,
 add_ui_destroyed_callback=function(_,fn) destroyed=fn end,
 add_listener=function(_,name,event,cond,fn) listeners[event]={cond,fn} end
}
UIComponent=function(v) return v end
io={open=function(path,mode)
 if mode=="w" then files[path]="" end
 return {write=function(_,text) files[path]=(files[path] or "")..text; return true end,close=function() return true end}
end}
effect={trigger_shortcut=function() error("Diagnostic must not send input") end}
function n:SimulateLClick() error("Diagnostic must not click") end
dofile("diagnostics/native_ui_diagnostic.lua")
local function fire(event,c) local l=listeners[event]; if l and l[1](c) then l[2](c) end end
created()
fire("ShortcutTriggered",{string="script_F4"})
fire("ShortcutTriggered",{string="script_F2"})
for i=1,10 do fire("ShortcutTriggered",{string="script_F2"}) end -- repeat is ignored
ready=false; destroyed()
local text
for path,contents in pairs(files) do if path:find("native%-ui%-diagnostic.log") then text=contents end end
assert(text:find("tree.child0.Id.RESULT"))
assert(text:find("tree.child0.GetTooltipText.RESULT"))
local first_child = assert(text:find("tree.child0.Find.START", 1, true))
local root_classify = assert(text:find("tree.classify.START", 1, true))
assert(first_child < root_classify) -- classification cannot block child traversal
assert(text:find("root.IsInteractive.ERROR"))
assert(text:find("root.Address.RESULT\tuserdata"))
assert(text:find("tree.nodes\tnumber\t2", 1, true))
assert(text:find("tree.controls\tnumber\t1", 1, true))
assert(not text:find("capture.ERROR"))
local _,count=text:gsub("capture.COMPLETE","")
assert(count==1, count)
local bridge_text = ''
for path,contents in pairs(files) do if path:find('jsonl') then bridge_text=bridge_text..contents end end
assert(bridge_text:find('Controls, 1 of 1: Keyboard choice'))
local original_core = core
core = {is_campaign=function() return true end, is_battle=function() return false end}
local previous = text
dofile("diagnostics/native_ui_diagnostic.lua")
for path,contents in pairs(files) do if path:find("native%-ui%-diagnostic.log") then assert(contents==previous) end end
core = original_core
print("PASS: read-only F2/F3 browser, one-shot bounded tree, labels, lifecycle, opaque addresses and per-method errors")
