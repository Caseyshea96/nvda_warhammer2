"""Package the Windows NVDA build with a hash manifest and exact payload checks.

--graphics-preview: the player build (menus, Select Lord, campaign reading).
--scanner-compare: the read-only scanner comparison diagnostic.
"""
from pathlib import Path
import hashlib
import json
import zipfile
import sys
graphics_preview = "--graphics-preview" in sys.argv
scanner_compare = "--scanner-compare" in sys.argv
if graphics_preview == scanner_compare:
    raise SystemExit('Choose --graphics-preview or --scanner-compare')
version = "0.6.67-nvda-automation-preview" if graphics_preview else "0.5.3-nvda-scanner-compare"
pack_name = "warhammer_access_graphics_preview.pack" if graphics_preview else "warhammer_access_scanner_compare.pack"

root = Path(__file__).resolve().parents[1]
pack = (root / 'artifacts' / pack_name).read_bytes()
digest = hashlib.sha256(pack).hexdigest()
assert (root / 'artifacts' / (pack_name + '.sha256')).read_text().split()[0] == digest
assert pack[:4] == b'PFH5' and int.from_bytes(pack[4:8], 'little') & 15 == 3
files = {'warhammer_access.pack': pack}
for folder in ('companion', 'packaging/pilot'):
    for path in sorted((root / folder).iterdir()):
        if path.name == 'Automation.ps1' and not graphics_preview:
            continue
        if not path.is_file():
            continue
        assert path.name not in files, f'duplicate {path.name}'
        files[path.name] = path.read_text().replace('\n', '\r\n').encode('utf-8')
controller = root / 'local/tools/nvda-2026.2-controller/x64/nvdaControllerClient.dll'
license_file = root / 'local/tools/nvda-2026.2-controller/license.txt'
files['nvdaControllerClient.dll'] = controller.read_bytes()
files['LICENSE-NVDA-CONTROLLER.txt'] = license_file.read_bytes()
files['warhammer2-quiet-mode-0.1.0.nvda-addon'] = (
    root / 'artifacts/warhammer2-quiet-mode-0.1.0.nvda-addon').read_bytes()
if graphics_preview:
    files['Start Pilot.cmd'] = files['Start Pilot.cmd'].replace(b' -Launch', b' -Launch -MenuKeys')
    assert files['Start Pilot.cmd'].count(b'-MenuKeys') == 2
files['README.txt'] = (root / ('packaging/interactive/GRAPHICS_PREVIEW.txt' if graphics_preview else 'diagnostics/SCANNER_COMPARE.txt')).read_bytes()
assert b"stage -eq 'frontend-activation-preview'" in files['Companion.ps1']
manifest = {
    'version': version, 'stage': 'frontend-activation-preview' if graphics_preview else 'read-only-native-ui-diagnostic',
    'steam_app_id': 594570,
    'screen_reader': 'NVDA',
    'nvda_controller_version': '2026.2',
    'nvda_controller_bundle_sha256': '510736F021AEFA33378076FA342A4524B586BC1C6B096DB9479AF42B28AAC649',
    'nvda_quiet_mode_version': '0.1.0',
    'automation_protocol': 1 if graphics_preview else None,
    'windows_runtime_tested': False, 'screen_reader_runtime_tested': False, 'coop_tested': False,
    'files': {name: hashlib.sha256(data).hexdigest() for name, data in sorted(files.items())}
}
files['manifest.json'] = (json.dumps(manifest, indent=2) + '\n').encode()
expected = {'warhammer_access.pack','Companion.ps1','Bridge.cs','NvdaController.cs','MenuKeys.cs','Protocol.ps1',
            'Install.ps1','Install.cmd','Uninstall.ps1','Uninstall.cmd','Start Pilot.cmd','README.txt','manifest.json',
            'nvdaControllerClient.dll','LICENSE-NVDA-CONTROLLER.txt','warhammer2-quiet-mode-0.1.0.nvda-addon'}
if graphics_preview:
    expected.add('Automation.ps1')
assert set(files) == expected, (set(files) ^ expected)
package_name = 'warhammer2-windows-' + version
output = root / f'artifacts/{package_name}.zip'
prefix = f'{package_name}/'
with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    for name, data in sorted(files.items()):
        archive.writestr(prefix + name, data)
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    for name, data in files.items():
        assert archive.read(prefix + name) == data
output.with_suffix('.zip.sha256').write_text(hashlib.sha256(output.read_bytes()).hexdigest() + '  ' + output.name + '\n')
print(output)
