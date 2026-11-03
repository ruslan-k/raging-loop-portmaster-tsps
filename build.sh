#!/bin/bash
# Raging Loop: Windows Mono data -> arm64 IL2CPP player data for ua_host.
# Input: GAME (a copy of the retail Windows install; "ragingloop_Data" inside it).
# Output: build/arm64 (apk, lib/, Game_Data/StreamingAssets) ready for the port dir.
set -euo pipefail

GAME=${GAME:-game}                     # copy of the retail install, e.g. game/ragingloop_Data
OUT=${OUT:-build}
TOOLKIT=${PORTMASTER_UNITY:-../skald-work/portmaster-unity}
UNITY=2018.3.10f1
HOME_DIR=${PMUNITY_HOME:-$HOME/.cache/pmunity}
PLAYER=$HOME_DIR/il2cpp/$UNITY/player-arm64-v8a
NDK=$HOME_DIR/il2cpp/ndk-r16b

[ -d "$GAME/ragingloop_Data" ] || [ -d "$GAME/Managed" ] || { echo "put the Windows data in $GAME/ragingloop_Data" >&2; exit 1; }
DATA=$GAME/ragingloop_Data; [ -d "$DATA" ] || DATA=$GAME
mkdir -p "$OUT/logs"

cd "$TOOLKIT/convert"; PY=../.venv/bin/python

# 1. the one source patch this game needs (see README)
dotnet build -v q --nologo "$OLDPWD/tools/movietexture-patch/movietexture-patch.csproj" -o "$OLDPWD/$OUT/tools" \
  -p:PortmasterUnity="$OLDPWD/$TOOLKIT" >/dev/null
dotnet "$OLDPWD/$OUT/tools/movietexture-patch.dll" "$DATA/Managed/Assembly-CSharp.dll"

# 2. IL2CPP: arm64-v8a libil2cpp.so + its metadata; streaming-asset reads pointed at a loose folder
$PY -m pmunity il2cpp "$DATA" "$OLDPWD/$OUT/il2cpp" --abi arm64-v8a \
  --asmpatch "dotnet $TOOLKIT/tools/asmpatch/out/asmpatch.dll" \
  --streaming-assets loose --jobs "$(nproc)" 2>&1 | tee "$OLDPWD/$OUT/logs/il2cpp.log"

# 3. D3D11 -> GLES3 shaders, textures, settings, handheld quality caps (in place)
PMHLSLCC=$TOOLKIT/tools/hlslcc/out/pmhlslcc $PY -m pmunity convert "$DATA" \
  --config "$OLDPWD/convert.json" 2>&1 | tee "$OLDPWD/$OUT/logs/convert.log"

# 4. the Android data tree + APK
$PY -m pmunity android-data --src "$DATA" --pkg "$PLAYER" --il2cpp "$OLDPWD/$OUT/il2cpp" \
  --out "$OLDPWD/$OUT/android" --streaming-assets loose --pack apk \
  --name RagingLoop --package com.kemco.ragingloop 2>&1 | tee "$OLDPWD/$OUT/logs/android-data.log"

# 5. libplugin.so: the game P/Invokes plugin!executeAPI (Kemco DRM, void, result ignored)
S=$OLDPWD/$OUT/stub; mkdir -p "$S"
cat > "$S/plugin.c" <<'EOF'
void executeAPI(const char *a) { (void)a; }
EOF
docker run --rm --user "$(id -u):$(id -g)" -v "$S":/w -w /w ua-build-arm64 \
  aarch64-linux-gnu-gcc -shared -fPIC -O2 -o libplugin.so plugin.c

# 6. assemble the port's arm64 dir
A=$OLDPWD/$OUT/arm64; rm -rf "$A"; mkdir -p "$A/lib"
cp "$OLDPWD/$OUT/android/zip/RagingLoop.apk" "$OLDPWD/$OUT/android/zip/android_package.json" \
   "$OLDPWD/$OUT/android/zip/plugins.map" "$A/"
sed -i 's/^map plugin none$/map plugin lib libplugin.so/' "$A/plugins.map"
cp -a "$OLDPWD/$OUT/android/zip/Game_Data" "$A/"
cp "$PLAYER/Variations/il2cpp/Release/Libs/arm64-v8a/libunity.so" "$A/lib/"
cp "$OLDPWD/$OUT/il2cpp/lib/arm64-v8a/libil2cpp.so" "$A/lib/"
cp "$S/libplugin.so" "$A/lib/"
echo "port data: $A"
