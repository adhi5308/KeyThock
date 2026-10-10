#!/bin/zsh
# Usage: ./Scripts/release.sh 0.1.0 adhi5308/keythock
# Produces a GitHub-release archive and its ready-to-copy Homebrew cask.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  print "Usage: $0 VERSION GITHUB_OWNER/REPOSITORY"
  exit 1
fi

version="$1"
repository="$2"
project_dir="${0:A:h:h}"
dist_dir="$project_dir/dist"
archive="$dist_dir/KeyThock-$version.zip"

"$project_dir/Scripts/build-app.sh"
mkdir -p "$dist_dir"
rm -f "$archive"
ditto -c -k --sequesterRsrc --keepParent "$project_dir/KeyThock.app" "$archive"

checksum="$(shasum -a 256 "$archive" | awk '{print $1}')"
sed \
  -e "s|VERSION|$version|g" \
  -e "s|SHA256|$checksum|g" \
  -e "s|OWNER_REPOSITORY|$repository|g" \
  "$project_dir/Casks/keythock.rb.template" > "$dist_dir/keythock.rb"

print "Release archive: $archive"
print "Homebrew cask:   $dist_dir/keythock.rb"
