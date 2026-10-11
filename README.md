![purplerepo](assets/banner.png)

# purplerepo

A small Cydia/Sileo repo of jailbreak **tweaks** and **icon themes** for **iOS 12** (rootful, arm64).
Everything here is written by [purplesquarecube](https://github.com/purplesquarecube).

**Repo address**

```
https://purplesquarecube.github.io/purplerepo/
```

Open the [website](https://purplesquarecube.github.io/purplerepo/) on your iPhone for one-tap buttons, or add the address by hand:

| Package manager | How |
| --- | --- |
| Sileo | Sources > + (top right) > paste the address |
| Zebra | Sources > + > paste the address |
| Cydia | Sources > Edit > Add > paste the address |

Pull down to refresh the source, then install.

## Tweaks

| Name | Version | What it does | Where |
| --- | --- | --- | --- |
| **Tidy** | 1.0.0 | Clean up the Home Screen. Hide icon labels, notification badges and page dots, or make the dock background clear. Changes apply instantly. | Settings > Tidy |
| **TapLock** | 1.0.0 | Double-tap to lock. Double-tap an empty spot on the Home Screen or Dock to lock your device, so you never have to reach for the power button. | Settings > TapLock |
| **QuietHUD** | 1.0.0 | No more pop-ups. Hide the volume, brightness, ringer and rotation-lock pop-ups. The change still happens, you just don't see the overlay. | Settings > QuietHUD |
| **TapFeel** | 1.0.0 | Icons that answer back. Play a sound and bounce the icon when you tap an app. Pick from six system sounds and set how bouncy it is. | Settings > TapFeel |
| **BatteryLine** | 1.0.0 | A battery meter you can see in any app. A thin line along the top or bottom of the screen that shows your battery level on top of every app. Turns green while charging, orange under 50% and red under 20%. | Settings > BatteryLine |
| **AppTunes** | 2.0.0 | A different song in every app. Import your own MP3s and choose a song for each app. It plays while that app is open and stops when you leave. | Settings > AppTunes |
| **LaunchFX** | 1.0.0 | 50 ways to open an app. Pick one of 50 opening effects (iris shapes, wipes, curtains, blinds, tile dissolves and more). Preview them right in Settings. | Settings > LaunchFX |
| **Liquid Glass** | 1.0.0 | A glass look for iOS 12. Bright glass edges, a soft shine and a highlight that moves as you tilt the phone. Works on the Dock, folders, notifications and Control Center. | Settings > Liquid Glass |

Every tweak adds its own page to the Settings app (they depend on PreferenceLoader, which Sileo installs for you).

## Themes

Icon themes for Snowboard or Anemone. Covers the stock Apple apps plus Sileo, Zebra, Cydia and Filza. Apps without an icon here keep their normal one.

Install a theme, open **Snowboard** (or **Anemone**), tick the theme and apply it.

### Violet
Deep violet squares with solid white glyphs.

![Violet](assets/theme-violet.png)

### Mono
Near-black with thin white line art and a single colour dot.

![Mono](assets/theme-mono.png)

### Paper
Warm cream stock with ink glyphs on an offset colour print.

![Paper](assets/theme-paper.png)

### Neon
Glowing tube-light outlines on midnight blue.

![Neon](assets/theme-neon.png)

### Frost
Frosted pale glass with tinted, softly lit glyphs.

![Frost](assets/theme-frost.png)

## Requirements

- iOS 12.0 to 12.5.8, jailbroken, arm64 (iPhone 5s and later)
- A rootful jailbreak such as checkra1n, unc0ver or Chimera
- Substrate or Substitute, and PreferenceLoader (installed automatically)

## Troubleshooting

- **A package doesn't show up in Sileo.** Pull down on the Sources tab to refresh. If it still isn't there, remove the source and add it again. GitHub Pages can cache the package list for a few minutes after an update.
- **A tweak has no entry in Settings.** Make sure PreferenceLoader is installed, then respring.
- **Something looks wrong after installing a tweak.** Turn that tweak's switches off in Settings. If SpringBoard won't load, use safe mode from your jailbreak app.
- **A theme isn't applied.** Themes need Snowboard or Anemone. Respring after applying.

These tweaks are provided as-is and were written for fun. Back up before you try anything new.

## Source

The tweaks are plain Objective-C, built with clang against the iOS 12 SDK. Everything needed to rebuild the repo is in [`src/`](src):

- `src/tweaks/` the tweaks (`Tweak.m` hooks SpringBoard, `Prefs.m` is the Settings page)
- `src/common/` shared helpers
- `src/art.py`, `src/themes.py` the logo, icons and theme generators (Python, Pillow)
- `src/build.py`, `src/assemble.py` build the `.deb` files and this repo folder

## Layout

```
debs/         .deb packages
icons/        package icons shown in Sileo
depictions/   Sileo package pages (JSON)
assets/       logo, banner and theme previews
Release, Packages, Packages.bz2, Packages.gz   what the package managers read
index.html    the website
```
