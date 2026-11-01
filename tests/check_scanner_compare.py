"""Validate the Windows read-only comparison with the bundled Lua 5.1 DLL."""
from pathlib import Path
import ctypes
import os
root = Path(__file__).resolve().parents[1]
os.chdir(root)
base = (root / 'diagnostics/native_ui_diagnostic.lua').read_text(encoding='utf-8')
source = (root / 'diagnostics/scanner_compare.lua').read_text(encoding='utf-8')
def tree(text):
    return text[text.index('local function capture_tree('):text.index('local function capture(source)')]
assert tree(base) == tree(source), 'Comparison must preserve the proven traversal exactly'
assert 'SimulateLClick' not in source and 'trigger_shortcut' not in source
assert "c.string == 'script_F2' or c.string == 'script_F3'" in source
lua = ctypes.CDLL(str(root / 'local/tools/lua-5.1.5-windows/lua5.1.dll'))
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]
for filename, execute in [('diagnostics/scanner_compare.lua', False), ('tests/scanner_compare_harness.lua', True)]:
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
print('PASS: Lua syntax, exact baseline traversal preservation and F2/F3-only source')
