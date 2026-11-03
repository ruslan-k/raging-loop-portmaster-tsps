# Raging Loop — PortMaster port (TrimUI Smart Pro S / aarch64)

Raging Loop (Kemco, 2015/2017 PC release) is a Unity **2018.3.10f1** game, **Mono / .NET 3.5**,
Windows-only build (D3D11 shaders, x86 player, 18 scenes, 1280x720). This repository holds the
PortMaster port for the TrimUI Smart Pro S ("TSPS": aarch64, SpruceOS, Mali-G57) built on
[wild1walker/portmaster-unity](https://github.com/wild1walker/portmaster-unity), following the
structure of [wild1walker/portmaster-cuphead](https://github.com/wild1walker/portmaster-cuphead).

**Status: build stage.** The port is not yet packaged or verified on the device.

## Why this route

`pmunity port check` on the retail Windows data:

| fact | value | consequence |
|---|---|---|
| Unity | 2018.3.10f1 | supported by the toolkit (2017.4 – 2022.3) |
| script backend | Mono, .NET 3.5 (`libmono`) | no Mono 2.6 aarch64 JIT ⇒ the plain `mono-arm64` template is refused |
| player | Windows x86, D3D11 shaders | shaders must be translated (HLSLcc) |
| scenes | 18 | — |
| screen | 1280x720 | matches the handheld panel |

The Android package (`Raging.Loop.ver.1.0.1.build.101.apk`, 32 MB) is only the runtime: the game
content is a separate 1.84 GB download (`kemco.ragingloopdeluxe.zip`, `files/…`), so the APK-import
route would need Kemco's download service. The Windows build is complete and self-contained.

Route taken: **Windows data → `il2cpp` (arm64-v8a)** — the Mono assemblies are compiled into
`libil2cpp.so` against the Unity 2018.3.10f1 Android player, so the game runs on a stock arm64
Unity player with no Mono runtime and no bridge.

## Build

```sh
./build.sh            # il2cpp + data conversion, into build/
```

Requires the toolkit checkout (`PORTMASTER_UNITY`, default `../skald-work/portmaster-unity`), Docker,
~8 GB free disk. The toolkit fetches the Unity 2018.3.10f1 editor IL2CPP toolchain, NDK r16b and the
`player-arm64-v8a` package into `~/.cache/pmunity` on the first run.

## Known deviations from the retail build

1. **`UnityEngine.MovieTexture` is gone from the 2018.3 Android player** (removed from Unity; the
   Windows Mono reference assembly still has it). `Assembly-CSharp` declares two fields of that type
   (`VideoPlayer.movie`, `ViewController.Video`), and no IL reads or writes them — only the type
   reference breaks IL2CPP. `tools/movietexture-patch` retypes both fields to `System.Object` on a
   copy of the data; the original game files are untouched. Movie playback (OP/ED) therefore does
   not run; the story path does not depend on it.
2. **`plugin.dll`** (Kemco helper, one P/Invoke: `executeAPI`) is a Windows x86 DLL and is not
   shipped. See `docs/build-log.md` for how it is handled.
3. Windows D3D11 shaders are translated to GLES3 with HLSLcc at packaging time.

## Layout

```
build.sh                     reproduce the arm64 libil2cpp.so + converted data
tools/movietexture-patch/    the only source patch the port needs (documented above)
docs/build-log.md            what was tried, what the tooling said, what broke and why
port/                        launcher + PortMaster metadata (added at packaging)
```

No game data is stored in this repository.
