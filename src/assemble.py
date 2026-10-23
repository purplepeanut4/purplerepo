"""Assemble the purplerepo folder that gets pushed to GitHub."""
import bz2
import glob
import gzip
import html
import json
import os
import shutil
import subprocess

from PIL import Image

import art
import meta
import peanut
import themes as th

ROOT = "/home/claude/purple"
REPO = f"{ROOT}/repo"
OLD = "/tmp/pr"          # existing clone with the three older debs

ALL = meta.TWEAKS + meta.THEMES + meta.HELPERS


def deb_name(p):
    return f"{p['id']}_{p['version']}_iphoneos-arm.deb"


def slug(p):
    return p["id"].replace(".", "-")


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


# ------------------------------------------------------------------ files
def collect_debs():
    os.makedirs(f"{REPO}/debs", exist_ok=True)
    for p in ALL:
        name = deb_name(p)
        src = f"{ROOT}/out/debs/{name}"
        if not os.path.exists(src):
            src = f"{OLD}/debs/{name}"
        if not os.path.exists(src):
            src = f"{OLD}/{name}"
        if not os.path.exists(src):
            raise SystemExit(f"missing deb: {name}")
        shutil.copy(src, f"{REPO}/debs/{name}")


def make_images():
    os.makedirs(f"{REPO}/icons", exist_ok=True)
    os.makedirs(f"{REPO}/assets", exist_ok=True)
    for p in meta.TWEAKS:
        art.tweak_icon(p["key"], 256).save(f"{REPO}/icons/{p['id']}.png", optimize=True)
    for p in meta.HELPERS:
        art.tweak_icon(p["key"], 256).save(f"{REPO}/icons/{p['id']}.png", optimize=True)
    rows = {r[0]: r for r in th.THEMES}
    for t in meta.THEMES:
        peanut.peanut_icon("theme." + t["key"], 256).save(f"{REPO}/icons/{t['id']}.png", optimize=True)
        pv = th.preview(rows[t["key"]])
        pv.thumbnail((900, 900))
        pv.save(f"{REPO}/assets/theme-{t['key']}.png", optimize=True)
    # repo icon shown in Sileo: the peanut, cropped square from the photo
    photo = Image.open(f"{ROOT}/peanut-photo.jpg").convert("RGB")
    photo.crop((0, 60, 940, 1000)).resize((180, 180), Image.LANCZOS).save(f"{REPO}/CydiaIcon.png", optimize=True)
    shutil.copy(f"{ROOT}/peanut-hi.png", f"{REPO}/assets/peanut.png")
    pn = Image.open(f"{ROOT}/peanut-hi.png").convert("RGBA")
    fav = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    ph = 120
    small = pn.resize((int(pn.size[0] * ph / pn.size[1]), ph), Image.LANCZOS)
    fav.alpha_composite(small, ((128 - small.size[0]) // 2, 4))
    fav.save(f"{REPO}/assets/favicon.png", optimize=True)


# ------------------------------------------------------------------ Packages + depictions
def depiction(p):
    is_theme = p["id"].startswith("com.purplesquarecube.theme.")
    changelog = meta.THEME_CHANGELOG if is_theme else meta.CHANGELOG.get(p["id"], meta.CHANGELOG_NEW)
    is_helper = p in meta.HELPERS
    views = [
        {"class": "DepictionSubheaderView", "title": p["tagline"], "useBoldText": True, "useBottomMargin": False},
        {"class": "DepictionMarkdownView", "markdown": p["desc"], "useSpacing": True},
    ]
    if is_theme:
        views.append({"class": "DepictionScreenshotsView", "itemCornerRadius": 8,
                      "itemSize": "{300, 230}",
                      "screenshots": [{"accessibilityText": f"{p['name']} theme preview",
                                       "url": f"{meta.REPO_URL}assets/theme-{p['key']}.png"}]})
        views.append({"class": "DepictionMarkdownView", "markdown": meta.THEME_FOOTNOTE, "useSpacing": True})
    elif is_helper:
        views.append({"class": "DepictionMarkdownView",
                      "markdown": "Installed automatically with the purplerepo themes. There is nothing to set up: it runs by itself when you add or remove apps.",
                      "useSpacing": True})
    else:
        bullets = "\n".join(f"- {f}" for f in p["features"])
        views.append({"class": "DepictionSubheaderView", "title": "Features", "useBoldText": True,
                      "useBottomMargin": False})
        views.append({"class": "DepictionMarkdownView", "markdown": bullets, "useSpacing": True})
        views.append({"class": "DepictionTableTextView", "title": "Settings", "text": p["where"].replace(">", "›")})
    views.append({"class": "DepictionTableTextView", "title": "Version", "text": p["version"]})
    views.append({"class": "DepictionTableTextView", "title": "Requires",
                  "text": "iOS 12" + (" + Snowboard/Anemone" if is_theme else "")})
    views.append({"class": "DepictionTableTextView", "title": "Author", "text": meta.AUTHOR})
    return {
        "minVersion": "0.1", "class": "DepictionTabView", "tintColor": meta.ACCENT,
        "tabs": [
            {"tabname": "Details", "class": "DepictionStackView", "views": views},
            {"tabname": "Changelog", "class": "DepictionStackView", "views": [
                {"class": "DepictionSubheaderView", "title": p["version"], "useBoldText": True,
                 "useBottomMargin": False},
                {"class": "DepictionMarkdownView", "markdown": changelog, "useSpacing": True}]},
        ],
    }


def build_packages():
    for p in ALL:
        write(f"{REPO}/depictions/{p['id']}.json", json.dumps(depiction(p), indent=2))
    out = subprocess.run(["dpkg-scanpackages", "-m", "debs", "/dev/null"], cwd=REPO,
                         capture_output=True, text=True).stdout
    by_id = {p["id"]: p for p in ALL}
    stanzas = []
    for block in out.strip().split("\n\n"):
        fields = []
        for line in block.split("\n"):
            k, _, v = line.partition(": ")
            fields.append([k, v])
        d = {k: v for k, v in fields}
        p = by_id[d["Package"]]
        # replace/add presentation fields
        fields = [f for f in fields if f[0] not in ("Icon", "SileoDepiction", "Depiction")]
        for f in fields:
            if f[0] in ("Maintainer", "Author"):
                f[1] = meta.AUTHOR
        fields.append(["Icon", f"{meta.REPO_URL}icons/{p['id']}.png"])
        fields.append(["SileoDepiction", f"{meta.REPO_URL}depictions/{p['id']}.json"])
        fields.append(["Depiction", f"{meta.REPO_URL}#{slug(p)}"])
        stanzas.append("\n".join(f"{k}: {v}" for k, v in fields))
    text = "\n\n".join(stanzas) + "\n\n"
    write(f"{REPO}/Packages", text)
    raw = text.encode()
    with open(f"{REPO}/Packages.bz2", "wb") as f:
        f.write(bz2.compress(raw, 9))
    with open(f"{REPO}/Packages.gz", "wb") as f:
        f.write(gzip.compress(raw, 9, mtime=0))
    write(f"{REPO}/Release",
          "Origin: purplerepo\nLabel: purplerepo\nSuite: stable\nVersion: 1.0\nCodename: ios\n"
          "Architectures: iphoneos-arm\nComponents: main\nDescription: Tweaks and themes by purplepeanut4\n")
    write(f"{REPO}/.nojekyll", "")


# ------------------------------------------------------------------ website
PEANUTS = [
    # left %, width px, seconds, delay (negative = already mid-flight), drift px, start deg, end deg, top % (reduced-motion), opacity
    (6, 64, 26, -4, 40, -20, 300, 12, .95), (14, 40, 32, -19, -30, 15, -280, 62, .75), (23, 96, 21, -11, 55, -40, 330, 35, 1.0),
    (31, 52, 29, -26, -45, 30, -320, 80, .85), (40, 76, 24, -7, 35, -10, 290, 22, .95), (48, 36, 35, -30, -25, 50, -250, 70, .7),
    (56, 110, 20, -15, 60, -30, 360, 48, 1.0), (63, 48, 30, -2, -40, 20, -300, 9, .8), (71, 84, 23, -21, 45, -50, 310, 58, .95),
    (79, 44, 33, -12, -35, 35, -270, 28, .75), (86, 100, 22, -9, 50, -15, 340, 74, 1.0), (93, 58, 28, -24, -55, 40, -310, 40, .85),
    (3, 88, 25, -17, 30, 25, -330, 90, .9), (35, 42, 34, -33, 25, -35, 260, 52, .7), (52, 66, 27, -5, -50, 10, -290, 88, .9),
    (68, 38, 36, -28, 30, 45, -240, 15, .7), (90, 74, 24, -14, -45, -25, 320, 18, .9), (19, 56, 31, -22, 35, 20, 280, 94, .8),
]

SITE_CSS = """
*{box-sizing:border-box}
html,body{height:100%}
body{margin:0;background:#15111b;color:#f6e6c6;
  font:700 17px/1.2 "Marker Felt","Chalkboard SE","Comic Sans MS","Arial Rounded MT Bold",-apple-system,"Helvetica Neue",sans-serif;
  -webkit-text-size-adjust:100%}
.sky{position:fixed;top:0;right:0;bottom:0;left:0;overflow:hidden;pointer-events:none;z-index:0}
.p{position:absolute;bottom:-170px;height:auto;will-change:transform;
  -webkit-animation:rise linear infinite;animation:rise linear infinite;
  -webkit-user-select:none;user-select:none}
@-webkit-keyframes rise{from{-webkit-transform:translate3d(0,0,0) rotate(var(--a0))}to{-webkit-transform:translate3d(var(--dx),-135vh,0) rotate(var(--a1))}}
@keyframes rise{from{transform:translate3d(0,0,0) rotate(var(--a0))}to{transform:translate3d(var(--dx),-135vh,0) rotate(var(--a1))}}
@media (prefers-reduced-motion: reduce){.p{-webkit-animation:none;animation:none;bottom:auto;top:var(--t);transform:rotate(var(--a0))}}
main{position:relative;z-index:1;min-height:100%;display:-webkit-box;display:-webkit-flex;display:flex;
  -webkit-box-orient:vertical;-webkit-flex-direction:column;flex-direction:column;
  -webkit-box-pack:center;-webkit-justify-content:center;justify-content:center;-webkit-box-align:center;-webkit-align-items:center;align-items:center;
  padding:28px 20px calc(28px + env(safe-area-inset-bottom))}
h1{margin:0 0 26px;font-size:40px;font-weight:700;letter-spacing:.5px;color:#f6e6c6;text-shadow:0 0 14px #15111b,0 0 6px #15111b,3px 3px 0 #4b1a7a}
.btn{display:block;width:100%;max-width:310px;margin:0 0 14px;padding:17px 18px;text-align:center;text-decoration:none;
  font:inherit;font-size:19px;color:#4b1a7a;background:#f1d6a0;border:3px solid #15111b;border-radius:18px;
  box-shadow:4px 5px 0 #4b1a7a;-webkit-transform:rotate(-1.2deg);transform:rotate(-1.2deg)}
.btn:nth-of-type(2){-webkit-transform:rotate(1deg);transform:rotate(1deg)}
.btn.main{background:#6a2bb8;color:#fff1d6;border-color:#f1d6a0;box-shadow:4px 5px 0 #f1d6a0;-webkit-transform:rotate(-1.6deg);transform:rotate(-1.6deg)}
.btn:active{box-shadow:0 0 0 transparent;margin-top:4px;margin-bottom:10px}
"""

SITE_JS = """
(function(){
  var url = location.origin + location.pathname.replace(/index\\.html$/, "");
  if (url.charAt(url.length-1) !== "/") url += "/";
  var set = function(id, href){ var el = document.getElementById(id); if (el) el.href = href; };
  set("sileo", "sileo://source/" + url);
  set("zebra", "zbra://sources/add/" + url);
  set("cydia", "cydia://url/https://cydia.saurik.com/api/share#?source=" + encodeURIComponent(url));
})();
"""


def build_site():
    peanuts = "\n".join(
        f'    <img class="p" src="assets/peanut.png" alt="" width="{w}" '
        f'style="left:{l}%;width:{w}px;animation-duration:{d}s;-webkit-animation-duration:{d}s;'
        f'animation-delay:{dl}s;-webkit-animation-delay:{dl}s;opacity:{o};--dx:{dx}px;--a0:{a0}deg;--a1:{a1}deg;--t:{t}%">'
        for (l, w, d, dl, dx, a0, a1, t, o) in PEANUTS)
    page = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#15111b">
<title>purplerepo</title>
<link rel="icon" href="assets/favicon.png">
<style>{SITE_CSS}</style>
</head>
<body>
  <div class="sky" aria-hidden="true">
{peanuts}
  </div>
  <main>
    <h1>purplerepo</h1>
    <a class="btn main" id="sileo" href="sileo://source/{meta.REPO_URL}">Add to Sileo</a>
    <a class="btn" id="zebra" href="zbra://sources/add/{meta.REPO_URL}">Add to Zebra</a>
    <a class="btn" id="cydia" href="cydia://url/https://cydia.saurik.com/api/share#?source={meta.REPO_URL}">Add to Cydia</a>
  </main>
<script>{SITE_JS}</script>
</body>
</html>
"""
    write(f"{REPO}/index.html", page)


# ------------------------------------------------------------------ README
def build_readme():
    text = f"""<img src="assets/peanut.png" width="70" align="right" alt="">

# purplerepo

Tweaks and themes for iOS 12 jailbreaks, by [purplepeanut4](https://github.com/purplepeanut4).

**Repo address**

```
{meta.REPO_URL}
```

Open that link on your iPhone and tap **Add to Sileo**, **Zebra** or **Cydia**.
"""
    write(f"{REPO}/README.md", text)


# ------------------------------------------------------------------ source
def copy_source():
    dst = f"{REPO}/src"
    shutil.rmtree(dst, ignore_errors=True)
    os.makedirs(f"{dst}/tweaks")
    for f in ("art.py", "themes.py", "build.py", "assemble.py", "meta.py"):
        shutil.copy(f"{ROOT}/{f}", dst)
    shutil.copytree(f"{ROOT}/common", f"{dst}/common")
    for k in [t["key"] for t in meta.TWEAKS if not t.get("prebuilt")]:
        shutil.copytree(f"{ROOT}/tweaks/{k}", f"{dst}/tweaks/{k}")
    # the three earlier tweaks
    older = {
        "apptunes": ("/home/claude/apptunes", {"tweak/Tweak.m": "Tweak.m", "prefs/AppTunesPrefs.m": "Prefs.m"}),
        "launchfx": ("/home/claude/launchfx", {"tweak/Tweak.m": "Tweak.m", "prefs/LaunchFXPrefs.m": "Prefs.m",
                                               "common/LFXEngine.m": "LFXEngine.m", "common/LFXEngine.h": "LFXEngine.h"}),
    }
    for name, (base, files) in older.items():
        os.makedirs(f"{dst}/tweaks/{name}", exist_ok=True)
        for s, d in files.items():
            if os.path.exists(f"{base}/{s}"):
                shutil.copy(f"{base}/{s}", f"{dst}/tweaks/{name}/{d}")
    shutil.rmtree(f"{dst}/__pycache__", ignore_errors=True)


def main():
    shutil.rmtree(REPO, ignore_errors=True)
    os.makedirs(REPO)
    collect_debs()
    make_images()
    build_packages()
    build_site()
    build_readme()
    copy_source()
    print("assembled", REPO)


if __name__ == "__main__":
    main()
