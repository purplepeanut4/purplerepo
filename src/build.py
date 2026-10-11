"""Build purplerepo: compile the tweaks, render + package the themes, write debs/."""
import os
import plistlib
import shutil
import subprocess
import sys

from PIL import Image

import art
import meta
import themes as th

ROOT = "/home/claude/purple"
SDK = "/home/claude/sdk/sdks/iPhoneOS12.4.sdk"
LDID = "/home/claude/ldid/ldid"
BUILD = f"{ROOT}/build"
DEBS = f"{ROOT}/out/debs"

CFLAGS = ["-target", "arm64-apple-ios12.0", "-isysroot", SDK, "-fobjc-arc", "-fobjc-runtime=ios-12.0",
          "-fuse-ld=lld", "-fPIC", "-Wall", "-Wno-unused-function", "-O2", f"-I{ROOT}/common"]
FRAMEWORKS = ["-framework", "Foundation", "-framework", "UIKit", "-framework", "QuartzCore",
              "-framework", "CoreGraphics", "-framework", "AudioToolbox"]

# folder name, class prefix, display name
TWEAK_SRC = {
    "tidy": "Tidy", "taplock": "TapLock", "quiethud": "QuietHUD",
    "tapfeel": "TapFeel", "batteryline": "BatteryLine", "liquidglass": "LiquidGlass",
}


def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode != 0:
        print("FAILED:", " ".join(cmd)[:200])
        print(r.stdout[-2000:], r.stderr[-3000:])
        sys.exit(1)
    if r.stderr.strip():
        print(r.stderr.strip()[:1500])
    return r


def write(path, text, mode="w"):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, mode) as f:
        f.write(text)


def control(pkg, section, depends, desc, extra=""):
    return (f"Package: {pkg['id']}\nName: {pkg['name']}\nVersion: {pkg['version']}\n"
            f"Architecture: iphoneos-arm\nDescription: {desc}\n"
            + (f"Depends: {depends}\n" if depends else "")
            + f"Maintainer: purplesquarecube\nAuthor: purplesquarecube\nSection: {section}\n"
            + extra)


def make_deb(stage, out):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    if os.path.exists(out):
        os.remove(out)
    run(["dpkg-deb", "--root-owner-group", "-Zgzip", "-b", stage, out])


# ---------------------------------------------------------------- tweaks
def build_tweak(pkg):
    folder = pkg["key"]
    cls = TWEAK_SRC[folder]
    src = f"{ROOT}/tweaks/{folder}"
    out = f"{BUILD}/{folder}"
    os.makedirs(out, exist_ok=True)

    dylib = f"{out}/{cls}.dylib"
    prefs = f"{out}/{cls}Prefs"
    run(["clang", *CFLAGS, "-dynamiclib", "-install_name",
         f"/Library/MobileSubstrate/DynamicLibraries/{cls}.dylib", *FRAMEWORKS,
         f"{src}/Tweak.m", "-o", dylib])
    run(["clang", *CFLAGS, "-bundle", f"-F{SDK}/System/Library/PrivateFrameworks", *FRAMEWORKS,
         "-framework", "Preferences", f"{src}/Prefs.m", "-o", prefs])
    run([LDID, "-S", dylib])
    run([LDID, "-S", prefs])

    stage = f"{out}/pkg"
    shutil.rmtree(stage, ignore_errors=True)
    dyn = f"{stage}/Library/MobileSubstrate/DynamicLibraries"
    bundle = f"{stage}/Library/PreferenceBundles/{cls}Prefs.bundle"
    loader = f"{stage}/Library/PreferenceLoader/Preferences"
    os.makedirs(dyn); os.makedirs(bundle); os.makedirs(loader)
    shutil.copy(dylib, dyn)
    write(f"{dyn}/{cls}.plist", '{ Filter = { Bundles = ( "com.apple.springboard" ); }; }\n')
    shutil.copy(prefs, bundle)
    with open(f"{bundle}/Info.plist", "wb") as f:
        plistlib.dump({
            "CFBundleDevelopmentRegion": "English", "CFBundleExecutable": f"{cls}Prefs",
            "CFBundleIdentifier": f"com.purplesquarecube.{folder}prefs", "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": f"{cls}Prefs", "CFBundlePackageType": "BNDL",
            "CFBundleShortVersionString": pkg["version"], "CFBundleVersion": pkg["version"],
            "NSPrincipalClass": f"{cls}RootListController",
        }, f)
    with open(f"{loader}/{cls}.plist", "wb") as f:
        plistlib.dump({"entry": {
            "bundle": f"{cls}Prefs", "cell": "PSLinkCell", "detail": f"{cls}RootListController",
            "icon": "icon.png", "isController": True, "label": pkg["name"]}}, f)
    for px, name in ((29, "icon.png"), (58, "icon@2x.png"), (87, "icon@3x.png")):
        art.tweak_icon(folder, px, rounded=False).save(f"{bundle}/{name}")

    write(f"{stage}/DEBIAN/control", control(
        pkg, "Tweaks", "mobilesubstrate, preferenceloader, firmware (>= 12.0)", pkg["tagline"] + " " + pkg["desc"].split(". ")[0]))
    deb = f"{DEBS}/{pkg['id']}_{pkg['version']}_iphoneos-arm.deb"
    make_deb(stage, deb)
    print("tweak", pkg["name"], os.path.getsize(deb), "bytes")


# ---------------------------------------------------------------- themes
def build_theme(theme_row, tmeta):
    tid, display, blurb, fn, lw = theme_row
    folder = f"{display}.theme"
    stage = f"{BUILD}/theme-{tid}/pkg"
    shutil.rmtree(stage, ignore_errors=True)
    tdir = f"{stage}/Library/Themes/{folder}"
    ib = f"{tdir}/IconBundles"
    os.makedirs(ib)
    for i, (bid, _, _) in enumerate(th.APPS):
        img = th.render_icon(theme_row, i, 180)
        img.save(f"{ib}/{bid}.png", optimize=True)
        img.save(f"{ib}/{bid}-large.png", optimize=True)
    with open(f"{tdir}/Info.plist", "wb") as f:
        plistlib.dump({"PackageVersion": 2, "IB-MaskIcons": True, "ThemeName": display,
                       "ThemeAuthor": "purplesquarecube"}, f)
    write(f"{stage}/DEBIAN/control", control(
        tmeta, "Themes (Icons)", "", f"{blurb} Needs Snowboard or Anemone."))
    deb = f"{DEBS}/{tmeta['id']}_{tmeta['version']}_iphoneos-arm.deb"
    make_deb(stage, deb)
    print("theme", display, os.path.getsize(deb), "bytes")


def main():
    only = sys.argv[1:] or ["tweaks", "themes"]
    os.makedirs(DEBS, exist_ok=True)
    if "tweaks" in only:
        for pkg in meta.TWEAKS:
            if pkg.get("prebuilt"):
                continue
            build_tweak(pkg)
    if "themes" in only:
        by_key = {t["key"]: t for t in meta.THEMES}
        for row in th.THEMES:
            build_theme(row, by_key[row[0]])


if __name__ == "__main__":
    main()
