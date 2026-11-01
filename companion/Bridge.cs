using System;
using System.IO;
using System.Text;
using System.Collections.Generic;

namespace WarhammerAccessibility {
    // Binary incremental tail: UTF-8 characters and records may span writes.
    public sealed class Tail {
        public readonly string Path;
        private long offset;
        private string header;
        private readonly List<byte> pending = new List<byte>();
        private bool discardLine;
        public int OversizedRecords { get; private set; }
        public int InvalidUtf8Records { get; private set; }
        public Tail(string path, bool skipExisting) {
            Path = path;
            if (File.Exists(path) && skipExisting) {
                using (var f = Open()) { header = Header(f); offset = f.Length; }
            }
        }
        private FileStream Open() {
            return new FileStream(Path, FileMode.Open, FileAccess.Read,
                FileShare.ReadWrite | FileShare.Delete);
        }
        private static string Header(FileStream f) {
            f.Position = 0;
            var b = new List<byte>();
            for (int i = 0; i < 32768; i++) {
                int c = f.ReadByte();
                if (c < 0) return null;
                if (c == 10) return Convert.ToBase64String(b.ToArray());
                b.Add((byte)c);
            }
            return "oversized";
        }
        public string[] Poll() {
            var records = new List<string>();
            if (!File.Exists(Path)) { offset = 0; header = null; pending.Clear(); discardLine = false; return records.ToArray(); }
            using (var f = Open()) {
                string now = Header(f);
                if (f.Length < offset || (header != null && now != null && header != now)) {
                    offset = 0; pending.Clear(); discardLine = false;
                }
                if (now != null) header = now;
                f.Position = offset;
                var buffer = new byte[65536];
                int count = f.Read(buffer, 0, buffer.Length);
                offset += count;
                for (int i = 0; i < count; i++) {
                    byte b = buffer[i];
                    if (b == 10) {
                        if (!discardLine) {
                            try { records.Add(new UTF8Encoding(false, true).GetString(pending.ToArray()).TrimEnd('\r')); }
                            catch (DecoderFallbackException) { InvalidUtf8Records++; }
                        }
                        pending.Clear(); discardLine = false;
                    } else if (!discardLine) {
                        pending.Add(b);
                        if (pending.Count > 32768) { pending.Clear(); discardLine = true; OversizedRecords++; }
                    }
                }
            }
            return records.ToArray();
        }
    }
}
