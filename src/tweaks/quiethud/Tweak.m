// QuietHUD - by purplepeanut4
// Hide the volume, brightness, ringer and rotation-lock pop-ups.
#import "PKCommon.h"

static NSString *const kDomain = @"com.purplesquarecube.quiethud";
static const char *kNotif = "com.purplesquarecube.quiethud/prefsChanged";

static struct { BOOL on, volume, brightness, ringer, rotation; } T;

static void QLoad(void) {
    PKSync(kDomain);
    T.on         = PKBool(kDomain, @"enabled", YES);
    T.volume     = PKBool(kDomain, @"volume", YES);
    T.brightness = PKBool(kDomain, @"brightness", NO);
    T.ringer     = PKBool(kDomain, @"ringer", NO);
    T.rotation   = PKBool(kDomain, @"rotation", NO);
}

static BOOL QShouldHideView(id view) {
    if (!T.on || !view) return NO;
    if (T.volume     && [view isKindOfClass:objc_getClass("SBVolumeHUDView")])       return YES;
    if (T.brightness && [view isKindOfClass:objc_getClass("SBBrightnessHUDView")])   return YES;
    if (T.ringer     && [view isKindOfClass:objc_getClass("SBRingerHUDView")])       return YES;
    if (T.rotation   && [view isKindOfClass:objc_getClass("SBRotationLockHUDView")]) return YES;
    return NO;
}

// SBHUDController: every classic HUD goes through here
static void (*orig_present)(id, SEL, id);
static void new_present(id self, SEL _cmd, id view) {
    if (QShouldHideView(view)) return;
    orig_present(self, _cmd, view);
}
static void (*orig_presentDelay)(id, SEL, id, double);
static void new_presentDelay(id self, SEL _cmd, id view, double d) {
    if (QShouldHideView(view)) return;
    orig_presentDelay(self, _cmd, view, d);
}

// VolumeControl: volume HUD on iOS 12
static void (*orig_volHUD)(id, SEL, int, float);
static void new_volHUD(id self, SEL _cmd, int mode, float vol) {
    if (T.on && T.volume) return;
    orig_volHUD(self, _cmd, mode, vol);
}

// Ringer switch HUD
static void (*orig_ringer)(id, SEL, int);
static void new_ringer(id self, SEL _cmd, int a) {
    if (T.on && T.ringer) return;
    orig_ringer(self, _cmd, a);
}

// Brightness slider: ask for "no HUD"
static void (*orig_bright)(id, SEL, float, BOOL);
static void new_bright(id self, SEL _cmd, float level, BOOL show) {
    orig_bright(self, _cmd, level, (T.on && T.brightness) ? NO : show);
}

__attribute__((constructor))
static void QInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        QLoad();
        PKHook("SBHUDController", @selector(presentHUDView:), (IMP)new_present, (IMP *)&orig_present);
        PKHook("SBHUDController", @selector(presentHUDView:autoDismissWithDelay:), (IMP)new_presentDelay, (IMP *)&orig_presentDelay);
        PKHook("VolumeControl", NSSelectorFromString(@"_presentVolumeHUDWithMode:volume:"), (IMP)new_volHUD, (IMP *)&orig_volHUD);
        PKHookClassMethod("SBRingerHUDController", NSSelectorFromString(@"activate:"), (IMP)new_ringer, (IMP *)&orig_ringer);
        PKHook("SBBrightnessController", NSSelectorFromString(@"_setBrightnessLevel:showHUD:"), (IMP)new_bright, (IMP *)&orig_bright);
        dispatch_async(dispatch_get_main_queue(), ^{ PKOnNotify(kNotif, ^{ QLoad(); }); });
    }
}
