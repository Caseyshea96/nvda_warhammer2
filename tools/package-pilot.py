"""Package Windows pilot with a hash manifest and exact payload checks."""
from pathlib import Path
import hashlib
import json
import zipfile
import sys
graphics_preview = "--graphics-preview" in sys.argv
scanner_compare = "--scanner-compare" in sys.argv
diagnostic = "--diagnostic" in sys.argv or scanner_compare
interactive_nvda = "--interactive-nvda" in sys.argv or graphics_preview
if diagnostic and interactive_nvda:
    raise SystemExit('Choose diagnostic or interactive NVDA, not both')
nvda = diagnostic or interactive_nvda
version = "0.6.63-nvda-automation-preview" if graphics_preview else "0.5.3-nvda-scanner-compare" if scanner_compare else "0.4.3-nvda-diagnostic" if diagnostic else ("0.5.2-nvda-preview" if interactive_nvda else "0.2.5-dev")
pack_name = "jaws_access_graphics_preview.pack" if graphics_preview else "jaws_access_scanner_compare.pack" if scanner_compare else "jaws_access_diagnostic.pack" if diagnostic else ("jaws_access_interactive.pack" if interactive_nvda else "jaws_access.pack")

root = Path(__file__).resolve().parents[1]
pack = (root / 'artifacts' / pack_name).read_bytes()
digest = hashlib.sha256(pack).hexdigest()
assert (root / 'artifacts' / (pack_name + '.sha256')).read_text().split()[0] == digest
assert pack[:4] == b'PFH5' and int.from_bytes(pack[4:8], 'little') & 15 == 3
files = {'jaws_access.pack': pack}
for folder in ('companion', 'packaging/pilot'):
    for path in sorted((root / folder).iterdir()):
        if path.name == 'Automation.ps1' and not graphics_preview:
            continue
        if not path.is_file():
            continue
        assert path.name not in files, f'duplicate {path.name}'
        files[path.name] = path.read_text().replace('\n', '\r\n').encode('utf-8')
if nvda:
    del files['Native.cs']
    del files['HotkeyPolicy.cs']
    controller = root / 'local/tools/nvda-2026.2-controller/x64/nvdaControllerClient.dll'
    license_file = root / 'local/tools/nvda-2026.2-controller/license.txt'
    files['nvdaControllerClient.dll'] = controller.read_bytes()
    files['LICENSE-NVDA-CONTROLLER.txt'] = license_file.read_bytes()
    files['warhammer2-quiet-mode-0.1.0.nvda-addon'] = (
        root / 'artifacts/warhammer2-quiet-mode-0.1.0.nvda-addon').read_bytes()
    files['Start Pilot.cmd'] = files['Start Pilot.cmd'].replace(
        b' -Launch', b' -Launch -NoHotkeys -ScreenReader Nvda' + (b' -MenuKeys' if graphics_preview else b''))
    files['README.txt'] = (root / ('packaging/interactive/GRAPHICS_PREVIEW.txt' if graphics_preview else 'diagnostics/SCANNER_COMPARE.txt' if scanner_compare else 'packaging/interactive/README.txt' if interactive_nvda else 'diagnostics/README.txt')).read_bytes()
    assert files['Start Pilot.cmd'].count(b'-NoHotkeys') == 2
    assert files['Start Pilot.cmd'].count(b'-ScreenReader Nvda') == 2
    assert b'[switch]$NoHotkeys' in files['Companion.ps1']
    assert b"stage -eq 'read-only-native-ui-diagnostic'" in files['Companion.ps1']
manifest = {
    'version': version, 'stage': 'read-only-native-ui-diagnostic' if diagnostic else ('frontend-activation-preview' if interactive_nvda else 'experimental-integration-pilot'), 'steam_app_id': 594570,
    'screen_reader': 'NVDA' if nvda else 'JAWS',
    'nvda_controller_version': '2026.2' if nvda else None,
    'nvda_controller_bundle_sha256': '510736F021AEFA33378076FA342A4524B586BC1C6B096DB9479AF42B28AAC649' if nvda else None,
    'nvda_quiet_mode_version': '0.1.0' if nvda else None,
    'automation_protocol': 1 if graphics_preview else None,
    'windows_runtime_tested': False, 'screen_reader_runtime_tested': False, 'coop_tested': False,
    'previous_probe_sha256': hashlib.sha256((root / 'artifacts/jaws_probe.pack').read_bytes()).hexdigest(),
    'files': {name: hashlib.sha256(data).hexdigest() for name, data in sorted(files.items())}
}
files['manifest.json'] = (json.dumps(manifest, indent=2) + '\n').encode()
expected = {'jaws_access.pack','Companion.ps1','Bridge.cs','NvdaController.cs','MenuKeys.cs','Protocol.ps1',
            'Install.ps1','Install.cmd','Uninstall.ps1','Uninstall.cmd','Start Pilot.cmd','README.txt','manifest.json'}
if graphics_preview:
    expected.add('Automation.ps1')
if nvda:
    expected.update({'nvdaControllerClient.dll','LICENSE-NVDA-CONTROLLER.txt','warhammer2-quiet-mode-0.1.0.nvda-addon'})
else:
    expected.update({'Native.cs','HotkeyPolicy.cs'})
assert set(files) == expected, (set(files) ^ expected)
package_name = ('warhammer2-windows-' if nvda else 'jaws-coop-pilot-windows-') + version
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
