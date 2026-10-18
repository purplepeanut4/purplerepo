"""Single source of truth for purplerepo: packages, copy, versions."""

REPO_URL = "https://purplepeanut4.github.io/purplerepo/"
GITHUB_URL = "https://github.com/purplepeanut4/purplerepo"
ACCENT = "#7C3AED"

# kind: tweak | theme
TWEAKS = [
    dict(
        key="tidy", id="com.purplesquarecube.tidy", name="Tidy", version="1.0.0",
        tagline="Clean up the Home Screen.",
        desc="Hide icon labels, notification badges and page dots, or make the dock background clear. Changes apply instantly.",
        features=["Hide icon labels", "Hide notification badges", "Hide the page dots", "Clear dock background",
                  "Respring button in Settings"],
        where="Settings > Tidy",
    ),
    dict(
        key="taplock", id="com.purplesquarecube.taplock", name="TapLock", version="1.0.0",
        tagline="Double-tap to lock.",
        desc="Double-tap an empty spot on the Home Screen or Dock to lock your device, so you never have to reach for the power button.",
        features=["Works on the Home Screen and the Dock", "Ignores taps on icons, widgets and folders",
                  "Each area can be switched off separately"],
        where="Settings > TapLock",
    ),
    dict(
        key="quiethud", id="com.purplesquarecube.quiethud", name="QuietHUD", version="1.0.0",
        tagline="No more pop-ups.",
        desc="Hide the volume, brightness, ringer and rotation-lock pop-ups. The change still happens, you just don't see the overlay.",
        features=["Hide the volume HUD", "Hide the brightness HUD", "Hide the ringer switch HUD",
                  "Hide the rotation lock HUD"],
        where="Settings > QuietHUD",
    ),
    dict(
        key="tapfeel", id="com.purplesquarecube.tapfeel", name="TapFeel", version="1.0.0",
        tagline="Icons that answer back.",
        desc="Play a sound and bounce the icon when you tap an app. Pick from six system sounds and set how bouncy it is.",
        features=["Six system sounds with a preview button", "Adjustable bounce strength",
                  "Sound and bounce can be used separately"],
        where="Settings > TapFeel",
    ),
    dict(
        key="batteryline", id="com.purplesquarecube.batteryline", name="BatteryLine", version="1.0.0",
        tagline="A battery meter you can see in any app.",
        desc="A thin line along the top or bottom of the screen that shows your battery level on top of every app. Turns green while charging, orange under 50% and red under 20%.",
        features=["Top or bottom edge", "Adjustable thickness and opacity", "Automatic or fixed colour",
                  "Optional pulse while charging", "Can show only while charging"],
        where="Settings > BatteryLine",
    ),
    dict(
        key="dimmer", id="com.purplesquarecube.dimmer", name="Dimmer", version="1.0.0",
        tagline="Darker than dark.",
        desc="Dims the screen below the normal minimum and adds an optional warm tint, on top of everything. Handy at night. It can run on a schedule.",
        features=["Extra dimming slider", "Warm tint slider", "Always on, or only during hours you choose"],
        where="Settings > Dimmer",
    ),
    dict(
        key="umbra", id="com.purplesquarecube.umbra", name="Umbra", version="1.0.0",
        tagline="A dark mode for iOS 12.",
        desc="Makes app backgrounds dark using iOS's Smart Invert, one app at a time. Pictures and videos are left alone in most apps. It can run on a schedule, and the Home Screen can stay light.",
        features=["Dark backgrounds in any app", "Pick which apps stay light", "Always on, or only during hours you choose",
                  "Home Screen and system UI can stay normal"],
        where="Settings > Umbra",
    ),
    dict(
        key="plugin", id="com.purplesquarecube.plugin", name="PlugIn", version="1.0.0",
        tagline="A little show when you plug in.",
        desc="A light sweep around the edge of the screen and a sound when you connect a charger: green when you plug in, orange when you unplug.",
        features=["Sweep or pulse animation", "Six system sounds with a preview", "Optional on unplug", "Preview button"],
        where="Settings > PlugIn",
    ),
    dict(
        key="sleeptimer", id="com.purplesquarecube.sleeptimer", name="SleepTimer", version="1.0.0",
        tagline="Falls asleep before you do.",
        desc="Pick a time from 5 minutes to 2 hours and your music or video pauses when it ends. It can lock the device too.",
        features=["5 minutes to 2 hours", "Pauses music, podcasts and video", "Optionally locks the device", "Shows when it will stop"],
        where="Settings > SleepTimer",
    ),
    dict(
        key="badgecolor", id="com.purplesquarecube.badgecolor", name="BadgeColor", version="1.0.0",
        tagline="Badges in your colour.",
        desc="Recolor the red notification badges on your icons and make them bigger or smaller.",
        features=["Nine colours including the original red", "Adjustable size"],
        where="Settings > BadgeColor",
    ),
    dict(
        key="finevolume", id="com.purplesquarecube.finevolume", name="FineVolume", version="1.0.0",
        tagline="Volume, in smaller steps.",
        desc="Each press of a volume button changes the volume by less, so you can land on exactly the level you want. Set the step anywhere from a tenth to the normal size.",
        features=["Adjustable step size", "Works with the volume buttons"],
        where="Settings > FineVolume",
    ),
    dict(
        key="wakeup", id="com.purplesquarecube.wakeup", name="WakeUp", version="1.0.0",
        tagline="Wakes the screen when you plug in.",
        desc="Lights up the screen when you connect or disconnect a charger, so you can see right away that it's charging.",
        features=["On plugging in", "Optionally on unplugging"],
        where="Settings > WakeUp",
    ),
    dict(
        key="iconstyle", id="com.purplesquarecube.iconstyle", name="IconStyle", version="1.0.0",
        tagline="Icons with depth.",
        desc="Adds a soft shadow, or a coloured glow, under your app icons, and lets you make the icon pictures bigger or smaller.",
        features=["Shadow strength, softness and drop", "Seven shadow and glow colours", "Icon size slider"],
        where="Settings > IconStyle",
    ),
    dict(
        key="batteryalert", id="com.purplesquarecube.batteryalert", name="BatteryAlert", version="1.0.0",
        tagline="Know when to unplug.",
        desc="Shows a notice and plays a sound when your battery reaches the level you charge to, or when it runs low.",
        features=["Alert at a charge level from 50% to 100%", "Alert when the battery is low", "Six sounds with a preview"],
        where="Settings > BatteryAlert",
    ),
    dict(
        key="breather", id="com.purplesquarecube.breather", name="Breather", version="1.0.0",
        tagline="A nudge to take a break.",
        desc="Counts the time you spend on your phone and reminds you to take a short break. The count starts over once the phone has been locked for five minutes.",
        features=["Remind after 10 minutes to 1.5 hours", "Optional sound", "Resets after a real break"],
        where="Settings > Breather",
    ),
    dict(
        key="apptunes", id="com.purplesquarecube.apptunes", name="AppTunes", version="2.0.1",
        tagline="A different song in every app.",
        desc="Import your own MP3s and choose a song for each app. It plays while that app is open and stops when you leave.",
        features=["Import songs from the Files picker", "Pick a song per app", "Loop and volume controls"],
        where="Settings > AppTunes", prebuilt=True,
    ),
    dict(
        key="launchfx", id="com.purplesquarecube.launchfx", name="LaunchFX", version="1.0.1",
        tagline="50 ways to open an app.",
        desc="Pick one of 50 opening effects (iris shapes, wipes, curtains, blinds, tile dissolves and more). Preview them right in Settings.",
        features=["50 animations", "Preview button", "Speed and cover colour", "Per-app on/off", "Random mode"],
        where="Settings > LaunchFX", prebuilt=True,
    ),
    dict(
        key="liquidglass", id="com.purplesquarecube.liquidglass", name="Sheer", version="1.2.0",
        tagline="Turns every blur into clear glass.",
        desc="Replaces frosted blur with see-through glass across iOS 12: Control Center, notifications, folders, the dock, the lock screen and the app switcher. Bright glass edges, a soft inner glow and a highlight that moves as you tilt the phone.",
        features=["Clears every blurred surface, including Control Center's full-screen background",
                  "Glass edges and a tilt-reactive highlight on panels, the dock and folders",
                  "Frosted style if you want the blur back", "Adjustable blur, edge glow, shine and tint"],
        where="Settings > Sheer",
    ),
]

THEMES = [
    dict(key="violet", name="Violet",
         desc="Deep violet squares with solid white glyphs."),
    dict(key="mono", name="Mono",
         desc="Near-black with thin white line art and a single colour dot."),
    dict(key="paper", name="Paper",
         desc="Warm cream stock with ink glyphs on an offset colour print."),
    dict(key="neon", name="Neon",
         desc="Glowing tube-light outlines on midnight blue."),
    dict(key="frost", name="Frost",
         desc="Frosted pale glass with tinted, softly lit glyphs."),
    dict(key="sunset", name="Sunset", version="1.0.0",
         desc="Warm orange-to-purple dusk with a low sun and white glyphs."),
    dict(key="phosphor", name="Phosphor", version="1.0.0",
         desc="Green terminal glow with scanlines on black."),
    dict(key="blueprint", name="Blueprint", version="1.0.0",
         desc="White line drawings on blue graph paper."),
    dict(key="pixel", name="Pixel", version="1.0.0",
         desc="Chunky 8-bit glyphs on a dark pixel grid."),
    dict(key="doodle", name="Doodle", version="1.0.0",
         desc="Flat colour, wobbly marker outlines and a little pair of eyes."),
]
for t in THEMES:
    t["id"] = "com.purplesquarecube.theme." + t["key"]
    t.setdefault("version", "1.2.0")
    t["tagline"] = t["desc"]

THEME_FOOTNOTE = ("Icon themes for Snowboard or Anemone. They cover the stock Apple apps, Sileo, Zebra, Cydia, Filza and the "
                  "Google apps (Chrome, Gmail, Maps, YouTube, Drive, Photos, Docs and more), plus Strava, Geometry Dash, NewTerm 2, "
                  "iCleaner Pro, Amethyst, Delta and ReProvision. "
                  "Games, Google apps and fitness apps you install later, including 2-player games, get a matching icon "
                  "automatically through the small Purple Link helper.")

HELPERS = [
    dict(key="purplelink", id="com.purplesquarecube.purplelink", name="Purple Link", version="1.1.0",
         tagline="Icons for apps the themes don't list.",
         desc="A small helper installed with the themes. It looks at the apps on your phone and gives games, Google apps and fitness apps a matching theme icon, including 2-player games and anything you install later. It runs by itself when apps are added.",
         features=[], where=""),
]

CHANGELOG_NEW = "1.0.0: first release."
THEME_CHANGELOG = ("1.2.0: icons for NewTerm 2, iCleaner Pro, Amethyst, Delta and ReProvision, including sideloaded copies (needs the updated Purple Link).\n\n1.1.0: icons for the Google apps, Strava and Geometry Dash; popular games get their own icons; "
                   "games, Google apps and fitness apps you install later (including 2-player games) are themed "
                   "automatically by the new Purple Link helper. Smaller download too.\n\n1.0.0: first release.")
CHANGELOG = {
    "com.purplesquarecube.apptunes": "2.0.1: new, more detailed icon.\n\n2.0.0: rebuilt with a Settings page, song import and per-app songs.",
    "com.purplesquarecube.launchfx": "1.0.1: new, more detailed icon.\n\n1.0.0: first release.",
    "com.purplesquarecube.liquidglass": "1.2.0: renamed from Liquid Glass to Sheer. New Clear Every Blur switch clears every blurred surface in SpringBoard, including Control Center's full-screen background, the lock screen, the app switcher and the dock.\n\n1.1.0: new Clear style (now the default) that fades out the system blur so the glass is see-through. Frosted keeps the old look. Added a blur slider and a soft inner glow.\n\n1.0.0: first release.",
}

# Jailbreaks these packages are expected to run on. Exact iOS ranges change, so each entry points people
# at the project's own page. Nothing here has been tested on every one of them.
JAILBREAKS = [
    dict(name="checkra1n", ios="iOS 12.0 to 14.8.1",
         devices="A7 to A11 chips: iPhone 5s up to iPhone X, plus iPads and iPods with the same chips",
         note="Semi-tethered: run it from a Mac or Linux PC again after every reboot. Rootful on iOS 12, so everything installs the normal way. The main target for this repo."),
    dict(name="Odysseyra1n", ios="iOS 12.0 to 14.8.1",
         devices="Same devices as checkra1n",
         note="Runs on top of checkra1n and also needs a computer after every reboot. It uses libhooker where older jailbreaks use Substrate; libhooker stands in for it."),
    dict(name="Amethyst", ios="iOS 12.0 to 13.7",
         devices="arm64 devices (listed for all devices on those versions)",
         note="Released June 2026. Semi-untethered: sideload the app and tap to re-jailbreak after a reboot. It loads tweaks, and a community write-up reports it working on an iPhone 6 running iOS 12.5.8."),
    dict(name="unc0ver", ios="iOS 12.0 to 12.4.8 (skips 12.3 to 12.3.2)",
         devices="A7 to A11 chips, partial support on A12",
         note="Does not cover iOS 12.5.x. If you are on 12.5.x, use one of the others."),
    dict(name="Chimera", ios="iOS 12.0 to 12.5.7",
         devices="A7 to A12 chips",
         note="Comes with Substitute and Sileo. iOS 12.5.x needs the community chimera_patch."),
]
JB_REQUIREMENTS = ("Any jailbreak should work if it gives you iOS 12 on an arm64 device, a rootful filesystem, "
                   "a tweak injector (Substrate, Substitute or libhooker) and PreferenceLoader.")
JB_NOT_COMPATIBLE = ("Odyssey (iOS 13), Taurine (iOS 14), Dopamine, palera1n and XinaA15 (iOS 15 and up), and any jailbreak "
                     "for iOS 13 or later. Amethyst and Odysseyra1n can reach those versions, but these packages are "
                     "only built for iOS 12 and rootful systems.")
JB_CHECKED = "Version ranges checked against public sources in October 2026. They can change, so confirm on each project's own page."



# ---- every tweak got a new hand-drawn icon: bump the patch version so the Settings icon updates too
AUTHOR = "purplepeanut4"
for _t in TWEAKS:
    _maj, _min, _pat = _t["version"].split(".")
    _old = _t["version"]
    _t["old_version"] = _old
    _t["version"] = f"{_maj}.{_min}.{int(_pat) + 1}"
    _prev = CHANGELOG.get(_t["id"], CHANGELOG_NEW)
    CHANGELOG[_t["id"]] = f"{_t['version']}: new hand-drawn icon.\n\n{_prev}"
