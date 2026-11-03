# Build log

Chronological, with the tooling's own output. Route: Windows Mono data → arm64 IL2CPP.

## 1. What the retail Windows build is

`pmunity port check` on `ragingloop_Data`:

- Unity **2018.3.10f1**, Windows **x86 Mono** player (`.NET 3.5`, `libmono`), 18 scenes, 1280x720.
- Textures: BC (DXT5 4 MB, a couple of tiny DXT1); shaders D3D11; audio inside `resources.assets`.
- `ragingloop_Data/Plugin/plugin.dll` — one P/Invoke, see §5.
- `StreamingAssets/` 574 MB of loose story assets (`background/`, `ui/`, `Movies/`, `popup/`,
  `thumb/`, `license/`), read with `System.IO` — so the port needs them loose and the game's reads
  pointed beside the APK.

Rejected routes, and why:

- **APK import** (`Raging.Loop.ver.1.0.1.build.101.apk`, 32 MB): it is only the runtime. The story
  is a separate 1.84 GB download (`kemco.ragingloopdeluxe.zip`, `files/…`) fetched by the app from
  Kemco; the APK alone has nothing to play.
- **Mono arm64 template** (the usual Windows-data route): the game needs Mono 2.6, and the toolkit's
  aarch64 Mono is newer; `port check` refuses that template for this data. Hence IL2CPP.

## 2. IL2CPP conversion and the one blocker

```
python -m pmunity il2cpp <data> out/il2cpp --abi arm64-v8a --asmpatch "dotnet asmpatch.dll" \
       --streaming-assets loose --jobs 14
```

UnityLinker ran (69 assemblies kept → 5.6 MiB), then `il2cpp.exe` aborted with a stack inside
`Unity.IL2CPP.AssemblyConverter.Apply` — a dangling type reference:

```
Unable to resolve a reference to the type 'UnityEngine.MovieTexture' … (ViewController)
```

`UnityEngine.MovieTexture` was removed from Unity; the 2018.3 **Android** player's reference
assemblies no longer have a `TypeDef` for it (only the Windows Mono `UnityEngine.dll` still does —
verified by walking every `TypeDef`/`ExportedType` in
`~/.cache/pmunity/il2cpp/2018.3.10f1/player-arm64-v8a/Variations/il2cpp/Managed/*.dll`: the only
match is `DownloadHandlerMovieTexture`). The game declares two fields of the removed type:

```
FIELD VideoPlayer.movie      : UnityEngine.MovieTexture
FIELD ViewController.Video    : UnityEngine.MovieTexture[]
```

No IL instruction reads or writes either field, so `tools/movietexture-patch` retypes both to
`System.Object` on the build copy (the retail install is never modified). With that, IL2CPP
succeeded: `libil2cpp.so` 26.0 MiB, metadata version 24, 13 data files.

Consequence: movie playback (the OP/ED if the game plays them) does not run. The story path does not
depend on it.

## 3. Data conversion

```
python -m pmunity convert <data-copy> --config convert.json     # in place
```

`convert.json`: steps `shaders,textures,settings,audio,quality`; `shaders.from = ["d3d11"]`;
`settings.graphics_apis = [11]` (GLES3); `quality.profile = handheld` (the panel is 720p and the
device has 963 MB of RAM). Run output, in full:

```
shaders: 42 shaders given GLES3 programs (175 programs, 362 subprograms) in 5 files; 1 not translatable
shaders: from Direct3D 11: 42 of 43 shaders (175 programs); 1 SubShaders left out
         (Hidden/BlitToDepth_MSAA pass 0: textureSamples() is not in GLSL ES)
textures: guided_astc is not installed: every block is searched (mode "search")
textures: 10 converted (37 -> 12 MB), 0 atlas entries and 0 sprites follow their scaled textures
audio: 0 clips kept compressed in memory (0.0 MiB of PCM); budget 16 MiB a scene, most a scene holds 0.0 MiB
quality: QualitySettings: Good/Fantastic/Beautiful pixelLightCount -> 1, shadows -> 1,
         shadowResolution 2 -> 1, Fantastic.shadowCascades 4 -> 2, anisotropicTextures -> 1,
         Fantastic/Beautiful.softParticles -> False
quality: run-time caps for ua_host: pixel_lights=1,shadows=1,shadow_resolution=1,
         shadow_cascades=2,msaa=0,anisotropic=1,soft_particles=0
```

Note: `convert` must run **in place on the data copy**; a separate output directory drops
`Managed/`, and the next step needs it (`no managed assemblies (Managed/*.dll)`).

## 4. Android data + APK

```
python -m pmunity android-data --src <data-copy> --pkg <player-arm64-v8a> --il2cpp out/il2cpp \
       --out out/android --streaming-assets loose --pack apk \
       --name RagingLoop --package com.kemco.ragingloop
```

`RagingLoop.apk` 880.6 MiB (zip32, stored, aligned, verified), `Game_Data/StreamingAssets/`
574.2 MiB loose beside it, `plugins.map` with 3 libraries. The tool's own warning is the next step:

> plugin plugin (unknown library, 1 entry points): none - shipped as a desktop library only:
> DllNotFoundException at the first call unless an ARM build (Android, or Linux glibc) is put in lib/

## 5. `plugin.dll` (Kemco DRM stub)

`Assembly-CSharp` has exactly one P/Invoke into it:

```
PINVOKE DmmDrm.executeAPI : System.Void (System.String a) <- plugin!executeAPI
CALL   DmmDrm.Start @IL_0005: ldstr "gp_v98du3j0"; call DmmDrm::executeAPI(string)
```

Void return, result ignored, the caller wraps it in try/catch ("drm error" on failure). So the port
ships a 2-line `libplugin.so` exporting a no-op `executeAPI`, built with the `ua-build-arm64` cross
image, and `plugins.map` maps `plugin` to it (`map plugin lib libplugin.so`).

## 6. Port layout

```
ports/ragingloop/
  ua_host                     runtime (built from the toolkit's runtime/, arm64)
  arm64/RagingLoop.apk        game data
  arm64/Game_Data/StreamingAssets/
  arm64/plugins.map           plugin -> lib/libplugin.so
  arm64/android_package.json
  arm64/lib/{libunity.so, libil2cpp.so, libplugin.so}
ports/RagingLoop.sh           launcher (PortMaster control.txt + get_controls)
```

### Installed payload, read back from the device (sha256, 2026-11-03)

```
5876f24f20cd68b3c2b270ebf0b1b03cd2408a724297c5782bbafede9ab7ee34  lib/libunity.so    19971888
5d383a627c13a773418bc2da1c35470e090b2e668f6441627ab4a77ea56968eb  lib/libil2cpp.so   27291680
eb0fda78de3146429a9d453940df1b6ab12eb52c28e8ff39415856c9c13e03ad  lib/libplugin.so       7928
bf3079d0cdb22306c3745130271781bced7af9647600f34a326c82b5cda3e7c5  lib/libmain.so         6144
bb1c757a489bd6fc1e002aaa78b8e31c5b22e0999140f7fa23491cbb3c05ed56  RagingLoop.apk    923337410
```

All five match the local build byte for byte. The copy to the SD card is `rsync -a`, which reports
exit 23 on exFAT/vfat (`chown … Operation not permitted` on the temp file); the payload is unaffected —
hashes above are the proof. `plugins.map` on the device reads
`map plugin lib libplugin.so`, `map sdkencryptedappticket none`, `map steam_api stub steam`.

## 7. Device test

TrimUI Smart Pro S (SpruceOS, Mali-G57), `ua_host` launched directly with the port's environment
(`HOME=conf`, `UA_FPS=1`, the `TRIMUI Player1` SDL mapping). 6826 frames, then `SIGTERM`:

```
[display] SDL KMSDRM: EGL 1.4 Valhall-"r32p0-01eac1" (ARM), Mali-G57, OpenGL ES 3.2 v1.r32p0-01eac1.3634895aa082dda7c3407d9f3e199919
[display] config 9: RGBA 8888 depth 24 stencil 8 samples 0, ES3
[display] fullscreen 1280x720, 60 Hz, swap interval 1
[plugins] /mnt/sdcard/mmcblk1p1/Roms/ports/ragingloop/arm64/plugins.map: 3 libraries, 0 float signatures
[plugins] plugin: lib/libplugin.so (glibc library)
[plugins] sdkencryptedappticket: not available (DllNotFoundException at the first call)
[plugins] steam_api: built-in stub steam
[input] pad 0: "TRIMUI Player1" (SDL "TRIMUI Player1", 045e:028e) as Android device 1
[fps] 60.0 fps, frame 16.7 avg / 17.2 p99 / 17.2 worst ms, late 0 hitch 0, gc 0 heap -1 MB (… 6826 total, 114 s) rss 172 MB
[fj 23424] up: UnityMain thread exits after 6826 frames
```

Facts worth keeping:

- 60.0 fps with `late 0 hitch 0` for the whole run, 172 MB RSS (the device has 963 MB).
- `sdkencryptedappticket` is listed as unavailable; the game never calls it, so it never throws.
  The stub only has to cover `plugin` (Kemco's `executeAPI`), which resolves.
- `ERROR: Could not queue pageflip: -16` appears 53 times over the run (EBUSY from `SDL_GL_SwapWindow`).
  Rendering and the frame counters are unaffected; it was produced while the frontend still owned the
  display, so it is not yet attributed to a real KMS problem.
- First run died at `libmain.so: No such file or directory` — the player package ships it
  (`Variations/il2cpp/Release/Libs/arm64-v8a/libmain.so`, 6 KB), it is now in `lib/`.

Not yet verified: the picture itself. `ua_host`'s own screenshot path needs GLES hooks this build
does not have (`[frames] screenshot: no GLES functions`), so a `shot.req` in the port dir is ignored;
a frame has to come from a `kmsgrab` capture. Until then "60 fps, 172 MB" is the render side only.
