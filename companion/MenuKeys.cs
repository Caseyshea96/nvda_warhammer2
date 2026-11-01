using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace WarhammerAccessibility {
    public sealed class MenuKeyArgs : EventArgs {
        public readonly string Action;
        public MenuKeyArgs(string action) { Action = action; }
    }

    // Standard screen reader navigation keys for the game's menus: arrows and
    // Tab move, Home/End jump, Enter/Space activate, letters jump to items.
    // Registered only while the game window is focused and the mod reports a
    // menu screen; released otherwise so the game and other programs keep them.
    // Escape is never taken: it stays the game's own Back key.
    public sealed class MenuKeys : NativeWindow, IDisposable {
        [DllImport("user32.dll")] private static extern bool RegisterHotKey(IntPtr h, int id, uint mods, uint key);
        [DllImport("user32.dll")] private static extern bool UnregisterHotKey(IntPtr h, int id);
        [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
        private const uint NoRepeat = 0x4000;
        private sealed class Binding { public uint Mods; public uint Key; public string Action; }
        private readonly Dictionary<int, Binding> bindings = new Dictionary<int, Binding>();
        private readonly HashSet<int> owned = new HashSet<int>();
        private bool disposed;
        public event EventHandler<MenuKeyArgs> Pressed;

        public MenuKeys() {
            CreateHandle(new CreateParams());
            // Arrows and Tab repeat when held, like any list; activation and
            // letters never repeat, so a held Enter cannot activate twice.
            // Shift+Tab is left alone: it is Steam's overlay shortcut.
            Bind(0x28, 0, "next"); Bind(0x26, 0, "previous");
            Bind(0x09, 0, "next");
            Bind(0x24, NoRepeat, "first"); Bind(0x23, NoRepeat, "last");
            Bind(0x0D, NoRepeat, "activate"); Bind(0x20, NoRepeat, "activate");
            // Backspace: back one step in a sequence of choices (Select Lord).
            Bind(0x08, NoRepeat, "back");
            for (uint letter = 0x41; letter <= 0x5A; letter++)
                Bind(letter, NoRepeat, "letter:" + (char)(letter + 32));
        }
        private void Bind(uint key, uint mods, string action) {
            bindings.Add(0x5000 + bindings.Count, new Binding { Mods = mods, Key = key, Action = action });
        }

        public static bool GameFocused() {
            uint pid; GetWindowThreadProcessId(GetForegroundWindow(), out pid);
            try { return Process.GetProcessById((int)pid).ProcessName.Equals("Warhammer2", StringComparison.OrdinalIgnoreCase); }
            catch { return false; }
        }

        // Returns how many keys failed to register or release (0 when all went well).
        public int SetActive(bool active) {
            if (disposed) return 0;
            int failures = 0;
            if (active && GameFocused()) {
                foreach (var pair in bindings) {
                    if (owned.Contains(pair.Key)) continue;
                    if (RegisterHotKey(Handle, pair.Key, pair.Value.Mods, pair.Value.Key)) owned.Add(pair.Key); else failures++;
                }
            } else {
                foreach (int id in new List<int>(owned)) {
                    if (UnregisterHotKey(Handle, id)) owned.Remove(id); else failures++;
                }
            }
            return failures;
        }
        public bool Active { get { return owned.Count > 0; } }

        protected override void WndProc(ref Message m) {
            if (m.Msg == 0x0312) {
                int id = m.WParam.ToInt32();
                Binding binding;
                if (owned.Contains(id) && bindings.TryGetValue(id, out binding) && GameFocused() && Pressed != null)
                    Pressed(this, new MenuKeyArgs(binding.Action));
            }
            base.WndProc(ref m);
        }
        public void Dispose() { SetActive(false); disposed = true; DestroyHandle(); }
    }
}
