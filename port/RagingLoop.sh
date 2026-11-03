#!/bin/bash
# Raging Loop — PortMaster (TrimUI Smart Pro S). The game data in arm64/ is built by build.sh
# (Windows Mono data -> arm64 IL2CPP player data); nothing is built on the device.

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
if [ -d "/mnt/SDCARD/Persistent/portmaster/PortMaster/" ]; then
  controlfolder="/mnt/SDCARD/Persistent/portmaster/PortMaster"
elif [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source "$controlfolder/control.txt"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/$directory/ports/ragingloop"
cd "$GAMEDIR" || exit 1
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

export HOME="$GAMEDIR/conf"
export XDG_CONFIG_HOME="$HOME"
mkdir -p "$HOME"

export SDL_AUDIODRIVER=alsa
export UA_FPS=1
# TSPS pad is a virtual device: its SDL GUID carries crc16("TRIMUI Player1"), no DB entry matches it
export SDL_GAMECONTROLLERCONFIG="0300a3845e0400008e02000014010000,TRIMUI Player1,a:b0,b:b1,back:b6,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,guide:b8,leftshoulder:b4,leftstick:b9,lefttrigger:a2,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b10,righttrigger:a5,rightx:a3,righty:a4,start:b7,x:b2,y:b3,platform:Linux"

chmod +x "$GAMEDIR/ua_host"
"$GAMEDIR/ua_host" "$GAMEDIR/arm64"

pm_finish
