from pathlib import Path
import plistlib, subprocess, sys

app = Path(sys.argv[1]); source = Path(__file__).parent / 'Sources/MiaotouMac/Resources/icon.png'
info = {
    'CFBundleExecutable': 'MiaotouMac', 'CFBundleIdentifier': 'app.miaotou.desktop',
    'CFBundleName': '小苗头', 'CFBundleDisplayName': '小苗头', 'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': '1.0', 'CFBundleVersion': '1',
    'LSMinimumSystemVersion': '14.0', 'LSUIElement': True,
    'NSPrincipalClass': 'NSApplication', 'NSHighResolutionCapable': True,
    'CFBundleIconFile': 'Miaotou', 'CFBundleDevelopmentRegion': 'en',
    'CFBundleLocalizations': ['en', 'zh-Hans'], 'LSApplicationCategoryType': 'public.app-category.productivity'
}
(app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
icons = app.parent/'Miaotou.iconset'; icons.mkdir(exist_ok=True)
for size in [16, 32, 128, 256, 512]:
    for scale in [1, 2]:
        name = f'icon_{size}x{size}' + ('@2x' if scale == 2 else '') + '.png'
        subprocess.run(['sips', '-z', str(size*scale), str(size*scale), str(source), '--out', str(icons/name)], check=True, stdout=subprocess.DEVNULL)
subprocess.run(['iconutil', '-c', 'icns', str(icons), '-o', str(app/'Contents/Resources/Miaotou.icns')], check=True)
(app/'Contents/Resources/PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps({
    'NSPrivacyTracking': False, 'NSPrivacyTrackingDomains': [], 'NSPrivacyCollectedDataTypes': [], 'NSPrivacyAccessedAPITypes': []
}))
