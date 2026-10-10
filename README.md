# PurpleTweaks (iOS 12)

PurpleTweaks is a jailbreak tweak project targeting **iOS 12.0–12.5.8**, including iOS 12.5.8.

It provides a Settings.app preference pane with ten independent options and a Liquid Glass-inspired appearance mode. The Liquid Glass option is an approximation using UIKit blur and translucent layers; iOS 12 does not contain Apple's newer native Liquid Glass APIs, so this cannot reproduce the exact newer system material.

## Options

1. Hide Home Screen icon labels
2. Rounded app icon corners
3. Translucent dock
4. Translucent folder backgrounds
5. Blur selected system surfaces
6. Reduce selected interface animations
7. Hide page dots
8. Hide the dock background
9. Use a dark translucent surface style where supported by this tweak
10. Liquid Glass-inspired blur and highlight styling

## Compatibility and limitations

- The package declares iOS 12.0 as its minimum version and uses Objective-C / Theos / Cydia Substrate.
- This repository contains source code, not a prebuilt or device-tested Debian package.
- Jailbreak, bootstrap, architecture, and installed PreferenceLoader/Substrate versions can affect compatibility.
- SpringBoard internals vary between devices and jailbreaks. Test on a device you can restore and disable/remove the tweak if SpringBoard becomes unstable.
- The Liquid Glass setting is a visual approximation, not Apple's native Liquid Glass implementation.

## Build

Build with Theos and an iOS SDK that includes the iOS 12-compatible UIKit and Preferences headers. Install the PreferenceLoader package on the jailbroken device so the preference pane can appear in Settings.

The project is intentionally scoped to legacy/rootful iOS 12 jailbreak packaging. It is not an App Store app and does not modify iOS system files outside the normal tweak injection and preference locations.
