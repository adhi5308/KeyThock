#!/bin/zsh
# Builds a double-clickable local macOS app at KeyThock.app.
set -euo pipefail

project_dir="${0:A:h:h}"
app_path="$project_dir/KeyThock.app"

cd "$project_dir"
swift build -c release

rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "AppBundle/Info.plist" "$app_path/Contents/Info.plist"
cp ".build/release/KeyThock" "$app_path/Contents/MacOS/KeyThock"
cp "AppBundle/KeyThock.icns" "$app_path/Contents/Resources/KeyThock.icns"
cp -R "SoundPacks" "$app_path/Contents/Resources/SoundPacks"

# Ad-hoc signing identifies the app as a local bundle to macOS.
codesign --force --deep --sign - "$app_path"
echo "Built $app_path"
