"""Single source of truth for purplerepo: packages, copy, versions."""

REPO_URL = "https://purplesquarecube.github.io/purplerepo/"
GITHUB_URL = "https://github.com/purplesquarecube/purplerepo"
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
        key="apptunes", id="com.purplesquarecube.apptunes", name="AppTunes", version="2.0.0",
        tagline="A different song in every app.",
        desc="Import your own MP3s and choose a song for each app. It plays while that app is open and stops when you leave.",
        features=["Import songs from the Files picker", "Pick a song per app", "Loop and volume controls"],
        where="Settings > AppTunes", prebuilt=True,
    ),
    dict(
        key="launchfx", id="com.purplesquarecube.launchfx", name="LaunchFX", version="1.0.0",
        tagline="50 ways to open an app.",
        desc="Pick one of 50 opening effects (iris shapes, wipes, curtains, blinds, tile dissolves and more). Preview them right in Settings.",
        features=["50 animations", "Preview button", "Speed and cover colour", "Per-app on/off", "Random mode"],
        where="Settings > LaunchFX", prebuilt=True,
    ),
    dict(
        key="liquidglass", id="com.purplesquarecube.liquidglass", name="Liquid Glass", version="1.1.0",
        tagline="Clear glass for iOS 12.",
        desc="See-through glass panels with a bright edge, a faint inner glow and a highlight that moves as you tilt the phone. Works on the Dock, folders, notifications and Control Center.",
        features=["Clear style: the system blur is faded out so panels are see-through (default)",
                  "Frosted style keeps the blur if you prefer it", "Adjustable blur, edge glow, shine and tint",
                  "Dock, folders, panels and optional icons"],
        where="Settings > Liquid Glass",
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
]
for t in THEMES:
    t["id"] = "com.purplesquarecube.theme." + t["key"]
    t["version"] = "1.0.0"
    t["tagline"] = t["desc"]

THEME_FOOTNOTE = ("Icon themes for Snowboard or Anemone. Covers the stock Apple apps plus Sileo, Zebra, Cydia and Filza. "
                  "Apps without an icon here keep their normal one.")

CHANGELOG_NEW = "1.0.0: first release."
CHANGELOG = {
    "com.purplesquarecube.apptunes": "2.0.0: rebuilt with a Settings page, song import and per-app songs.",
    "com.purplesquarecube.liquidglass": "1.1.0: new Clear style (now the default) that fades out the system blur so the glass is see-through. Frosted keeps the old look. Added a blur slider and a soft inner glow.\n\n1.0.0: first release.",
}

# Jailbreaks these packages are expected to run on. Exact iOS ranges change, so each entry points people
# at the project's own page. Nothing here has been tested on every one of them.
JAILBREAKS = [
    dict(name="checkra1n", ios="iOS 12.x",
         devices="A7 to A11 chips: iPhone 5s up to iPhone X, plus iPads and iPods with the same chips",
         note="The main target for this repo. Rootful on iOS 12, so everything installs the normal way."),
    dict(name="Odysseyra1n", ios="Same versions as checkra1n",
         devices="Same devices as checkra1n",
         note="Installs on top of checkra1n. It uses libhooker where older setups use Substrate; libhooker stands in for it."),
    dict(name="unc0ver", ios="Some iOS 12 versions (roughly 12.0 to 12.4.x)",
         devices="Depends on the iOS version",
         note="Check unc0ver's own page for the exact versions your device can use."),
    dict(name="Chimera", ios="iOS 12.x (versions vary)",
         devices="A7 to A12 chips",
         note="Comes with Substitute and Sileo. Check the project page for the versions it covers."),
    dict(name="Amethyst", ios="iOS 12 (see the project page)",
         devices="See the project page",
         note="Listed as an iOS 12 jailbreak. If it provides tweak injection and PreferenceLoader, these packages install normally."),
]
JB_REQUIREMENTS = ("Any jailbreak should work if it gives you iOS 12 on an arm64 device, a rootful filesystem, "
                   "a tweak injector (Substrate, Substitute or libhooker) and PreferenceLoader.")
JB_NOT_COMPATIBLE = ("Odyssey, Taurine, unc0ver on iOS 13 or 14, Dopamine, palera1n, XinaA15 and other jailbreaks "
                     "for iOS 13 and later. These packages are built for iOS 12 and rootful systems only.")

