// Umbra - by purplepeanut4
// A dark mode for iOS 12, built on iOS's own Smart Invert. Invert is switched on while a chosen app is
// in front and off again when you leave it, so you can pick which apps go dark.
//
// This file runs in two places:
//   * every app: marks big pictures as "do not invert", so photos keep their real colours
//   * SpringBoard: switches Smart Invert on and off as you move between apps
#import "PKCommon.h"

// libAccessibility (private)
extern void _AXSInvertColorsSetEnabled(Boolean enabled);
extern Boolean _AXSInvertColorsEnabled(void);
extern void _AXSClassicInvertColorsSetEnabled(Boolean enabled);
extern Boolean _AXSClassicInvertColorsEnabled(void);

static NSString *const kDomain = @"com.purplesquarecube.umbra";
static const char *kNotif = "com.purplesquarecube.umbra/prefsChanged";

#pragma mark - Pictures stay normal (every app)

static BOOL sPhotos = YES;

static void UPhotosLoad(void) {
    PKSync(kDomain);
    sPhotos = PKBool(kDomain, @"photos", YES);
}

static void UProtect(UIImageView *v) {
    if (!sPhotos) return;
    UIImage *img = v.image;
    if (!img) return;
    if (img.renderingMode == UIImageRenderingModeAlwaysTemplate) return;     // icons take the tint colour
    CGSize s = img.size, b = v.bounds.size;
    if (MIN(s.width, s.height) < 64) return;                                   // small glyphs and icons invert normally
    if (b.width > 0 && MIN(b.width, b.height) < 44) return;
    SEL set = NSSelectorFromString(@"setAccessibilityIgnoresInvertColors:");
    SEL get = NSSelectorFromString(@"accessibilityIgnoresInvertColors");
    if (![v respondsToSelector:set] || ![v respondsToSelector:get]) return;
    if (!((BOOL (*)(id, SEL))objc_msgSend)(v, get)) ((void (*)(id, SEL, BOOL))objc_msgSend)(v, set, YES);
}

static void (*orig_setImage)(id, SEL, id);
static void new_setImage(id self, SEL _cmd, id image) {
    orig_setImage(self, _cmd, image);
    UProtect(self);
}
static void (*orig_moveWin)(id, SEL);
static void new_moveWin(id self, SEL _cmd) {
    orig_moveWin(self, _cmd);
    if ([(UIView *)self window]) UProtect(self);
}

#pragma mark - SpringBoard: when to invert

static BOOL sHookSeen = NO;                // the front-app hook has reported at least once
static NSString *sFront = nil;             // front app according to that hook (nil = Home Screen / system UI)
static BOOL sLocked = NO;
static NSInteger sGen = 0;

static BOOL UWeEnabled(void) { return PKBool(kDomain, @"weEnabled", NO); }
static void USetWeEnabled(BOOL v) {
    CFPreferencesSetAppValue(CFSTR("weEnabled"), v ? kCFBooleanTrue : kCFBooleanFalse, (__bridge CFStringRef)kDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
}

// only used if the hook never fires on some build
static NSString *UFrontAX(void) {
    UIApplication *ui = [UIApplication sharedApplication];
    SEL sel = NSSelectorFromString(@"_accessibilityFrontMostApplication");
    if (ui && [ui respondsToSelector:sel]) {
        id app = ((id (*)(id, SEL))objc_msgSend)(ui, sel);
        if (app && [app respondsToSelector:@selector(bundleIdentifier)])
            return ((id (*)(id, SEL))objc_msgSend)(app, @selector(bundleIdentifier));
    }
    return nil;
}

static BOOL UInSchedule(void) {
    if (PKInt(kDomain, @"schedule", 0) == 0) return YES;
    NSInteger start = PKInt(kDomain, @"start", 20), end = PKInt(kDomain, @"end", 7);
    if (start == end) return YES;
    NSDateComponents *dc = [[NSCalendar currentCalendar] components:(NSCalendarUnitHour | NSCalendarUnitMinute)
                                                           fromDate:[NSDate date]];
    double now = dc.hour + dc.minute / 60.0;
    if (start < end) return now >= start && now < end;
    return now >= start || now < end;
}

static BOOL UWant(void) {
    if (!PKBool(kDomain, @"enabled", NO) || !UInSchedule()) return NO;
    NSString *bid = sLocked ? nil : (sHookSeen ? sFront : UFrontAX());
    if (bid.length) {
        id pref = PKPref(kDomain, [@"app." stringByAppendingString:bid]);
        return pref ? [pref boolValue] : YES;              // apps are dark unless switched off
    }
    return PKBool(kDomain, @"system", NO);                 // Home Screen, lock screen and system UI
}

static void UApply(void) {
    PKSync(kDomain);
    BOOL want = UWant();
    BOOL on = _AXSInvertColorsEnabled();
    if (want) {
        // always Smart Invert. Classic Invert would flip pictures and every app's real colours.
        if (_AXSClassicInvertColorsEnabled()) _AXSClassicInvertColorsSetEnabled(false);
        if (!on) { _AXSInvertColorsSetEnabled(true); USetWeEnabled(YES); }
    } else if (on && UWeEnabled()) {                       // only undo what we turned on ourselves
        _AXSInvertColorsSetEnabled(false);
        USetWeEnabled(NO);
    }
}

// apply straight away, then re-check a few times while the app transition settles
static void UKick(void) {
    NSInteger gen = ++sGen;
    UApply();
    for (NSNumber *d in @[@0.15, @0.5, @1.2]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([d doubleValue] * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ if (gen == sGen) UApply(); });
    }
}

static void (*orig_front)(id, SEL, id);
static void new_front(id self, SEL _cmd, id display) {
    orig_front(self, _cmd, display);
    NSString *bid = nil;
    Class sbApp = NSClassFromString(@"SBApplication");
    if (display && sbApp && [display isKindOfClass:sbApp] && [display respondsToSelector:@selector(bundleIdentifier)])
        bid = ((id (*)(id, SEL))objc_msgSend)(display, @selector(bundleIdentifier));
    sFront = bid;
    sHookSeen = YES;
    UKick();
}

__attribute__((constructor))
static void UInit(void) {
    @autoreleasepool {
        NSString *me = [[NSBundle mainBundle] bundleIdentifier];
        BOOL isSB = [me isEqualToString:@"com.apple.springboard"];

        UPhotosLoad();
        PKHook("UIImageView", @selector(setImage:), (IMP)new_setImage, (IMP *)&orig_setImage);
        PKHook("UIImageView", @selector(didMoveToWindow), (IMP)new_moveWin, (IMP *)&orig_moveWin);
        dispatch_async(dispatch_get_main_queue(), ^{
            PKOnNotify(kNotif, ^{ UPhotosLoad(); if (isSB) UKick(); });
        });
        if (!isSB) return;

        PKHook("SpringBoard", NSSelectorFromString(@"frontDisplayDidChange:"), (IMP)new_front, (IMP *)&orig_front);
        dispatch_async(dispatch_get_main_queue(), ^{
            int tok;
            notify_register_dispatch("com.apple.springboard.lockstate", &tok, dispatch_get_main_queue(), ^(int t) {
                uint64_t state = 0;
                notify_get_state(t, &state);
                sLocked = (state != 0);
                UKick();
            });
            [NSTimer scheduledTimerWithTimeInterval:5 repeats:YES block:^(NSTimer *t) { UApply(); }];   // safety net + schedule
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ UKick(); });
        });
    }
}
