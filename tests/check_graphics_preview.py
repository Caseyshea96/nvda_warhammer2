"""Validate the Windows Graphics-only preview with the bundled Lua 5.1 DLL."""
from pathlib import Path
import ctypes
import os
root = Path(__file__).resolve().parents[1]
os.chdir(root)
base = (root / 'diagnostics/native_ui_diagnostic.lua').read_text(encoding='utf-8')
source = (root / 'diagnostics/graphics_preview.lua').read_text(encoding='utf-8')
def tree(text):
    return text[text.index('local function capture_tree('):text.index('local function capture(source)')]
annotated_tree = tree(source).replace('key = label, ', '').replace('    snapshot_node_count = visited\n', '').replace('else scan_valid = false; log(', 'else log(')
assert tree(base) == annotated_tree, 'Only metadata annotations may differ from the proven traversal'
logger = source[source.index('local function log(stage, value)'):source.index('local function speak(text)')]
assert 'scan_active' not in logger and 'classifying' not in logger
assert logger == base[base.index('local function log(stage, value)'):base.index('local function speak(text)')], 'Logger must match the proven diagnostic exactly'
assert source.count('node:SimulateLClick()') == 1 and 'trigger_shortcut' not in source
assert "shortcut == 'script_F2' or shortcut == 'script_F3'" in source
assert "function(c) return c.string == 'script_F4' end" in source
lua = ctypes.CDLL(str(root / 'local/tools/lua-5.1.5-windows/lua5.1.dll'))
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]
campaign_source = (root / 'diagnostics/campaign_readonly.lua').read_text(encoding='utf-8')
# HUD reading mode (owner-approved toggle, 0.6.34) shares reader-state.tsv and keys.tsv with the menu keys.
# Owner-approved HUD buttons (0.6.38): exactly one native click call site.
assert campaign_source.count('SimulateLClick') == 1, 'Campaign module needs exactly one click call site'
# 0.6.67 (owner, Nov 1): lords, settlements and moves read the model and give
# move orders only through campaign_game(); the HUD reader itself never does.
for forbidden in ['string.find', ':find(', 'trigger_shortcut', 'cm:']:
    assert forbidden not in campaign_source, f'Campaign discovery cannot use {forbidden}'
for filename, execute in [('diagnostics/graphics_preview.lua', False), ('tests/graphics_preview_harness.lua', True),
                          ('diagnostics/campaign_readonly.lua', False), ('tests/campaign_readonly_harness.lua', True)]:
    state = lua.luaL_newstate()
    assert state
    try:
        lua.luaL_openlibs(state)
        rc = lua.luaL_loadfile(state, filename.encode('utf-8'))
        if rc == 0 and execute:
            rc = lua.lua_pcall(state, 0, 0, 0)
        if rc:
            raise RuntimeError(lua.lua_tolstring(state, -1, None).decode('utf-8', errors='replace'))
    finally:
        lua.lua_close(state)
print('PASS: Lua syntax, baseline traversal with metadata annotations, isolated logger and single native activation call site')
