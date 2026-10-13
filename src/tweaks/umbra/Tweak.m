// Umbra - by purplesquarecube
// A dark mode for iOS 12, built on iOS's own Smart Invert. Invert is switched on while a chosen app is
// in front and off again when you leave it, so you can pick which apps go dark.
#import "PKCommon.h"

// libAccessibility (private)
extern void _AXSInvertColorsSetEnabled(Boolean enabled);
extern Boolean _AXSInvertColorsEnabled(void);

static NSString *const kDomain = @"com.purplesquarecube.umbra";
static const char *kNotif = "com.purplesquarecube.umbra/prefsChanged";

static NSString *sHintBundle = nil;
static dispatch_block_t sPending = nil;

static BOOL UWeEnabled(void) { return PKBool(kDomain, @"weEnabled", NO); }
static void USetWeEnabled(BOOL v) {
    CFPreferencesSetAppValue(CFSTR("weEnabled"), v ? kCFBooleanTrue : kCFBooleanFalse, (__bridge CFStringRef)kDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
}

static NSString *UFrontBundle(void) {
    UIApplication *ui = [UIApplication sharedApplication];
    SEL sel = NSSelectorFromString(@"_accessibilityFrontMostApplication");
    if (ui && [ui respondsToSelector:sel]) {
        id app = ((id (*)(id, SEL))objc_msgSend)(ui, sel);
        if (app && [app respondsToSelector:@selector(bundleIdentifier)])
            return ((id (*)(id, SEL))objc_msgSend)(app, @selector(bundleIdentifier));
        return nil;                                  // home screen / lock screen
    }
    return sHintBundle;
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

static void UApply(void) {
    PKSync(kDomain);
    BOOL want = NO;
    if (PKBool(kDomain, @"enabled", NO) && UInSchedule()) {
        NSString *bid = UFrontBundle();
        if (bid.length) {
            id pref = PKPref(kDomain, [@"app." stringByAppendingString:bid]);
            want = pref ? [pref boolValue] : YES;      // apps are dark unless switched off
        } else {
            want = PKBool(kDomain, @"system", NO);     // home screen and system UI
        }
    }
    BOOL now = _AXSInvertColorsEnabled();
    if (want && !now) {
        _AXSInvertColorsSetEnabled(true);
        USetWeEnabled(YES);
    } else if (!want && now && UWeEnabled()) {          // only undo what we turned on ourselves
        _AXSInvertColorsSetEnabled(false);
        USetWeEnabled(NO);
    }
}

static void USchedule(double delay) {
    if (sPending) dispatch_block_cancel(sPending);
    sPending = dispatch_block_create(0, ^{ UApply(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), sPending);
}

static void (*orig_front)(id, SEL, id);
static void new_front(id self, SEL _cmd, id display) {
    orig_front(self, _cmd, display);
    NSString *bid = nil;
    Class sbApp = NSClassFromString(@"SBApplication");
    if (display && sbApp && [display isKindOfClass:sbApp] && [display respondsToSelector:@selector(bundleIdentifier)])
        bid = ((id (*)(id, SEL))objc_msgSend)(display, @selector(bundleIdentifier));
    sHintBundle = bid;
    USchedule(0.25);
}

__attribute__((constructor))
static void UInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        PKHook("SpringBoard", NSSelectorFromString(@"frontDisplayDidChange:"), (IMP)new_front, (IMP *)&orig_front);
        dispatch_async(dispatch_get_main_queue(), ^{
            PKOnNotify(kNotif, ^{ USchedule(0.05); });
            notify_register_dispatch("com.apple.springboard.lockstate", &(int){0}, dispatch_get_main_queue(),
                                     ^(int t) { USchedule(0.2); });
            [NSTimer scheduledTimerWithTimeInterval:3 repeats:YES block:^(NSTimer *t) { UApply(); }];  // safety net + schedule
            USchedule(1.0);
        });
    }
}
