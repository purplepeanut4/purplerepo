// TapFeel - by purplesquarecube
// A sound and a little bounce when you tap an app icon.
#import "PKCommon.h"
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const kDomain = @"com.purplesquarecube.tapfeel";
static const char *kNotif = "com.purplesquarecube.tapfeel/prefsChanged";

static struct { BOOL on, sound, bounce; int soundID; double strength; } T;

static void FLoad(void) {
    PKSync(kDomain);
    T.on       = PKBool(kDomain, @"enabled", YES);
    T.sound    = PKBool(kDomain, @"sound", YES);
    T.bounce   = PKBool(kDomain, @"bounce", YES);
    T.soundID  = (int)PKInt(kDomain, @"soundID", 1104);
    T.strength = MAX(0.05, MIN(0.4, PKDouble(kDomain, @"strength", 0.18)));
}

static void FBounce(UIView *v) {
    CAKeyframeAnimation *a = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    a.values = @[@1.0, @(1.0 - T.strength), @(1.0 + T.strength * 0.35), @(1.0 - T.strength * 0.1), @1.0];
    a.keyTimes = @[@0.0, @0.25, @0.55, @0.8, @1.0];
    a.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
                          [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                          [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                          [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    a.duration = 0.38;
    [v.layer addAnimation:a forKey:@"tapfeel.bounce"];
}

static void (*orig_tapped)(id, SEL, id);
static void new_tapped(id self, SEL _cmd, id iconView) {
    @try {
        if (T.on && iconView) {
            id icon = [iconView respondsToSelector:@selector(icon)]
                ? ((id (*)(id, SEL))objc_msgSend)(iconView, @selector(icon)) : nil;
            NSString *bid = [icon respondsToSelector:@selector(applicationBundleID)]
                ? ((id (*)(id, SEL))objc_msgSend)(icon, @selector(applicationBundleID)) : nil;
            BOOL isEditing = [self respondsToSelector:@selector(isEditing)] &&
                ((BOOL (*)(id, SEL))objc_msgSend)(self, @selector(isEditing));
            if (!isEditing && [bid isKindOfClass:[NSString class]] && bid.length) {
                if (T.sound && T.soundID > 0) AudioServicesPlaySystemSound((SystemSoundID)T.soundID);
                if (T.bounce) FBounce(iconView);
            }
        }
    } @catch (NSException *e) {}
    orig_tapped(self, _cmd, iconView);
}

__attribute__((constructor))
static void FInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        FLoad();
        PKHook("SBIconController", @selector(iconTapped:), (IMP)new_tapped, (IMP *)&orig_tapped);
        dispatch_async(dispatch_get_main_queue(), ^{ PKOnNotify(kNotif, ^{ FLoad(); }); });
    }
}
