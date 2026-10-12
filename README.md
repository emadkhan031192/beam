# Beam — a fast, ad-free flashlight

Flutter UI + native Kotlin torch layer. No ads, no account, no internet
permission. The torch uses `CameraManager.setTorchMode()`, which needs no
camera permission.

Package: `com.afzal.beam` · version 1.0.0+1 · Android only (minSdk 24,
targetSdk 35).

## Project layout

```
lib/
  main.dart                    # cold start: torch channel only, then runApp
  core/
    theme.dart                 # design tokens, PressScale, SectionLabel
    beam_icons.dart            # 1.5px stroke icon set
    channels.dart              # TorchApi (MethodChannel + EventChannels)
    settings.dart              # SharedPreferences repo + Riverpod providers
    models.dart                # TorchMode/State, level mapping, SOS pattern
  features/
    torch/                     # torch screen + controller (tick ring, glow, bars)
    strobe/                    # strobe & SOS screen
    screen_light/              # full-screen color light + control sheet
    settings/                  # settings screen
android/app/src/main/kotlin/com/afzal/beam/
  TorchManager.kt              # camera torch, strobe/SOS threads, notifications
  MainActivity.kt              # channels, battery stream, shortcut fast-path
  BeamTileService.kt           # Quick Settings tile
  ShakeService.kt              # shake-to-toggle foreground service
  TorchActionReceiver.kt       # notification actions
test/                          # unit tests (mapping, SOS pattern, settings)
```

## Adding release-signing secrets

Add these four repository secrets (Settings → Secrets → Actions):

| Secret             | Value                                              |
|--------------------|----------------------------------------------------|
| `KEYSTORE_BASE64`  | `base64 -w0 your-release.jks` output               |
| `KEYSTORE_PASSWORD`| keystore password                                  |
| `KEY_ALIAS`        | key alias                                          |
| `KEY_PASSWORD`     | key password                                       |

If any secret is missing, the Gradle build signs the release with the debug
key instead, so CI never fails. (Debug-signed APKs can't go to the Play
Store — add the secrets before a store release.)

> Status 2026-10-11: a dedicated Beam upload keystore (`beam`, RSA 2048)
> was generated and all four secrets are already configured, so CI builds
> are release-signed. A backup of the keystore is kept outside the repo —
> keep the passwords in a password manager; losing the upload key means a
> new Play Store app listing.

## Changing the app name and icon

- **Name:** `android:label` in
  `android/app/src/main/AndroidManifest.xml`, and the `title` in
  `lib/main.dart` (`MaterialApp`).
- **Icon:** replace the PNGs in
  `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/`
  (`ic_launcher.png`, `ic_launcher_round.png`). The manifest already points at
  `@mipmap/ic_launcher`.
- **Package:** rename `com.afzal.beam` in `android/app/build.gradle`
  (`namespace`, `applicationId`), the Kotlin `package` lines, and the
  channel names in `lib/core/channels.dart` + `MainActivity.kt`.

## Manual test checklist

- [ ] **Cold start:** force-stop the app, enable “Light on when Beam opens”,
      launch — the torch should light effectively instantly (well under 300 ms
      of UI time; the native call happens before the first frame).
- [ ] **Tile:** add the “Beam” Quick Settings tile, toggle it — the torch
      flips without opening the app, and the tile state follows the real torch
      (e.g. turn the torch on in-app, the tile shows active). Long-press the
      tile — the app opens.
- [ ] **Shake:** enable “Shake to toggle”, grant the notification permission,
      two quick shakes toggle the light. “Turn off shake” in the notification
      stops the service.
- [ ] **Strobe stops:** start strobe, then press back / background the app /
      tap the Torch power button — flashing stops immediately every time.
- [ ] **Strobe warning:** first strobe shows the epilepsy confirmation; the
      warning line stays visible at the bottom even with “Strobe warning” off.
- [ ] **Camera-in-use conflict:** open the system camera, then try Beam — the
      UI turns off and shows “Camera in use by another app”.
- [ ] **No-flash device:** on a device without a flash, only the Screen light
      tab appears, with the explanation card.
- [ ] **Auto-off:** set 5 minutes, turn the torch on, check the quiet
      “Flashlight is on” notification with its “Turn off” action.
- [ ] **No accidents:** swipe the app away while the torch is on — it turns
      off (unless it was started from the tile/shake/notification).

## Simplified / not supported

- **1×1 home-screen widget:** skipped, as the spec allows — a widget that
  can't reliably reflect torch state is worse than none.
- **Heat warning is time-based, not thermal-sensor based:** after 10 minutes
  at max brightness the app shows “The flash can get hot. Give it a rest.”
  Reading the thermal sensor would need extra permissions and varies by
  device; time-at-max is the reliable proxy.
- **Shake with the screen off:** some phones stop sensor delivery when the
  screen is off. The settings screen says this plainly and links to the
  battery-optimisation page instead of claiming it works everywhere.
- **Brightness steps:** on API < 33 or when the device reports a max strength
  of 1, the bars are disabled with “Brightness steps aren't supported on this
  phone” — the hardware simply has no API for it.
- **Battery:** `battery_plus` was intentionally not used; the battery percent
  comes from the sticky `ACTION_BATTERY_CHANGED` broadcast over an
  EventChannel (no extra dependency, no polling).
- **APK size:** the < 8 MB-per-ABI target is not achievable with Flutter:
  release APKs (R8 + resource shrinking, split per ABI) measure
  arm64-v8a 17.5 MB, armeabi-v7a 14.9 MB, x86_64 19.0 MB. The Flutter engine
  (`libflutter.so`, ~11.7 MB uncompressed per ABI) plus Dart AOT (~4 MB) set
  the floor; fonts add ~1.2 MB. An 8 MB target would need a fully native
  (non-Flutter) app.
