#!/usr/bin/env bash
# Bring PKGBUILD and .SRCINFO up to the latest upstream release and test build the package.
# Exit 0 without changes when there is no newer upstream version.
# Any failure exits non zero so the caller must not push anything.
set -euo pipefail

cd "$(dirname "$0")"

upstream_repo="botiverse/desktop"
release_api="https://api.github.com/repos/$upstream_repo/releases/latest"

api_headers=(-H "Accept: application/vnd.github+json")
if [ -n "${GITHUB_TOKEN:-}" ]; then
  api_headers+=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

# The "latest" release endpoint never returns drafts or prereleases.
latest_tag=$(curl -fsSL "${api_headers[@]}" "$release_api" | grep -oP '"tag_name":\s*"\K[^"]+')
new_version="${latest_tag#v}"

current_version=$(grep -oP '^pkgver=\K.*' PKGBUILD)

echo "upstream version: $new_version"
echo "package version:  $current_version"

if [ "$(vercmp "$new_version" "$current_version")" -le 0 ]; then
  echo "package is up to date, nothing to do"
  exit 0
fi

deb_name="Raft-Desktop-${new_version}-amd64.deb"
sums_url="https://github.com/$upstream_repo/releases/download/${latest_tag}/SHA256SUMS"

new_sha=$(curl -fsSL "$sums_url" | grep -P "\s$deb_name\$" | cut -d' ' -f1)
if [ -z "$new_sha" ]; then
  echo "could not find $deb_name in upstream SHA256SUMS"
  exit 1
fi
echo "upstream sha256:  $new_sha"

sed -i \
  -e "s/^pkgver=.*/pkgver=$new_version/" \
  -e "s/^pkgrel=.*/pkgrel=1/" \
  -e "s/^sha256sums=.*/sha256sums=('$new_sha')/" \
  PKGBUILD

makepkg --printsrcinfo > .SRCINFO

# makepkg downloads the .deb and fails when its sha256 does not match PKGBUILD.
# Runtime dependencies are not needed to repackage a .deb, so skip the dependency check.
makepkg -f -d --noconfirm

package_file=$(makepkg --packagelist | head -n1)
echo "built package:    $package_file"

check_dir=$(mktemp -d)
trap 'rm -rf "$check_dir"' EXIT
bsdtar -xf "$package_file" -C "$check_dir"

launcher="$check_dir/usr/bin/raft-desktop"
if [ ! -L "$launcher" ]; then
  echo "check failed: usr/bin/raft-desktop is not a symlink"
  exit 1
fi
launcher_target=$(readlink "$launcher")
if [ ! -f "$check_dir$launcher_target" ]; then
  echo "check failed: symlink target $launcher_target is missing from the package"
  exit 1
fi

desktop_file="$check_dir/usr/share/applications/raft-desktop.desktop"
if ! grep -q '^Exec=raft-desktop' "$desktop_file"; then
  echo "check failed: desktop file Exec line is wrong"
  grep '^Exec=' "$desktop_file" || true
  exit 1
fi
if ! grep -q '^Icon=raft-desktop$' "$desktop_file"; then
  echo "check failed: desktop file Icon line is wrong"
  grep '^Icon=' "$desktop_file" || true
  exit 1
fi

echo "all checks passed for $new_version"
