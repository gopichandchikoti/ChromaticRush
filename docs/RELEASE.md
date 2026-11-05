# Chromatic Rush 1.0.0: release and verification

Built and verified on 2026-11-05 with Godot 4.7.2 official (`ed1daf0bf`). The dedicated
release key is protected outside the project. No commits, branches, pushes or store publication
were performed. These artifacts identify the current working source rather than a Git tag.

## Contents

- [Artifacts](#artifacts), [build/install/signing](#build-and-install) and [Android metadata](#android-metadata-and-signature)
- [Toolchain and compatibility](#toolchain-and-compatibility)
- [Tests and runtime verification](#tests-and-runtime-verification)
- [Accessibility verification](#accessibility-verification)
- [Quality gates](#quality-gates)
- [Balancing and performance](#balancing-and-performance)
- [Feature acceptance](#feature-acceptance)
- [Known limitations](#known-limitations)

This is the single record for release evidence and remaining acceptance gaps. Use the
[README](../README.md) to run/play, the [architecture guide](ARCHITECTURE.md) for implementation
and design decisions, and the [level catalogue](LEVEL_DESIGN.md) for individual authored routes.
Measurements below are the recorded 2026-11-05 release results, not newly rerun gameplay tests.

## Artifacts

| Artifact | Path | Bytes | SHA-256 |
|---|---|---:|---|
| Signed Android release | `builds/chromatic-rush-1.0.0-release.apk` | 52,667,604 | `8a29465f3d5d7cf77bb6078e4db10d350123b7eaf36177af0732e6bcc557a880` |
| Android debug | `builds/chromatic-rush-1.0.0-debug.apk` | 57,345,715 | `72535a0dd2a26c8af1161dc7e66fb9847546b7221eb8409ee74ad3f5337bc957` |
| Windows x64 preview | `builds/ChromaticRush-1.0.0.exe` | 109,569,376 | `829d5b22af97d305c6df2a9504e0ecfc119145d79b9bf4ab7363e1e4ae84a7f1` |
| Complete source | `builds/ChromaticRush-1.0.0-source.zip` | See file | See `.zip.sha256` sidecar |

The source digest stays in its sidecar because this document is itself inside the archive.
`scripts/audit_release.py` compares all sidecars and archived source bytes, checks ZIP CRCs,
verifies both APKs contain ten worlds/100 levels and the expected ABIs, and rejects signing
material and development-only payloads. Output: `builds/logs/release-audit.json`.

## Build and install

```powershell
.\scripts\bootstrap.ps1
.\scripts\check.ps1
.\scripts\test.ps1
.\scripts\quality.ps1
.\scripts\build.ps1 -Target All -SignedAndroidRelease
.\scripts\build.ps1 -Target Android
.\scripts\package.ps1
python .\scripts\audit_release.py
adb devices -l
adb -s YOUR_DEVICE_SERIAL install -r .\builds\chromatic-rush-1.0.0-release.apk
```

The first build command makes Windows plus the signed release; the second makes the separate
debug APK. Windows remains unsigned. Android signing uses the environment variables documented
in `.env.example`, or the existing protected signing directory. On a different machine restore
the signing files privately or provide your own key; do not generate a replacement identity for
updates to an existing release installation.

The private directory is `%USERPROFILE%\Documents\Codex\signing\ChromaticRush`. Its
`chromatic-rush-release.jks` and `release-password.txt` must be backed up together privately.
Only the current Windows user and SYSTEM were allowed by its protected directory ACL. Neither
file belongs in Git, source archives or app packages. `scripts/signing.ps1` checks/reuses existing
material and refuses partial key/password pairs. It never replaces an existing key automatically.

## Android metadata and signature

| Field | Inspected value |
|---|---|
| Package | `com.portfolio.chromaticrush` |
| Version | `1.0.0`, code `1` |
| Minimum / target SDK | 24 / 36 |
| ABIs | `arm64-v8a`, `x86_64` |
| Permission | `android.permission.VIBRATE` only |
| Network/storage permissions | None |
| Cloud backup | Disabled |
| Release signer | CN=Chromatic Rush, OU=Application Release, O=Chromatic Rush |
| Release key | RSA 3072 bits |
| Certificate SHA-256 | `0f84da993081ffe4d72793b5724cc18eac311e91cb3ed78a72a7f8e1456cfb5c` |
| Signature schemes | v2 and v3 verified |
| Launcher | `com.portfolio.chromaticrush/com.godot.game.GodotAppLauncher` |
| Release debuggable flag | Absent in installed package flags |

Evidence: `builds/logs/signed-apk-signature.log` and `signed-apk-metadata.log`.
`aapt2` still warns about an unused template themed-icon alias referencing missing XML. The
normal launcher/icon works; Android themed icons have not been verified.

The release and debug certificates differ. Android cannot update a debug-key installation with
this release. Removing the old installation erases its local progress. Same-key reinstall of
this signed APK succeeded and retained the saved large-text preference. That is same-version
reinstall evidence, not a cross-version migration test.

## Signed Android runtime evidence

Dedicated AVD `ChromaticRush_Release_Test`, Android 35 x86_64, 540x1200 at density 200, host GPU
renderer on AMD Radeon 780M. Commands used only this AVD. A separate ADB server on port 5038 and
its `127.0.0.1:5565` endpoint avoided another project's ADB server restarts.

- Signed installation succeeded. Host-renderer cold launch reported 1,374 ms.
- Menu, arena and touch input rendered. A direct tap incremented the actual run to one tap.
- System Back opened pause; a second Back resumed without replacing PID 2782.
- Airplane mode was enabled, the app force-stopped, and cold launch succeeded (942 ms).
  Continue restored route one and its cumulative 48.6-second run time.
- Large text was enabled using the real native settings toggle. Same-signed-APK reinstall
  succeeded; relaunch (740 ms) retained the enlarged, scrolling home screen.
- Airplane mode was restored to 0. The inspected crash buffer was empty.

Screenshots: `docs/evidence/signed-*.png`; machine-readable summary:
`docs/evidence/signed_android_smoke.json`. Screenshots show actual inspected states; no phone FPS,
audio output or vibration claim is inferred.

### Emulator renderer failure

The first test used deprecated `-gpu swiftshader_indirect` and displayed a blank canvas. The
engine reported `Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)`.
Restarting this same AVD with `-gpu host` rendered the **unchanged APK** with no corresponding
shader errors. Evidence: `builds/logs/signed-render-before.log` and `signed-render-host.log`.
This is a known limitation of that legacy emulator configuration. No unsupported project-setting
workaround or changed gameplay was shipped. Physical GPU compatibility remains untested.


## Toolchain and compatibility

Assessed 2026-11-03 on Windows 10.0.26300 (x64). No existing applications were changed.

| Component | Verified installation | Result |
| --- | --- | --- |
| Godot | `%LOCALAPPDATA%/Programs/CodexDevTools/godot/Godot_v4.7.2-stable_win64_console.exe` | `4.7.2.stable.official.ed1daf0bf` |
| Export templates | Godot 4.7.2 stable, Android and Windows | Download SHA512 matches official manifest |
| Java | `%USERPROFILE%/Documents/Codex/tools/jdk/jdk-17.0.19+10` | OpenJDK 17.0.19 Microsoft LTS |
| Android SDK | `%USERPROFILE%/Documents/Codex/android-sdk` | Platforms 35, 36, 37.0; build-tools 35.0.0, 36.0.0, 37.0.0 |
| ADB | SDK `platform-tools/adb.exe` | 1.0.41; platform-tools 37.0.0 |
| Emulator | SDK `emulator/emulator.exe` | 36.6.11.0 |
| Test AVD | `ChromaticRush_Test` | Dedicated Android 35 Google APIs x86_64, Pixel 7 1080x2400 |
| Python | `%LOCALAPPDATA%/Programs/Python/Python313/python.exe` | 3.13.15 |
| Physical phone | `adb devices -l` | None connected at any point; physical-device verification not performed |

The project uses the standard APK exporter, not a custom Gradle build. It therefore does not compile
native templates or require the NDK. JDK 17 is preferred over the separately installed JDK 21.
The renderer is Godot Compatibility (OpenGL ES 3 on Android). The standard Godot 4.7.2 template
declares Android 7.0/API 24+ and target SDK 36, package `com.portfolio.chromaticrush`, version
`1.0.0`, code `1`. SDK overrides require the Gradle exporter; they are intentionally left blank.

### Reproducibility

`scripts/bootstrap.ps1` downloads the pinned engine and required export templates from the official
Godot GitHub release and checks pinned SHA512 digests. It enables Godot's supported self-contained
mode, so build settings and generated debug keys stay beside this tool installation, outside Git.
`scripts/build.ps1` sets SDK paths in that isolated profile, imports resources, exports requested
targets, checks files exist and writes SHA256 sidecars. A successful export does not prove a launch;
runtime evidence is recorded in this guide's test and Android sections.

Godot's Android export can stop the ADB server. If the emulator vanishes from `adb devices` after a
build, run `adb start-server` and wait a few seconds; the emulator reconnects without a restart.

Godot portable engine archive SHA512:

```text
83DECD58FDF67B9D657958A1AE6BF1929C20785315A81EFFE245874CDC57ACB709BF868E00778A96984338C1B29DAFDB453C6847747694621C6ECF5DA2259993
```

Godot export templates archive SHA512:

```text
CA4D71C4D7B81DFC15D1A98BAA07534AA95B03FDDA78A0075B06672E1648D2E5F40980C9ADC28D23E1B92E732EE7BF3461997AA804AF74EC2FCD7A93CCB84079
```

Sources checked 2026-11-03:

- [Godot Windows download](https://godotengine.org/download/windows/)
- [Official 4.7.2 release and SHA512 manifest](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)
- [Android export requirements](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Command line exports](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- [Self-contained editor implementation](https://github.com/godotengine/godot/blob/4.7-stable/editor/file_system/editor_paths.cpp)

The official Android guide recommends build-tools 35.0.1. That exact version is not installed; the
exports in this repository were signed and verified with build-tools 36.0.0 (`apksigner`, `aapt2`),
and the resulting APK installed and ran on the Android 35 emulator.

## Tests and runtime verification

### Automated checks actually run

`scripts/check.ps1` exits 0: forty GDScript development/test files pass formatting/lint, every
Python script passes compilation, ten worlds/100 distinct layouts/486 stages validate, and the
Godot import passes. Temporary visual probes are excluded from the source archive.

`scripts/test.ps1` exits 0 with twelve native suites:

| Suite | Checks | Failures |
|---|---:|---:|
| Large text/accessibility | 460 | 0 |
| Effects/adaptive budget | 18 | 0 |
| Gate rules | 47,643 | 0 |
| All-level input replay | 2,358 | 0 |
| Actual runtime route search | 1,588 | 0 |
| Run simulation | 59 | 0 |
| Real-file saves | 158 | 0 |
| Graceful shutdown | 8 | 0 |
| Audio state | 15 | 0 |
| UI integration | 323 | 0 |
| UI failure paths | 24 | 0 |
| Every-world journeys | 43 | 0 |
| **Total sampled assertions** | **52,697** | **0** |

The search examined 21,132 candidates and completed all 100 authored routes. Successful schedules
replay at 30/60/120 simulated FPS. Assertion counts are not source coverage or rendered FPS.
Evidence: `builds/logs/test_*.log`, `docs/evidence/route_audit.json` and `builds/logs/level-structure.log`.

The rendered accessibility suite passes 473 checks and saves thirteen images. Rendered UI
integration passes 356 checks with eighteen images; rendered every-world practice journeys pass
63 checks with twenty images. No automated journey is labeled human playtesting. Original user
records are kept separate from test fixtures.

`scripts/quality.ps1` exits 0 with all production scripts included, no collector omissions or
production exclusions. Unique planned source-line coverage is 94.69%, branch coverage 90.84%,
and mixed tracking-point coverage 92.90%. Exact-token duplication is 0%; focused source scanning
finds no flagged pattern. Independent function/statement metrics and SonarQube are unsupported;
see [Quality gates](#quality-gates).

### Runtime and responsive matrix

| Case | Runtime | Steps | Expected | Actual | Result / evidence |
|---|---|---|---|---|---|
| Small/portrait/landscape menus | Windows Godot | Capture 320x600, 480x900, 900x480 | Usable controls, no tested overlaps | Checks pass | PASS, `ui-*.png` |
| Large text | Native renderer | Toggle, scroll, use menus and real clear/Next | Saved 200% reflow, unchanged rules | 473 checks pass | PASS, `large-*.png` |
| Large text exported UI | Windows EXE | Click setting, scroll, disable | Operable native controls | Observed | PASS, computer-use inspection |
| Continue and pause | Windows EXE | Continue then Escape | Arena then pause | Observed | PASS, computer-use inspection |
| Representative route in every world | Native renderer | Replay real practice inputs | Play/complete each world | 10 worlds complete | PASS, `world_smoke.json` |
| Signed install/launch | Android 35 x86_64 host GPU | Install, start launcher | Actual menu renders | 1,374 ms launch, menu inspected | PASS, `signed-home.png` |
| Signed direct touch / Back | Same AVD | Tap arena, Back, Back | Tap increments, pause/resume | One tap, same PID, pause/resume | PASS, `signed-pause.png`, `signed-resume.png` |
| Offline checkpoint relaunch | Same AVD | Airplane, force-stop, launch, Continue | Saved cumulative time restored | 48.6 seconds, 942 ms launch | PASS, `signed-offline.png` |
| Signed large text / reinstall | Same AVD | Enable text, reinstall identical APK, launch | Setting retained | Enlarged home retained | PASS, `signed-large-settings.png`, `signed-reinstall-large.png` |
| Legacy software emulator renderer | Same AVD, SwiftShader indirect | Launch identical signed APK | Menu renders | Blank canvas, uniform error | FAIL for this backend; host GPU resolves it |
| Physical phone/audio/haptics/FPS | None | Owner opted out | Hardware verification | Not performed | SKIPPED |
| TalkBack/Narrator and human balancing | Not performed | Real user evaluation | Usable assistive flow and difficulty | Not established | NOT TESTED |

Android screenshots and exact APK/certificate hashes are in RELEASE.md and
`docs/evidence/signed_android_smoke.json`. The tested AVD was dedicated to this project. Airplane
mode was restored to 0; the crash buffer was empty. The legacy SwiftShader failure is not hidden:
`builds/logs/signed-render-before.log` records it; `signed-render-host.log` records the successful
unchanged APK with the host renderer. No physical GPU compatibility result is inferred.

The Windows helper exposed only the window frame in its accessibility tree. Screen-driven clicks
worked, but semantic labels in code do not establish screen-reader conformance. See [Accessibility verification](#accessibility-verification).

### Extracted-source verification

The recorded source archive was extracted into a new directory with fresh lint and measurement
environments. Check, all twelve suites, rendered quality gates, Windows export, signed release
export and debug export passed. At that verification, 117 production/build/test files matched
the working source byte-for-byte. This host still shared its installed Godot/JDK/SDK; the result
does not establish an independent clean machine or hosted CI run.

Results: `docs/evidence/fresh_copy_20261105.json`, `builds/logs/fresh-copy-20261105-result.json`
and `builds/logs/fresh-copy-20261105/`. Subsequent documentation consolidation changes guide paths
and one quality-command help message, not gameplay or the delivered binaries. Repackaging and
`audit_release.py` verify the current archive against current source bytes and artifact sidecars.

## Accessibility verification

```powershell
& $env:GODOT_BIN --headless --path . --script res://tests/test_accessibility.gd
& $env:GODOT_BIN --path . --script res://tests/test_accessibility.gd -- --capture
```

The native suite passed 460 behavior/layout/contrast checks headlessly and 473 checks with thirteen
rendered captures. It verifies real setting persistence, operational proxies, locks, pause/resume,
retry and a production-input level clear/unlock. Layouts include 320x600, 480x900 and 900x480.
Text tokens exceed 4.5:1 against the tested native surface and all ten world gradient endpoints.
This token check does not measure every composited pixel, hover state or game effect.

The exported Windows build was also inspected with real clicks and scrolling: enabling Large text
reflowed settings, scrolling reached its toggle, and disabling it restored standard text. Escape
returned home, Continue entered the arena, and Escape opened pause. The Windows automation helper
exposed the native window frame but no game controls in its accessibility tree; these actions used
the rendered screen. Semantic properties in code are not proof of screen-reader interoperability.

Screenshots are `docs/evidence/large-*.png`. The fixed logical portrait frame scales within
landscape windows; it does not become a landscape-native game layout.

Screen-reader, automatic OS font scaling and hardware limits are listed below.

## Quality gates

Measured on 2026-11-05 using the delivered production scripts, Godot 4.7.2 and
`gd-tools-cli==0.10.0`. Run the full behavior suite before this gate:

```powershell
.\scripts\check.ps1
.\scripts\test.ps1
.\scripts\quality.ps1
```

The quality command installs the exact tools in `scripts/quality-requirements.lock` into an
isolated `.tools/quality/venv`, checks dependency consistency, scans source boundaries and measures
rendered coverage. No collector or instrumented script is included in the game.

### Observed results

| Check | Result | Required gate |
|---|---:|---:|
| Unique planned executable source lines | 2,017 / 2,130 = 94.69% | >=90% |
| Collector statement/branch tracking points (`line_rate`) | 2,460 / 2,648 = 92.90% | >=90% |
| Branch points, including boolean and ternary arms | 853 / 939 = 90.84% | >=90% |
| Exact-token duplicated production code | 0 / 2,922 code lines = 0% | <=3% |
| High-confidence source pattern findings | 0 | 0 unreviewed findings |
| Collector omissions / production exclusions | 0 / 0 | 0 |

The first complete diagnostic run also passed (94.74% unique lines and 91.16% branches).
Render/focus callbacks vary slightly with native scheduling; the table records the later complete
`quality.ps1` run. Both retained the same production hashes and thresholds.

### Measurement boundaries

Every one of the 21 `src/**/*.gd` files must appear in the plan. Source hashes are compared after
measurement, and an omitted or excluded production target fails the command. The collector runs
in a disposable project copy. It traces the normal behavior suites, rendered UI and every-world
journeys. Coverage uses `test_quality_routes.gd` to replay all successful schedules; the expensive
route search still runs in the separate mandatory `test.ps1` command. Drawing callbacks are measured
by the real native renderer, rather than marked covered by a headless run.

The collector's `line_rate` denominator mixes statement and branch tracking points. This project
therefore also gates unique planned source lines. It does **not** report independent function or
statement coverage. Those two parts of the requested four-metric gate remain unsupported, and
neither assertion counts nor the mixed tracking-point rate are presented as substitutes.

Evidence: `docs/evidence/quality-coverage.json` contains scope, metrics, per-file results and source
hashes. `builds/coverage/coverage.info` and `builds/logs/quality-*.log` contain local output. Individual
collector traces remain in the ignored workspace identified in the report.

### Static review scope and compatibility exception

SonarSource's [supported-language inventory](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/languages/overview)
does not list GDScript (checked 2026-11-05). This is a tool compatibility exception, not a passed
SonarQube gate. No Sonar security-hotspot status or unsupported rule result is claimed.

`quality_static.py` checks selected private-key/token patterns and runtime execution/network
boundaries, and measures exact lexical clones of at least 100 tokens across ten lines. Four
positive/negative controls validate the scanner. It does not normalize renamed identifiers or
literals, and is not a complete vulnerability assessment. The real-file save tests separately
exercise bounded inputs, malformed data, migration, backup recovery and write failure. Release
payload audits reject signing material and unexpected development files.

The CI workflow now invokes these same gates and uploads the reports. Remote CI execution has
not occurred; configuration is not evidence of a successful hosted run.

## Balancing and performance

Measured 2026-11-05 with the production Godot 4.7.2 `RunState`, authored registry and actual native
renderer. This is tool-assisted timing analysis and desktop performance evidence. It does not claim
human playtesting, physical touch latency, vibration/audio output or midrange Android performance.

### Reproduce

```powershell
.\scripts\balance.ps1
.\scripts\balance.ps1 -RenderBenchmark -Stress
```

The scripts use the pinned Godot location or `GODOT_BIN`. They require the normal completed
`docs/evidence/route_audit.json`; run `scripts/test.ps1` first if it is missing. Optional scripts are
outside the automatic `test_*.gd` suite because native rendering and quantitative sampling take
longer than behavior tests. They use isolated saves and never award standard progress.

Equivalent commands executed during this assessment:

```powershell
& $env:GODOT_BIN --headless --path . --script res://tests/balance_routes.gd
& $env:GODOT_BIN --headless --path . --script res://tests/balance_precision.gd
& $env:GODOT_BIN --path . --script res://tests/benchmark_render.gd -- --stress
```

Reports: `docs/evidence/balance_routes.json`, `balance_precision.json` and
`balance_render_benchmark.json`. These contain exact schedules, seeds, per-level results, world
summaries and measured render samples. Test tooling and added effect tests passed formatting/lint.

### Input robustness

All 100 baseline schedules still complete using production tap, cooldown, collision, pulse and
chain rules. Each replay uses a 120 Hz simulation; time advances in small steps even while waiting,
so the production half-second catch-up cap cannot silently shorten a wait.

For each level, the audit perturbs the earliest-success schedule with:

- A uniform early or late shift of every tap.
- Alternating early/late tap errors in both starting directions.
- Ten independent deterministic uniform-noise sequences, seeded by level ID and trial index.
- One omitted middle tap, followed by actual checkpoint retry and a new matching route search.

Negative tap times clamp to zero, and perturbed events sort into actual timestamp order before replay.
Inputs closer than the production 100 ms cooldown are naturally
rejected; the audit does not bypass that rule. These are full-route success counts, not per-tap
accuracy or player success probabilities.

| Jitter amplitude | Uniform shift, 200 trials | Alternating error, 200 trials | Independent error, 1,000 trials |
|---|---:|---:|---:|
| ±25 ms | 97 (48.5%) | 89 (44.5%) | 316 (31.6%) |
| ±50 ms | 89 (44.5%) | 66 (33.0%) | 184 (18.4%) |
| ±100 ms | 83 (41.5%) | 12 (6.0%) | 122 (12.2%) |

The baseline search intentionally chooses the earliest successful launches, often next to a color
boundary. Perturbing that schedule is deliberately stringent and is not evidence that every safe
launch window is that narrow. To distinguish boundary scheduling from authored difficulty, a second
search chooses stage launches that survive the signed tolerance and six interior quarter steps.
Repeat taps retain the exact 225 ms cadence; only that stage's launch phase shifts.

- 98 of 100 levels have a complete route with at least ±100 ms sampled launch-phase tolerance at
  every stage.
- Level 97, stage 4, and level 100, stage 5, are the two exceptions, both fast pendulums in the final
  world. Focused searches find complete routes for both at ±75 ms, ±50 ms and ±25 ms.
- Removing the middle tap still completes 70 routes. Another 26 collide, and four remain unfinished
  at the replay deadline. Checkpoint retry and matching-route search recover all 100, preserving
  earned checkpoint/color and elapsed time, tap count and failure count in every case.

These results support retaining the authored endgame precision distinction. No level parameters
were changed merely to make a timing metric pass. The optional 70% slow-time assist increases the
wall-clock time available to observe windows and records its results separately. Human difficulty
and accessibility-user feedback remain separate acceptance evidence.

### Progression and stars

| World | Mean stages | Mean par, seconds | Mean searched clear, seconds |
|---|---:|---:|---:|
| First Light | 3.8 | 42.0 | 7.12 |
| Tidal Circuit | 4.2 | 48.6 | 8.95 |
| Prism Orchard | 4.5 | 52.5 | 6.66 |
| Pulse Foundry | 4.5 | 55.9 | 9.92 |
| Glass Relay | 4.5 | 58.9 | 10.01 |
| Inverse Sky | 4.5 | 59.2 | 8.53 |
| Ember Archive | 5.0 | 63.4 | 8.78 |
| Ion Cathedral | 5.3 | 66.6 | 9.57 |
| Velvet Paradox | 5.8 | 69.7 | 9.31 |
| White Horizon | 6.5 | 74.3 | 9.03 |

Every zero-failure searched baseline earns three stars under the authored par. These are highly
optimized machine schedules, not a target human time. Mean route length and par allowance increase
through the campaign while mechanic combinations add the primary challenge. The analysis does not
justify reducing the par limits to machine-optimal times.

### Effects and render benchmark

The 18 focused effects checks cover sustained-frame hysteresis, immediate budget trimming,
recovery and reduced motion. The actual resource caps and algorithm are documented once in
[the rendering architecture](ARCHITECTURE.md#13-rendering-sound-and-accessibility).



The benchmark renders the actual `App` at 480×900 on Windows with the Compatibility renderer,
normal controlled taps, retries and all ten world backgrounds. The `--stress` option continuously
fills the bounded feedback queues to measure a deliberately heavy presentation. Each world warms
for 0.35 seconds and measures two seconds of actual frame completion timestamps; the total sampling
window is approximately 20 seconds. It reports wall-time FPS, median/95th-percentile frame duration,
peak draw calls and effect counts. These are rendered frames, not fixed-step simulation FPS.

The initial run on an AMD Radeon 780M measured 1,197 completed frames in 20.034691 seconds, aggregate
59.75 FPS. The slowest world's 95th-percentile frame was 18.828 ms; full-budget stress reached
90 sparks and 28 shards. A balance CPU search was running concurrently, so this records that host
under load. The JSON report is the measurement record for this host and workload.

This desktop result cannot establish 60 FPS on a midrange Android phone, thermal stability,
battery cost or physical touch latency. Those require the intended physical device.

## Feature acceptance

| Specification item | Implementation | Verification / remaining gate |
|---|---|---|
| Tap to propel an orb | Immediate impulse, repeated air taps, 100 ms input cooldown | Headless input/cooldown and native input integration; physical latency unmeasured |
| Matching moving color contacts | Shared gate sampler and swept, interpolated collision time | Correct/wrong colors, 30/60/120 FPS replay and large-delta rejection pass |
| 10 themed worlds | Ten named chapters with original palettes, geometry motifs and authored progression | Registry validated; world backgrounds visible in `docs/evidence/ui-*.png` |
| 100 individually authored levels | 100 named layouts, 486 explicit stages, no generated runtime copies | IDs/names/layout signatures validated; all 100 actual simulation routes complete |
| Distinct verified routes | Explicit kind/gap/speed/phase/offset/switch/checkpoint combinations | Saved tap schedules replay all levels; human balancing remains incomplete |
| Rotating rings | Moving quarter arcs and shared contact-angle sampling | Gate rules and complete-route search pass |
| Pendulums | Oscillating band with swinging visual support and authored drift | Sampler/route coverage pass; human tuning not performed |
| Moving gates | Sliding four-color bands | Matching and route search pass |
| Color switches | Match the gate, then adopt its authored next identity | Switch/checkpoint/retry tests pass |
| Reverse gravity | Mirrored descending field and input direction, restored on next stage | Direction/state tests and level routes pass; reverse stage captured at three sizes; no physical-device test |
| Timed pulses | Authored duty window plus matching-color requirement | All pulse-containing routes complete; no audio dependence |
| Multi-stage chains | Two independent contacts separated by 54 logical units | First contact alone cannot finish; second mismatch independently fails |
| Gradual mechanic introduction | Rings/slides, pendulums, switches, pulses, chains, reverse fields, combinations | Documented level bible and explicit content audit |
| Touch, mouse and keyboard | Playfield/action button, Space; menu focus and Enter | UI suite (keyboard, mouse, transformed touch) and emulator touch pass; physical touch latency unmeasured |
| Haptic feedback | Android vibration adapter with saved toggle | Permission configured; real vibration strength/availability untested |
| Audio feedback and themes | Original synthesized tap/clear/fail/complete tones and world pitch/tempo variants | Engine synthesis implemented; not listened to on a physical device |
| Visual feedback and particles | Orb/gate states, bounded sparks/shards/rings/trail, world motifs | Adaptive 90/30-spark budgets and hysteresis tests pass; native stress benchmark and captures in RELEASE.md#balancing-and-performance |
| Pause/retry/continue | Pause overlay, checkpoint retry, fresh restart, next route and app-focus pause | Domain tests and UI integration; emulator Back pauses/resumes and exits from home; no physical background matrix |
| Locked/unlocked level selection | Sequential standard unlocks; practice opens all levels | Save tests cover initial state, progression and bounds |
| Stars, best score and completion time | Independent personal best fields and completion count | Score/star boundaries and save merge tests pass |
| Checkpoint behavior | Authored checkpoints retain color and run statistics; saved on progress/pause/failure | Snapshot/retry and real-file persistence tests pass |
| Original transitions/backgrounds | Native button states, menu drift, stage feedback and layered geometric world backgrounds | Native visual review; reduced-motion option preserves timing information |
| Optional shaders only when performant | No shader dependency; original CanvasItem geometry | Static implementation; no shader performance claim needed |
| Practice mode | All 100 routes available; separate records | Cannot change standard unlocks/achievements in integration tests |
| Assist settings | Matching-window guide and 70% slow time | Explicit assisted mode, separate record collection; slow-time test passes |
| Offline saves | Private local JSON with bounded parsing, temporary replacement and backup | Real-file roundtrip, corrupt-primary recovery and failed-write tests pass |
| Resilient migration | V1 unlocked progress/settings migrate to V2 | Legacy times remain unknown; no invented stars; migration tests pass |
| Achievements | Seven clear/star milestones based on standard records | Threshold and practice-isolation tests pass |
| Audio/haptic/reduced-motion settings | Saved toggles; decorative movement/particles can be disabled | Settings persistence tested; supported OS reduce-animation requests are honored |
| Color-independent cues | Named identities, numbers and shape markers enabled by default | Implemented and contrast-checked in the UI suite; no color-vision or screen-reader user evaluation |
| Dark/light themes where relevant | Ten intentional dark world palettes; no light theme exists or is offered | Dark-only by design. The save schema carries an unused `light_theme` default for compatibility; it has no UI |
| Deterministic registry/editor tooling | Explicit JSON schema, Python validator and actual-physics route harness | No graphical level editor; edit JSON and run both validators |
| 60 FPS Android target | Compatibility renderer, adaptive bounded effects, lightweight geometry, 120 Hz simulation | Midrange physical-device FPS/battery/thermal target unverified |
| Responsive portrait and desktop | Centered 480×900 logical arena with window scaling | Captured at 480×900, 320×600 and 900×480; no physical cutout check |
| Semantic controls and accessibility | Native buttons/toggles, explicit focus flow, accessible names, saved 200% scrolling menus/HUD | 460 native checks plus 13 rendered captures; screen-reader and OS font scaling remain untested |
| Error/empty/first-run states | No-record and locked states; save warnings, corruption recovery, reset confirmation | Save failure and first-run tests pass; native presentation covered by the UI suite |
| Background/foreground/app updates | Focus-loss pause/audio suspension; versioned save migration | Hardware lifecycle/update-install testing incomplete |
| No unnecessary accounts/network | No server, auth, telemetry, advertising or external API | No online degradation needed; permission/artifact audit recorded at release |
| Privacy and permissions | Private results/settings; vibration only in export preset; cloud backup disabled | No secrets in project; manifest audit in RELEASE.md (VIBRATE only) |
| Structured errors/observability | Error return codes, persistent user warning, JSON test/audit output | No remote telemetry or production diagnostics service |
| Static checks and formatting | Native GDScript import, pinned gdtoolkit, independent schema validator | `check.ps1 -Format` passes on the final source (see RELEASE.md#tests-and-runtime-verification) |
| Unit and real-boundary integration tests | Gate/run tests and real local-file save tests | No backend/DB exists; no fake network endpoint is used |
| All-level automated audit | 100 successful input schedules plus 30/60/120 FPS replays | Structural tests alone are not used as solvability proof |
| Representative manual play per world | Required as a separate acceptance gate | Not established by the headless route search; no per-world human playtest was run |
| ≥90% four-metric source coverage | All 21 production scripts instrumented in a disposable native project | 94.69% unique planned lines, 90.84% branches; independent function/statement metrics unsupported |
| SonarQube gate / hotspot review | No supported SonarSource GDScript analyzer | Compatibility exception; independent pattern/duplication checks pass within documented scope |
| CI checks/build/artifacts | Windows workflow for bootstrap, check, tests, exports and uploads | Configuration supplied; remote CI run is not claimed |
| Android debug APK | Reproducible native export preset and build script | Rebuilt and signature-verified; signed release exercised on Android 35 emulator; hashes in RELEASE.md |
| Private signed Android release path | Dedicated private RSA 3072-bit key; no signing material in packages | Signed APK built, v2/v3 verified, installed and exercised offline; store publication not performed |
| Windows release preview | Embedded-pack executable export; unsigned | Built and launched; hash in RELEASE.md; unsigned |
| Documentation/bootstrap/fresh clone | README, architecture, design, level bible, tests, release and limits | Independent clean-machine replay remains unverified (see RELEASE.md#tests-and-runtime-verification for the extracted-copy run) |
| Git milestone commits | New isolated repository initialized | Commits intentionally unmade under the universal no-automatic-commit rule |

No cloud integration, health endpoint, account onboarding, chart, external API contract or backend
database is required for this offline game. Their omission is an explicit architectural choice.

## Known limitations

The signed APK is ready for private sideloading/portfolio review. These are explicit boundaries
of the evidence above, not passed checks inferred from a successful export.

| Area | Remaining boundary |
|---|---|
| Physical Android hardware | The owner chose to finish without a phone. Touch latency, audio listening, vibration strength/availability, cutouts, rotation/lifecycle, storage exhaustion, thermal/battery behavior and midrange 60 FPS were not tested. |
| Human usability and difficulty | All 100 routes complete in simulation, but human playtests in every world, accessibility-user feedback and extended soak testing remain open. Sampled timing tolerance is not a human success rate. |
| Assistive technology | No WCAG conformance or complete TalkBack/Narrator gameplay claim. Switch access, automatic OS font scaling and full composited-screen contrast are untested; large text is an explicit app setting. |
| Presentation | The arena remains portrait inside a landscape window. Ten dark palettes are implemented; there is no light theme. Music varies an original synthesized phrase rather than ten recorded compositions. |
| Analysis tools | Source-line/branch gates pass. Independent function/statement metrics are unsupported. Pattern/exact-token checks are bounded tools, not a complete vulnerability assessment or SonarQube hotspot review. |
| Infrastructure verification | Hosted CI, an independent clean machine and physical cross-version Android migration have not run. Same-version signed reinstall is not a migration test. |
| Engine import | Cold-cache Godot imports have intermittently crashed silently on this host. Check/test/build retry only silent imports up to three times; diagnosed script errors and tests are never retried. |
| GPU and visuals | Legacy emulator `swiftshader_indirect` failed shader linking; the same APK rendered with `-gpu host`. Phone GPU compatibility is untested. Screenshots are inspected evidence, not a screenshot-diff regression suite. |
| Save durability | Backup recovery can lose the latest write. Phone storage exhaustion, sudden power loss and filesystem-specific replacement atomicity were not tested. Progress is local, unencrypted and editable; uninstall removes it, cloud backup is disabled, and there is no sync/export/import recovery UI. |
| Hardware capability | A saved haptic preference requests platform vibration; no separate hardware capability indicator is provided. |
| Signing and publication | Preserve the external release key/password for updates. Debug/release signatures differ. Google Play AAB/publication, Windows code signing and installer packaging were not performed. |
| Targets and reproducibility | Android ARM64/x86_64 only, min SDK 24/target 36; no ARMv7/TV target. Windows scripts are verified; equivalent macOS/Linux automation is not. Rebuilt binary hashes can differ. An unused template themed-icon alias still warns in `aapt2`. |
| Repository history | No automatic commits, branches or pushes were made during the recorded implementation. Local artifacts and workflow configuration do not establish remote hosting or completed hosted CI. |

Historical `android-release-*` captures and `android_release_smoke.json` identify an older debug
APK. Current signed-runtime evidence is `signed-*` plus `signed_android_smoke.json`. JSON evidence,
screenshots and diagrams are retained so consolidating prose does not discard verification data.

## Documentation consolidation

On 2026-11-05, overlapping design, compatibility, accessibility, balancing, coverage, feature,
test and limitation notes were merged into the four guides linked from the README. Original
design intent now lives in Architecture section 19; all release/verification boundaries live here.
Removed guide paths were updated in prose and the quality-command help message. Validation for
this documentation change checks Markdown links/anchors, all eleven diagram assets, PowerShell
syntax and the regenerated source archive; it does not claim a new gameplay test run.
