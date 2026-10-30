#!/bin/bash
# Builds Pilot.app, signs it with a stable local certificate (so Accessibility permission survives
# rebuilds), installs it to ~/Applications and launches it.   Usage: app/build.sh [--no-launch]
set -euo pipefail
cd "$(dirname "$0")"
REPO="$(cd .. && pwd)"
APP="build/Pilot.app"
DEST="$HOME/Applications/Pilot.app"
IDENTITY="Pilot Local Signing"
KEYCHAIN="$HOME/Library/Keychains/pilot-signing.keychain-db"
KC_PASS="pilot"   # only protects a self-signed cert used to sign this app on this Mac

# 1. One-time: a self-signed code-signing certificate in its own keychain (no password prompts).
if ! security find-certificate -c "$IDENTITY" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "Creating signing certificate '$IDENTITY' (one time)…"
  TMP="$(mktemp -d)"
  cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $IDENTITY
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF
  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cert.cnf" \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
  /usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/cert.p12" -passout pass:"$KC_PASS"
  [ -f "$KEYCHAIN" ] || security create-keychain -p "$KC_PASS" "$KEYCHAIN"
  security unlock-keychain -p "$KC_PASS" "$KEYCHAIN"
  security set-keychain-settings "$KEYCHAIN"   # no auto-lock
  security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$KC_PASS" -T /usr/bin/codesign >/dev/null
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KC_PASS" "$KEYCHAIN" >/dev/null
  rm -rf "$TMP"
fi
security unlock-keychain -p "$KC_PASS" "$KEYCHAIN"
# codesign only finds identities in keychains on the search list
if ! security list-keychains -d user | grep -q pilot-signing; then
  security list-keychains -d user -s $(security list-keychains -d user | tr -d '"') "$KEYCHAIN"
fi

# 2. Build and check the Brain.
swift build -c release --product Pilot
swift build -c release --product BrainCheck
.build/release/BrainCheck "$REPO/commands/commands.json"

# 3. Assemble the app bundle.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Pilot "$APP/Contents/MacOS/Pilot"
cp "$REPO/commands/commands.json" "$APP/Contents/Resources/commands.json"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>dev.jsurya.pilot</string>
  <key>CFBundleName</key><string>Pilot</string>
  <key>CFBundleDisplayName</key><string>Pilot</string>
  <key>CFBundleExecutable</key><string>Pilot</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>$(date +%Y%m%d%H%M)</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>PilotCommandsPath</key><string>$REPO/commands/commands.json</string>
  <key>NSAppleEventsUsageDescription</key><string>Pilot plays the song you ask for from your Music library ("Pilot, play Florida on Apple Music").</string>
  <key>NSMicrophoneUsageDescription</key><string>Pilot listens for the word "Pilot" so it can start Wispr Flow without a key, only while you switch it on.</string>
  <key>NSSpeechRecognitionUsageDescription</key><string>Pilot recognises the word "Pilot" on this Mac, offline, to start Wispr Flow.</string>
</dict>
</plist>
EOF
codesign --force --sign "$IDENTITY" --keychain "$KEYCHAIN" --identifier dev.jsurya.pilot "$APP"

# 4. Install and (re)launch.
pkill -x Pilot 2>/dev/null && sleep 0.5 || true
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -R "$APP" "$DEST"
echo "Installed $DEST"
[ "${1:-}" = "--no-launch" ] || open "$DEST"
