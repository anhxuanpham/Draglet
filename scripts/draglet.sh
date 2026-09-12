#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 William
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
worktree_key="$(printf '%s' "$project_dir" | shasum -a 256 | cut -c 1-12)"
derived_data="${DRAGLET_DERIVED_DATA:-${TMPDIR:-/tmp}/draglet-derived-$worktree_key}"
products_root="${DRAGLET_PRODUCTS_DIR:-${TMPDIR:-/tmp}/draglet-products-$worktree_key}"
artifacts_dir="$project_dir/artifacts"
action="${1:-help}"

usage() {
    cat <<'USAGE'
Usage: bash scripts/draglet.sh <command>
  generate                 Regenerate Draglet.xcodeproj with XcodeGen
  icon                     Regenerate native app-icon assets
  build [Debug|Release]    Build an ad-hoc-signed app (Release is universal)
  test                     Run all native unit/integration tests
  package                  Build and verify local app, ZIP and DMG
  release IDENTITY PROFILE Sign with Developer ID and notarize with a stored keychain profile

Optional paths: DRAGLET_DERIVED_DATA, DRAGLET_PRODUCTS_DIR.
Artifacts go to the project's artifacts/ directory. No external publication.
USAGE
}

generate() { xcodegen generate --spec project.yml; }

build_app() {
    local configuration="$1"
    if [[ "$configuration" != Debug && "$configuration" != Release ]]; then
        printf 'Configuration must be Debug or Release.\n' >&2
        exit 2
    fi
    local arch_args=(ONLY_ACTIVE_ARCH=YES)
    if [[ "$configuration" == Release ]]; then arch_args=("ARCHS=arm64 x86_64" ONLY_ACTIVE_ARCH=NO); fi
    xcodebuild -project Draglet.xcodeproj -scheme Draglet -configuration "$configuration" \
        -derivedDataPath "$derived_data" "CONFIGURATION_BUILD_DIR=$products_root/$configuration" \
        CODE_SIGN_IDENTITY=- "${arch_args[@]}" build
}

notarize() {
    local payload="$1" profile="$2" result="$3"
    xcrun notarytool submit "$payload" --keychain-profile "$profile" --wait --output-format json > "$result"
    python3 - "$result" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    raise SystemExit('Notarization was not accepted; inspect ' + sys.argv[1])
print('Notarization accepted:', result['id'])
PY
}

package_app() {
    local identity="${1:-}" profile="${2:-}" suffix=local
    if [[ -n "$identity" ]]; then
        if [[ "$identity" != "Developer ID Application:"* || -z "$profile" ]]; then
            printf 'Release requires a Developer ID Application identity and a stored notarytool profile.\n' >&2
            exit 2
        fi
        suffix=notarized
    fi
    build_app Release
    mkdir -p "$artifacts_dir"
    package_work="$(mktemp -d "${TMPDIR:-/tmp}/draglet-package.XXXXXX")"
    trap 'rm -rf "$package_work"' EXIT
    local app="$package_work/Draglet.app"
    ditto "$products_root/Release/Draglet.app" "$app"
    local version
    version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")"
    local stem="Draglet-$version-$suffix"
    if [[ -n "$identity" ]]; then
        codesign --force --options runtime --timestamp --sign "$identity" "$app"
        ditto -c -k --sequesterRsrc --keepParent "$app" "$package_work/submission.zip"
        notarize "$package_work/submission.zip" "$profile" "$artifacts_dir/$stem-app-notarization.json"
        xcrun stapler staple "$app"
        xcrun stapler validate "$app"
    fi
    codesign --verify --deep --strict --verbose=2 "$app"
    ditto -c -k --sequesterRsrc --keepParent "$app" "$artifacts_dir/$stem.zip"
    mkdir "$package_work/dmg"
    ditto "$app" "$package_work/dmg/Draglet.app"
    ln -s /Applications "$package_work/dmg/Applications"
    hdiutil create -volname Draglet -srcfolder "$package_work/dmg" -format UDZO -fs HFS+ -ov "$artifacts_dir/$stem.dmg"
    if [[ -n "$identity" ]]; then
        codesign --force --timestamp --sign "$identity" "$artifacts_dir/$stem.dmg"
        notarize "$artifacts_dir/$stem.dmg" "$profile" "$artifacts_dir/$stem-dmg-notarization.json"
        xcrun stapler staple "$artifacts_dir/$stem.dmg"
        xcrun stapler validate "$artifacts_dir/$stem.dmg"
        spctl --assess --type execute --verbose=2 "$app"
    fi
    unzip -tq "$artifacts_dir/$stem.zip"
    hdiutil verify "$artifacts_dir/$stem.dmg"
    shasum -a 256 "$artifacts_dir/$stem.zip" "$artifacts_dir/$stem.dmg" > "$artifacts_dir/$stem.sha256"
    local delivered_app="$artifacts_dir/$stem.app"
    if [[ -e "$delivered_app" ]]; then mv "$delivered_app" "$package_work/previous-delivery.app"; fi
    if ! ditto "$app" "$delivered_app"; then
        printf 'App copy failed; the verified ZIP and DMG are retained.\n' >&2
        exit 1
    fi
    codesign --verify --deep --strict "$delivered_app"
    printf '\nVerified packages: %s/%s.{zip,dmg}\nApp: %s\n' "$artifacts_dir" "$stem" "$delivered_app"
}

case "$action" in
    generate) generate ;;
    icon) swift scripts/GenerateAppIcon.swift ;;
    build) build_app "${2:-Debug}" ;;
    test)
        xcodebuild -project Draglet.xcodeproj -scheme Draglet -configuration Debug \
            -derivedDataPath "$derived_data" "CONFIGURATION_BUILD_DIR=$products_root/Debug" \
            CODE_SIGN_IDENTITY=- -parallel-testing-enabled NO test
        ;;
    package) package_app ;;
    release)
        if [[ $# -ne 3 ]]; then usage >&2; exit 2; fi
        package_app "$2" "$3"
        ;;
    help|--help|-h) usage ;;
    *) usage >&2; exit 2 ;;
esac
