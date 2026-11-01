"""Exercise the shipped PS installer against temporary game/library fixtures.

Runs on Windows or Linux PowerShell: does not validate Windows ACLs, COM, shortcut creation,
WinForms, Steam launch, or JAWS. Those remain explicit pilot runtime tests.
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
archive_path = args.package or root / ('artifacts/jaws-coop-pilot-windows-' + os.environ.get('PILOT_TEST_VERSION', '0.2.5-dev') + '.zip')
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
    base = appdata / 'JawsWarhammer2'
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
    target = game / 'data/jaws_access.pack'
    target.write_bytes(b'unknown mod')
    install(success=False)
    assert target.read_bytes() == b'unknown mod'
    target.unlink()
    # The known diagnostic is backed up and removed to prevent duplicate keys.
    old = game / 'data/jaws_probe.pack'
    shutil.copyfile(root / 'artifacts/jaws_probe.pack', old)
    install()
    assert not old.exists()
    assert hashlib.sha256((base / 'diagnostic-backup.pack').read_bytes()).hexdigest() == manifest['previous_probe_sha256']
    assert hashlib.sha256(target.read_bytes()).hexdigest() == manifest['files']['jaws_access.pack']
    assert Path(json.loads((app / 'config.json').read_text(encoding='utf-8-sig'))['game_path']) == game
    assert (app / 'Start Pilot.cmd').exists()
    # Every runtime payload must actually be copied, not merely present in the ZIP.
    for name, digest in manifest['files'].items():
        if name in ('jaws_access.pack', 'Install.ps1', 'Install.cmd'):
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
    assert not (game / 'data/jaws_access.pack.new').exists()
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
    assert (base / 'diagnostic-backup.pack').exists()
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
print('PASS: shipped ZIP install, non-default path with spaces, idempotence, upgrade over an earlier install, old-probe backup, mismatch refusal, tamper detection, uninstall and preservation')
