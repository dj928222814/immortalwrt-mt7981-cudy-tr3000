#!/usr/bin/env bash
# Import packages used by the legacy 256M profile into an upstream 25.12 tree.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENWRT_DIR="${OPENWRT_DIR:-$REPO_DIR/openwrt}"
PACKAGE_DIR="$OPENWRT_DIR/package"
IMPORT_DIR="${RUNNER_TEMP:-/tmp}/tr3000-25.12-package-sources"

mkdir -p "$PACKAGE_DIR" "$IMPORT_DIR"

stage_package() {
  local source_dir="$1"
  local package_name
  package_name="$(basename "$source_dir")"
  if [[ ! -f "$source_dir/Makefile" ]]; then
    echo "::error::Package Makefile not found: $source_dir"
    exit 1
  fi
  if [[ -e "$PACKAGE_DIR/$package_name" || -L "$PACKAGE_DIR/$package_name" ]]; then
    echo "::error::Package name collision while importing $package_name"
    exit 1
  fi
  ln -s "$source_dir" "$PACKAGE_DIR/$package_name"
  echo "Imported $package_name"
}

clone() {
  local name="$1" url="$2" branch="$3"
  git clone --depth 1 --single-branch --branch "$branch" "$url" "$IMPORT_DIR/$name"
}

# Keep the repository's local luci-compat-keep package.
stage_package "$REPO_DIR/package/luci-compat-keep"

# QModem's source tree is a collection of packages, not a feed root. Stage each
# package directory at OpenWrt's package/ level so the build system discovers it.
clone qmodem https://github.com/sfwtw/QModem-custom.git main
for category in application luci; do
  for source_dir in "$IMPORT_DIR/qmodem/$category"/*; do
    [[ -d "$source_dir" && -f "$source_dir/Makefile" ]] && stage_package "$source_dir"
  done
done
while IFS= read -r makefile; do
  stage_package "$(dirname "$makefile")"
done < <(find "$IMPORT_DIR/qmodem/driver" -mindepth 2 -maxdepth 3 -type f -name Makefile -print)

# Use the current Argon package and its bundled compatibility package. Remove
# feed copies first so the build has only one provider for each package.
clone argon https://github.com/jerrykuku/luci-theme-argon.git master
rm -rf "$OPENWRT_DIR/feeds/luci/themes/luci-theme-argon" \
       "$OPENWRT_DIR/feeds/luci/applications/luci-app-argon-config" \
       "$PACKAGE_DIR/feeds/luci/luci-theme-argon" \
       "$PACKAGE_DIR/feeds/luci/luci-app-argon-config"
stage_package "$IMPORT_DIR/argon"
stage_package "$IMPORT_DIR/argon/compat/luci-app-argon-config"

# Preserve the Aurora theme and its LuCI settings app selected by the old profile.
clone aurora-theme https://github.com/eamonxg/luci-theme-aurora.git master
clone aurora-config https://github.com/eamonxg/luci-app-aurora-config.git master
stage_package "$IMPORT_DIR/aurora-theme"
stage_package "$IMPORT_DIR/aurora-config"

# Bandix is split into a backend and LuCI frontend package.
clone bandix-core https://github.com/timsaya/openwrt-bandix.git main
clone bandix-luci https://github.com/timsaya/luci-app-bandix.git main
stage_package "$IMPORT_DIR/bandix-core/openwrt-bandix"
stage_package "$IMPORT_DIR/bandix-luci/luci-app-bandix"

# iStore is maintained as an OpenWrt feed and is added by the workflow itself.
