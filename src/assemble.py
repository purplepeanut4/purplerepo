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
    idx_phone = [b for b, _, _ in th.APPS].index("com.apple.mobilephone")
    for t in meta.THEMES:
        th.render_icon(rows[t["key"]], idx_phone, 256).save(f"{REPO}/icons/{t['id']}.png", optimize=True)
        pv = th.preview(rows[t["key"]])
        pv.thumbnail((900, 900))
        pv.save(f"{REPO}/assets/theme-{t['key']}.png", optimize=True)
    art.logo(180).save(f"{REPO}/CydiaIcon.png", optimize=True)          # repo icon shown in Sileo
    art.logo(512, rounded=True).save(f"{REPO}/assets/logo.png", optimize=True)
    art.banner().save(f"{REPO}/assets/banner.png", optimize=True)


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
    views.append({"class": "DepictionTableTextView", "title": "Author", "text": "purplesquarecube"})
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
          "Architectures: iphoneos-arm\nComponents: main\nDescription: Tweaks and themes by purplesquarecube\n")
    write(f"{REPO}/.nojekyll", "")


# ------------------------------------------------------------------ website
CSS = """
:root{
  --paper:#F4EFE4; --paper2:#EAE3D3; --ink:#1B1527; --muted:#6C6480; --rule:rgba(27,21,39,.16);
  --accent:#6A3DE8; --accent-ink:#ffffff;
}
@media (prefers-color-scheme: dark){
  :root{ --paper:#130E20; --paper2:#1B1530; --ink:#EEE8FB; --muted:#9C92B6; --rule:rgba(238,232,251,.16);
         --accent:#B59CFF; --accent-ink:#130E20; }
}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{
  margin:0; background:var(--paper); color:var(--ink);
  font:17px/1.55 -apple-system,"Helvetica Neue",Helvetica,Arial,sans-serif;
  padding:0 20px env(safe-area-inset-bottom);
}
.wrap{max-width:720px; margin:0 auto; padding:30px 0 56px}
a{color:var(--ink)}
.serif,h1,h2,h3{font-family:"Iowan Old Style","Palatino Linotype",Palatino,"Book Antiqua",Georgia,serif}
.mono,.url,.ver,.label,.count,.where,.dl,.tagrow span,.stamp,footer,.btn{
  font-family:Menlo,"SF Mono",Monaco,Consolas,"Courier New",monospace}

/* masthead */
.top{display:-webkit-box;display:flex;-webkit-box-align:center;align-items:center;position:relative;padding-bottom:22px;border-bottom:2px solid var(--ink)}
.mark{width:72px;height:72px;border-radius:17px;margin-right:16px;flex:none;display:block}
h1{margin:0;font-size:40px;line-height:1;letter-spacing:-.5px;font-weight:700}
.by{margin:8px 0 0;font-size:13px;color:var(--muted)}
.stamp{position:absolute;right:0;top:-6px;transform:rotate(5deg);-webkit-transform:rotate(5deg);
  border:2px solid var(--accent);color:var(--accent);padding:3px 8px;font-size:11px;line-height:1.25;
  text-transform:uppercase;letter-spacing:.8px;text-align:center}

/* ticket */
.ticket{margin:28px 0 8px;padding:18px;background:var(--paper2);border:2px solid var(--ink);box-shadow:5px 5px 0 var(--ink)}
.label{margin:0 0 6px;font-size:11px;text-transform:uppercase;letter-spacing:1.2px;color:var(--muted)}
.url{margin:0 0 14px;font-size:14px;word-break:break-all;padding:9px 11px;background:var(--paper);border:1px solid var(--rule)}
.actions{margin:0 -4px}
.btn{display:inline-block;margin:4px;padding:9px 13px;font-size:13px;color:var(--ink);text-decoration:none;
  background:var(--paper);border:2px solid var(--ink);box-shadow:3px 3px 0 var(--ink);cursor:pointer;
  -webkit-appearance:none;appearance:none;border-radius:0;white-space:nowrap}
.btn.main{background:var(--accent);color:var(--accent-ink)}
.btn:active{box-shadow:0 0 0 var(--ink);transform:translate(3px,3px);-webkit-transform:translate(3px,3px)}

/* sections */
h2{margin:44px 0 6px;font-size:27px;line-height:1.1;font-weight:700}
.count{font-size:13px;font-weight:400;color:var(--muted);vertical-align:super;margin-left:5px}
.lede{margin:0 0 6px;color:var(--muted);font-size:15px}

/* package list */
.index{list-style:none;margin:10px 0 0;padding:0;counter-reset:pkg}
.pkg{counter-increment:pkg;display:-webkit-box;display:flex;padding:20px 0;border-top:1px solid var(--rule);position:relative}
.pkg:last-child{border-bottom:1px solid var(--rule)}
.pkg:before{content:counter(pkg,decimal-leading-zero);font:11px Menlo,monospace;color:var(--muted);width:26px;flex:none;padding-top:5px}
.ico{width:56px;height:56px;border-radius:13px;flex:none;margin-right:14px;display:block}
.pbody{min-width:0;-webkit-box-flex:1;flex:1}
h3{margin:0;font-size:22px;line-height:1.2;font-weight:700}
.ver{font-size:11px;font-weight:400;color:var(--muted);margin-left:6px;vertical-align:middle}
.tag{margin:2px 0 6px;font-style:italic;color:var(--accent)}
.pbody p{margin:0 0 8px;font-size:15.5px}
details{margin-top:6px;font-size:15px}
summary{cursor:pointer;font:12px Menlo,monospace;color:var(--muted);padding:3px 0;list-style:none}
summary::-webkit-details-marker{display:none}
summary:before{content:"+ ";}
details[open] summary:before{content:"- ";}
details ul{margin:6px 0 8px 0;padding-left:20px}
details li{margin:2px 0}
.where{font-size:12px;color:var(--muted);margin:6px 0}
.dl{font-size:12px}

/* themes */
.themes{display:grid;grid-template-columns:1fr 1fr;grid-gap:22px 16px;margin-top:18px}
@media(min-width:620px){.themes{grid-template-columns:1fr 1fr 1fr}}
figure{margin:0}
figure img{width:100%;height:auto;display:block;border:2px solid var(--ink);box-shadow:4px 4px 0 var(--ink)}
figcaption{margin-top:12px;font-size:14px;line-height:1.35}
figcaption b{display:block;font:700 18px "Iowan Old Style",Georgia,serif}
figcaption span{display:block;color:var(--muted);font-size:13px;margin:2px 0 4px}


/* jailbreak list */
.jb{list-style:none;margin:12px 0 0;padding:0}
.jb li{padding:15px 0;border-top:1px solid var(--rule)}
.jb li:last-child{border-bottom:1px solid var(--rule)}
.jb b{font:700 20px "Iowan Old Style","Palatino Linotype",Palatino,Georgia,serif}
.jb .ios{display:block;font:12px Menlo,"SF Mono",Monaco,monospace;color:var(--accent);margin:4px 0 1px}
.jb .dev{display:block;font:12px Menlo,"SF Mono",Monaco,monospace;color:var(--muted)}
.jb p{margin:7px 0 0;font-size:15px}
.nope{margin:16px 0 0;font-size:14.5px;padding-left:12px;border-left:3px solid var(--accent)}
.nope b{font:700 12px Menlo,"SF Mono",Monaco,monospace;text-transform:uppercase;letter-spacing:.8px;display:block;margin-bottom:2px}

/* how-to */
.how ol{margin:12px 0 0;padding-left:22px}
.how li{margin:8px 0}
code{font:14px Menlo,monospace;background:var(--paper2);padding:1px 5px}

footer{margin-top:48px;padding-top:16px;border-top:2px solid var(--ink);font-size:11.5px;color:var(--muted);line-height:1.7}
footer a{color:var(--muted)}
@media(max-width:380px){h1{font-size:34px}.stamp{display:none}}
"""

JS = """
(function(){
  var url = location.origin + location.pathname.replace(/index\\.html$/, "");
  if (url.charAt(url.length-1) !== "/") url += "/";
  var set = function(id, fn){ var el = document.getElementById(id); if (el) fn(el); };
  set("repoUrl", function(e){ e.textContent = url; });
  set("sileo", function(e){ e.href = "sileo://source/" + url; });
  set("zebra", function(e){ e.href = "zbra://sources/add/" + url; });
  set("cydia", function(e){ e.href = "cydia://url/https://cydia.saurik.com/api/share#?source=" + encodeURIComponent(url); });
  set("copy", function(btn){
    btn.addEventListener("click", function(){
      var done = function(){ btn.textContent = "Copied"; setTimeout(function(){ btn.textContent = "Copy"; }, 1400); };
      var fallback = function(){
        var t = document.createElement("textarea"); t.value = url; document.body.appendChild(t); t.select();
        try { document.execCommand("copy"); done(); } catch (e) {}
        document.body.removeChild(t);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(url).then(done, fallback);
      else fallback();
    });
  });
})();
"""


def esc(s):
    return html.escape(s, quote=True)


def build_site():
    items = []
    for p in meta.TWEAKS:
        feats = "".join(f"<li>{esc(f)}</li>" for f in p["features"])
        items.append(f"""
      <li class="pkg" id="{slug(p)}">
        <img class="ico" src="icons/{p['id']}.png" width="56" height="56" alt="">
        <div class="pbody">
          <h3>{esc(p['name'])}<span class="ver">{p['version']}</span></h3>
          <p class="tag">{esc(p['tagline'])}</p>
          <p>{esc(p['desc'])}</p>
          <details><summary>details</summary>
            <ul>{feats}</ul>
            <p class="where">{esc(p['where'])}</p>
            <a class="dl" href="debs/{deb_name(p)}">download .deb</a>
          </details>
        </div>
      </li>""")
    theme_figs = []
    for t in meta.THEMES:
        theme_figs.append(f"""
      <figure id="{slug(t)}">
        <img src="assets/theme-{t['key']}.png" alt="{esc(t['name'])} theme preview" width="450" height="337">
        <figcaption><b>{esc(t['name'])}</b><span>{esc(t['desc'])}</span>
          <a class="dl" href="debs/{deb_name(t)}">download .deb</a></figcaption>
      </figure>""")

    jb_items = "".join(
        f"""
    <li><b>{esc(j['name'])}</b><span class="ios">{esc(j['ios'])}</span>
      <span class="dev">{esc(j['devices'])}</span><p>{esc(j['note'])}</p></li>""" for j in meta.JAILBREAKS)

    page = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#F4EFE4">
<title>purplerepo</title>
<meta name="description" content="Jailbreak tweaks and icon themes for iOS 12, by purplesquarecube.">
<link rel="icon" href="assets/logo.png">
<style>{CSS}</style>
</head>
<body>
<div class="wrap">

  <header class="top">
    <img class="mark" src="assets/logo.png" width="72" height="72" alt="purplerepo">
    <div>
      <h1>purplerepo</h1>
      <p class="by">tweaks &amp; themes for iOS 12 &middot; by purplesquarecube</p>
    </div>
    <div class="stamp">iOS 12<br>rootful</div>
  </header>

  <section class="ticket" id="add">
    <p class="label">Repo address</p>
    <p class="url" id="repoUrl">{meta.REPO_URL}</p>
    <div class="actions">
      <a class="btn main" id="sileo" href="sileo://source/{meta.REPO_URL}">Add to Sileo</a>
      <a class="btn" id="zebra" href="zbra://sources/add/{meta.REPO_URL}">Zebra</a>
      <a class="btn" id="cydia" href="#">Cydia</a>
      <button class="btn" id="copy" type="button">Copy</button>
    </div>
  </section>

  <h2>Tweaks<span class="count">{len(meta.TWEAKS)}</span></h2>
  <p class="lede">Each one adds a page to the Settings app.</p>
  <ol class="index">{''.join(items)}
  </ol>

  <h2>Themes<span class="count">{len(meta.THEMES)}</span></h2>
  <p class="lede">{esc(meta.THEME_FOOTNOTE)}</p>
  <div class="themes">{''.join(theme_figs)}
  </div>

  <p class="lede" style="margin-top:22px"><b style="color:var(--ink)">{esc(meta.HELPERS[0]['name'])}</b>
    <span class="ver">{meta.HELPERS[0]['version']}</span> &mdash; {esc(meta.HELPERS[0]['desc'])}
    <a class="dl" href="debs/{deb_name(meta.HELPERS[0])}">download .deb</a></p>

  <h2>Works with<span class="count">{len(meta.JAILBREAKS)}</span></h2>
  <p class="lede">{esc(meta.JB_REQUIREMENTS)}</p>
  <ul class="jb">{jb_items}
  </ul>
  <p class="nope"><b>Not compatible</b>{esc(meta.JB_NOT_COMPATIBLE)}</p>
  <p class="lede" style="margin-top:14px">{esc(meta.JB_CHECKED)} These packages were not tested on every one.</p>

  <section class="how">
    <h2>Using the repo</h2>
    <ol>
      <li>Open this page on your iPhone and tap <b>Add to Sileo</b>, or paste the address into Sources.</li>
      <li>Pull down in Sileo to refresh, then install what you like.</li>
      <li>Respring. Tweaks show up in <b>Settings</b>; themes are applied from Snowboard or Anemone.</li>
    </ol>
  </section>

  <footer>
    Written for iOS 12. Provided as-is, use at your own risk.<br>
    Made by purplesquarecube &middot; <a href="{meta.GITHUB_URL}">source on GitHub</a>
  </footer>
</div>
<script>{JS}</script>
</body>
</html>
"""
    write(f"{REPO}/index.html", page)


# ------------------------------------------------------------------ README
def build_readme():
    rows = "\n".join(
        f"| **{p['name']}** | {p['version']} | {p['tagline']} {p['desc']} | {p['where']} |" for p in meta.TWEAKS)
    theme_rows = "\n".join(
        f"### {t['name']}\n{t['desc']}\n\n![{t['name']}](assets/theme-{t['key']}.png)\n" for t in meta.THEMES)
    jb_rows = "\n".join(f"| **{j['name']}** | {j['ios']} | {j['devices']} | {j['note']} |" for j in meta.JAILBREAKS)
    text = f"""![purplerepo](assets/banner.png)

# purplerepo

A small Cydia/Sileo repo of jailbreak **tweaks** and **icon themes** for **iOS 12** (rootful, arm64).
Everything here is written by [purplesquarecube](https://github.com/purplesquarecube).

**Repo address**

```
{meta.REPO_URL}
```

Open the [website]({meta.REPO_URL}) on your iPhone for one-tap buttons, or add the address by hand:

| Package manager | How |
| --- | --- |
| Sileo | Sources > + (top right) > paste the address |
| Zebra | Sources > + > paste the address |
| Cydia | Sources > Edit > Add > paste the address |

Pull down to refresh the source, then install.

## Tweaks

| Name | Version | What it does | Where |
| --- | --- | --- | --- |
{rows}

Every tweak adds its own page to the Settings app (they depend on PreferenceLoader, which Sileo installs for you).

## Themes

{meta.THEME_FOOTNOTE}

Install a theme, open **Snowboard** (or **Anemone**), tick the theme and apply it.

**Purple Link** (installed with every theme) is a small helper. {meta.HELPERS[0]['desc']} Install a new game, then respring, and it gets the matching icon. To redo the matching by hand, run `/usr/libexec/purplerepo/purplelink --all` as root.

{theme_rows}
## Works with

{meta.JB_REQUIREMENTS}

| Jailbreak | iOS | Devices | Notes |
| --- | --- | --- | --- |
{jb_rows}

**Not compatible:** {meta.JB_NOT_COMPATIBLE}

{meta.JB_CHECKED} These packages were not tested on every one.

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
    for k in ("tidy", "taplock", "quiethud", "tapfeel", "batteryline", "liquidglass", "dimmer", "plugin", "sleeptimer", "badgecolor", "umbra"):
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
