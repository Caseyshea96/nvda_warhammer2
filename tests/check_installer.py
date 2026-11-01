"""Exercise the shipped PS installer against temporary game/library fixtures.

Runs on Windows or Linux PowerShell: does not validate Windows ACLs, COM, shortcut creation,
WinForms, Steam launch, or NVDA. Those remain explicit runtime tests.
"""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import zipfile
import argparse

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--package', type=Path)
args = parser.parse_args()
if not args.package:
    raise SystemExit('Pass --package artifacts/warhammer2-windows-<version>.zip')
archive_path = args.package
with tempfile.TemporaryDirectory(prefix='installer-test-', dir=root / 'local') as tmp:
    folder = Path(tmp)
    with zipfile.ZipFile(archive_path) as z:
        z.extractall(folder / 'package')
    package = folder / 'package' / archive_path.stem
    manifest = json.loads((package / 'manifest.json').read_text())
    game = folder / 'Steam Library/steamapps/common/Total War WARHAMMER II'
    (game / 'data').mkdir(parents=True)
    (game / 'Warhammer2.exe').touch()
    (game / 'data/unrelated.pack').write_bytes(b'preserve this')
    (game / 'save.txt').write_text('preserve save')
    appdata = folder / 'User AppData'
    appdata.mkdir()
    base = appdata / 'WarhammerAccess'
    app = base / 'App'
    env = os.environ.copy()
    if os.name == 'nt':
        # Let Windows PowerShell construct its own module path, rather than inherit PowerShell 7's.
        for key in list(env):
            if key.upper() == 'PSMODULEPATH':
                del env[key]
    env['LOCALAPPDATA'] = str(appdata)
    env.pop('OS', None)  # Desktop COM is separately Windows-only.

    def run(script, *args, success=True):
        shell = (['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass'] if os.name == 'nt'
                 else ['bash', str(root / 'tools/pwsh-test.sh')])
        result = subprocess.run([*shell, '-File', str(script), *args],
                                env=env, cwd=root, capture_output=True, text=True)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return result

    def install(success=True):
        return run(package / 'Install.ps1', '-GamePath', str(game), '-NoShortcut', success=success)

    # Invalid path is rejected before any game pack copy.
    run(package / 'Install.ps1', '-GamePath', str(folder), '-NoShortcut', success=False)
    # Existing distinct pack cannot be overwritten.
    target = game / 'data/warhammer_access.pack'
    target.write_bytes(b'unknown mod')
    install(success=False)
    assert target.read_bytes() == b'unknown mod'
    target.unlink()
    # 0.6.65: an install under the earlier names (up to 0.6.64) is moved over:
    # its pack and recorded files go, flags are copied, logs stay.
    old_base = appdata / 'JawsWarhammer2'  # names before 0.6.65
    old_app = old_base / 'App'
    old_pack = game / 'data' / 'jaws_access.pack'
    def old_install(pack_bytes=b'old pack', receipt_game=None):
        old_app.mkdir(parents=True, exist_ok=True)
        old_pack.write_bytes(pack_bytes)
        (old_app / 'Companion.ps1').write_bytes(b'# old companion')
        (old_app / 'user-note.txt').write_text('keep me')
        (old_app / 'manifest.json').write_text(json.dumps({'version': '0.6.64-nvda-automation-preview',
            'files': {'Companion.ps1': hashlib.sha256(b'# old companion').hexdigest()}}))
        (old_base / 'receipt.json').write_text(json.dumps({'version': '0.6.64-nvda-automation-preview',
            'game_path': receipt_game or str(game), 'pack_sha256': hashlib.sha256(b'old pack').hexdigest(),
            'app_path': str(old_app)}))
        (old_base / 'lord-list-flat.flag').write_text('')
        (old_base / 'native-ui-graphics-preview.log').write_text('old log')
    # A changed old pack is refused and nothing is installed.
    old_install(pack_bytes=b'changed old pack')
    install(success=False)
    assert old_pack.read_bytes() == b'changed old pack' and not target.exists()
    # A receipt for another game folder does not vouch for the old pack.
    old_install(receipt_game=str(folder))
    install(success=False)
    assert old_pack.exists() and not target.exists()
    old_install()
    moved = install()
    assert 'Upgraded from version 0.6.64 to ' + manifest['version'].split('-')[0] in moved.stdout, moved.stdout
    assert not old_pack.exists(), 'Old pack removed'
    assert not (old_app / 'Companion.ps1').exists() and not (old_app / 'manifest.json').exists()
    assert (old_app / 'user-note.txt').read_text() == 'keep me', 'Unrecorded files are kept'
    assert not (old_base / 'receipt.json').exists()
    assert (old_base / 'native-ui-graphics-preview.log').read_text() == 'old log', 'Old logs stay'
    assert (base / 'lord-list-flat.flag').exists(), 'Option flags are copied'
    assert (game / 'data/unrelated.pack').read_bytes() == b'preserve this'
    # An old pack with no receipt (copied by hand) is refused.
    old_pack.write_bytes(b'hand copied')
    install(success=False)
    assert old_pack.read_bytes() == b'hand copied'
    old_pack.unlink()
    assert hashlib.sha256(target.read_bytes()).hexdigest() == manifest['files']['warhammer_access.pack']
    assert Path(json.loads((app / 'config.json').read_text(encoding='utf-8-sig'))['game_path']) == game
    assert (app / 'Start Pilot.cmd').exists()
    # Every runtime payload must actually be copied, not merely present in the ZIP.
    for name, digest in manifest['files'].items():
        if name in ('warhammer_access.pack', 'Install.ps1', 'Install.cmd'):
            continue
        assert (app / name).is_file(), f'Missing installed runtime payload: {name}'
        assert hashlib.sha256((app / name).read_bytes()).hexdigest() == digest
    install()  # Idempotent same-version install.
    # Upgrade over an earlier version this installer put there (trial run 2:
    # the friend's 0.6.62 install refused to replace 0.6.59 and the old build
    # kept running). Fake an older install: different pack and companion,
    # recorded in the receipt and the installed manifest.
    receipt_path = base / 'receipt.json'
    installed_manifest_path = app / 'manifest.json'
    new_pack = target.read_bytes()
    companion = app / 'Companion.ps1'
    new_companion = companion.read_bytes()

    def fake_older(pack_game=None, companion_bytes=b'# older companion\n', record_companion=True):
        target.write_bytes(b'older pack build')
        companion.write_bytes(companion_bytes)
        receipt = json.loads(receipt_path.read_text(encoding='utf-8-sig'))
        receipt['version'] = '0.6.59-nvda-automation-preview'
        receipt['pack_sha256'] = hashlib.sha256(b'older pack build').hexdigest()
        receipt['game_path'] = pack_game or str(game)
        receipt_path.write_text(json.dumps(receipt), encoding='utf-8')
        old_manifest = json.loads(installed_manifest_path.read_text(encoding='utf-8-sig'))
        old_manifest['version'] = '0.6.59-nvda-automation-preview'
        if record_companion:
            old_manifest['files']['Companion.ps1'] = hashlib.sha256(companion_bytes).hexdigest()
        installed_manifest_path.write_text(json.dumps(old_manifest), encoding='utf-8')

    fake_older()
    upgraded = install()
    assert target.read_bytes() == new_pack and companion.read_bytes() == new_companion
    assert 'Upgraded from version 0.6.59 to ' + manifest['version'].split('-')[0] in upgraded.stdout, upgraded.stdout
    assert not (game / 'data/warhammer_access.pack.new').exists()
    assert json.loads(receipt_path.read_text(encoding='utf-8-sig'))['version'] == manifest['version']
    assert (game / 'data/unrelated.pack').read_bytes() == b'preserve this'
    # A receipt for another game folder does not vouch for this pack.
    fake_older(pack_game=str(folder))
    install(success=False)
    assert target.read_bytes() == b'older pack build'
    # An older companion changed by hand (not the recorded hash) is kept, and so is the old pack.
    fake_older(record_companion=False, companion_bytes=b'# hand-edited\n')
    install(success=False)
    assert companion.read_bytes() == b'# hand-edited\n' and target.read_bytes() == b'older pack build'
    # Restore the current install for the remaining checks.
    fake_older()
    install()
    assert target.read_bytes() == new_pack and companion.read_bytes() == new_companion
    # A modified companion is preserved rather than silently overwritten.
    companion = app / 'Companion.ps1'
    original = companion.read_bytes()
    companion.write_bytes(original + b'\n# custom\n')
    install(success=False)
    assert companion.read_bytes().endswith(b'# custom\n')
    companion.write_bytes(original)
    # Package tampering must fail before installation.
    packaged = package / 'Bridge.cs'
    original = packaged.read_bytes()
    packaged.write_bytes(b'corrupt')
    install(success=False)
    packaged.write_bytes(original)
    if manifest.get('automation_protocol') == 1:
        automation = package / 'Automation.ps1'
        original = automation.read_bytes()
        automation.write_bytes(b'corrupt automation helper')
        install(success=False)
        automation.write_bytes(original)
    # One-step update: the installed Update.ps1 finds the newest ZIP in a
    # folder, unpacks it and runs its installer (no extracting by hand).
    downloads = folder / 'Downloads'
    downloads.mkdir()
    def update(*extra, success=True):
        return run(app / 'Update.ps1', '-Offline', '-Folder', str(downloads), '-GamePath', str(game), '-NoShortcut', *extra, success=success)
    missing = update(success=False)
    assert 'No update found' in missing.stdout, missing.stdout
    shutil.copy(archive_path, downloads / archive_path.name)
    (downloads / 'warhammer2-windows-0.1.0-nvda-automation-preview.zip').write_bytes(b'older, never chosen')
    (downloads / 'warhammer2-windows-notes.zip').write_bytes(b'not a version')
    current = update()
    assert 'Nothing to update' in current.stdout, current.stdout
    fake_older()
    updated = update()
    version = manifest['version'].split('-')[0]
    assert 'Updating from version 0.6.59 to ' + version in updated.stdout, updated.stdout
    assert 'Upgraded from version 0.6.59 to ' + version in updated.stdout, updated.stdout
    assert target.read_bytes() == new_pack and companion.read_bytes() == new_companion
    assert (app / 'Update.ps1').exists() and (app / 'Update.cmd').exists()
    # Update from the latest GitHub release (a local stand-in for the API):
    # download, checksum check, install; falls back to a saved ZIP offline.
    import http.server, threading
    zip_bytes = archive_path.read_bytes()
    published = {'zip': zip_bytes, 'sha': (hashlib.sha256(zip_bytes).hexdigest() + '  ' + archive_path.name + '\n').encode(), 'release': True}
    class FakeGitHub(http.server.BaseHTTPRequestHandler):
        def log_message(self, *a): pass
        def do_GET(self):
            port = self.server.server_address[1]
            if self.path == '/repos/test/mod/releases/latest':
                if not published['release']:
                    self.send_response(404); self.end_headers(); return
                body = json.dumps({'tag_name': 'v' + manifest['version'].split('-')[0], 'assets': [
                    {'name': archive_path.name, 'browser_download_url': f'http://127.0.0.1:{port}/dl/zip'},
                    {'name': archive_path.name + '.sha256', 'browser_download_url': f'http://127.0.0.1:{port}/dl/sha'},
                    {'name': 'notes.txt', 'browser_download_url': f'http://127.0.0.1:{port}/dl/none'}]}).encode()
            elif self.path == '/dl/zip': body = published['zip']
            elif self.path == '/dl/sha': body = published['sha']
            else:
                self.send_response(404); self.end_headers(); return
            self.send_response(200); self.send_header('Content-Length', str(len(body))); self.end_headers(); self.wfile.write(body)
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), FakeGitHub)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    api = f'http://127.0.0.1:{server.server_address[1]}'
    def online(*extra, success=True, api_base=None):
        return run(app / 'Update.ps1', '-ApiBase', api_base or api, '-Repository', 'test/mod', '-Folder', str(folder / 'empty'),
                   '-GamePath', str(game), '-NoShortcut', *extra, success=success)
    (folder / 'empty').mkdir()
    try:
        current = online()
        assert 'Nothing to update' in current.stdout and 'newest release' in current.stdout, current.stdout
        fake_older()
        published['sha'] = b'0' * 64 + b'  wrong\n'
        tampered = online(success=False)
        assert 'does not match its checksum' in tampered.stdout and target.read_bytes() == b'older pack build', tampered.stdout
        published['sha'] = (hashlib.sha256(zip_bytes).hexdigest() + '  ' + archive_path.name + '\n').encode()
        pulled = online()
        assert 'Downloading version ' + version in pulled.stdout, pulled.stdout
        assert 'Upgraded from version 0.6.59 to ' + version in pulled.stdout, pulled.stdout
        assert target.read_bytes() == new_pack and companion.read_bytes() == new_companion
        # No release yet: says so, then uses a saved ZIP.
        published['release'] = False
        fake_older()
        none_yet = run(app / 'Update.ps1', '-ApiBase', api, '-Repository', 'test/mod', '-Folder', str(downloads),
                       '-GamePath', str(game), '-NoShortcut')
        assert 'No release on GitHub yet' in none_yet.stdout and 'Upgraded from version 0.6.59' in none_yet.stdout, none_yet.stdout
    finally:
        server.shutdown()
    # GitHub unreachable: falls back to a saved ZIP.
    fake_older()
    offline = run(app / 'Update.ps1', '-ApiBase', api, '-Repository', 'test/mod', '-Folder', str(downloads),
                  '-GamePath', str(game), '-NoShortcut')
    assert 'Could not reach GitHub' in offline.stdout and 'Upgraded from version 0.6.59' in offline.stdout, offline.stdout
    assert target.read_bytes() == new_pack
    # Installing while the helper runs: the installer closes it (Windows only).
    if os.name == 'nt':
        helper = subprocess.Popen(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(app / 'Companion.ps1'), '-Console'],
                                  env=env, cwd=root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            import time
            time.sleep(4)
            assert helper.poll() is None, 'Helper did not start'
            closed = install()
            assert 'Closing the accessibility helper.' in closed.stdout, closed.stdout
            helper.wait(timeout=10)
        finally:
            if helper.poll() is None:
                helper.kill()
    # Uninstaller must not delete a changed pack.
    original_pack = target.read_bytes()
    target.write_bytes(b'changed')
    run(app / 'Uninstall.ps1', success=False)
    assert target.read_bytes() == b'changed'
    target.write_bytes(original_pack)
    (base / 'companion.log').write_text('preserve diagnostics')
    run(app / 'Uninstall.ps1')
    assert not target.exists() and not app.exists()
    assert (game / 'data/unrelated.pack').read_bytes() == b'preserve this'
    assert (game / 'save.txt').read_text() == 'preserve save'
    assert (base / 'companion.log').read_text() == 'preserve diagnostics'
    install()  # Fresh install after removal.
    run(app / 'Uninstall.ps1')
    if manifest.get('automation_protocol') == 1:
        install()
        automation = app / 'Automation.ps1'
        modified = automation.read_bytes() + b'\n# user modification\n'
        automation.write_bytes(modified)
        run(app / 'Uninstall.ps1')
        assert automation.read_bytes() == modified, 'Changed automation helper must be preserved'
        assert (game / 'save.txt').read_text() == 'preserve save'
print('PASS: shipped ZIP install, non-default path with spaces, idempotence, upgrade over an earlier install, one-step update from the latest GitHub release (checksum checked) or a downloaded ZIP, closing a running helper, move from the earlier names, mismatch refusal, tamper detection, uninstall and preservation')
