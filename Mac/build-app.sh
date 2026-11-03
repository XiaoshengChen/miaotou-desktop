#!/bin/zsh
set -euo pipefail
desktop_dir="${0:A:h}"
repo_dir="${desktop_dir:h}"
output_dir="$repo_dir/dist"
app_dir="$output_dir/小苗头.app"
mkdir -p "$output_dir"
swift build --package-path "$desktop_dir" -c release --arch arm64 --arch x86_64 -Xswiftc -file-prefix-map -Xswiftc "$repo_dir=." -Xswiftc -debug-prefix-map -Xswiftc "$repo_dir=."
binary_dir="$(swift build --package-path "$desktop_dir" -c release --arch arm64 --arch x86_64 --show-bin-path)"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/MiaotouMac" "$app_dir/Contents/MacOS/MiaotouMac"
ditto "$binary_dir/MiaotouDesktop_MiaotouMac.bundle" "$app_dir/Contents/Resources/MiaotouDesktop_MiaotouMac.bundle"
python3 "$desktop_dir/package-app.py" "$app_dir"
strip -S "$app_dir/Contents/MacOS/MiaotouMac"
codesign --force --sign - --entitlements "$desktop_dir/Miaotou.entitlements" "$app_dir"
codesign --verify --deep --strict "$app_dir"
python3 - "$app_dir" "$output_dir/Miaotou-Mac-1.0.zip" <<'ZIP'
from pathlib import Path
import sys, zipfile
app = Path(sys.argv[1])
with zipfile.ZipFile(sys.argv[2], 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for file in sorted(app.rglob('*')):
        if file.is_file(): archive.write(file, file.relative_to(app.parent))
ZIP
echo "$app_dir"
