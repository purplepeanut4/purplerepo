// LaunchFX - by purplesquarecube
// Plays a custom reveal animation when you tap an app icon on the Home Screen.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "LFXEngine.h"

static NSString *const kDomain = @"com.purplesquarecube.launchfx";

static id LFXPref(NSString *key) {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                       (__bridge CFStringRef)kDomain));
}
static BOOL LFXBool(NSString *key, BOOL def) {
    id v = LFXPref(key);
    return v ? [v boolValue] : def;
}

// average colour of an app icon (used by the "Match App Icon" colour option)
static UIColor *LFXAverageColor(UIImage *img) {
    if (!img || !img.CGImage) return nil;
    unsigned char px[4] = {0, 0, 0, 0};
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(px, 1, 1, 8, 4, cs,
                                             kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(cs);
    if (!ctx) return nil;
    CGContextSetInterpolationQuality(ctx, kCGInterpolationMedium);
    CGContextDrawImage(ctx, CGRectMake(0, 0, 1, 1), img.CGImage);
    CGContextRelease(ctx);
    if (px[3] == 0) return nil;
    CGFloat a = px[3] / 255.0;
    return [UIColor colorWithRed:(px[0] / 255.0) / a green:(px[1] / 255.0) / a
                            blue:(px[2] / 255.0) / a alpha:1];
}

static UIColor *LFXIconColor(NSString *bundleID) {
    SEL sel = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
    if (![UIImage respondsToSelector:sel]) return nil;
    UIImage *img = ((UIImage *(*)(id, SEL, NSString *, int, CGFloat))objc_msgSend)(
        [UIImage class], sel, bundleID, 2, [UIScreen mainScreen].scale);
    return LFXAverageColor(img);
}

static void LFXHandleTap(id iconController, id iconView) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
    if (!LFXBool(@"enabled", YES)) return;
    if (!iconView) return;

    // ignore taps while rearranging icons
    if ([iconController respondsToSelector:@selector(isEditing)] &&
        ((BOOL (*)(id, SEL))objc_msgSend)(iconController, @selector(isEditing))) return;

    id icon = [iconView respondsToSelector:@selector(icon)]
        ? ((id (*)(id, SEL))objc_msgSend)(iconView, @selector(icon)) : nil;
    NSString *bid = [icon respondsToSelector:@selector(applicationBundleID)]
        ? ((id (*)(id, SEL))objc_msgSend)(icon, @selector(applicationBundleID)) : nil;
    if (![bid isKindOfClass:[NSString class]] || !bid.length) return;   // folders, widgets...

    // per-app switch (default on)
    id appPref = LFXPref([@"app." stringByAppendingString:bid]);
    if (appPref && ![appPref boolValue]) return;

    // which animation
    NSInteger idx = 0;
    id ap = LFXPref(@"animation");
    if (ap) idx = [ap integerValue];
    if (LFXBool(@"shuffle", NO)) idx = arc4random_uniform(LFX_COUNT);
    if (idx < 0 || idx >= LFX_COUNT) idx = 0;

    // duration
    double dur = 0.6;
    id dp = LFXPref(@"duration");
    if (dp) dur = [dp doubleValue];
    if (dur < 0.25) dur = 0.25;
    if (dur > 1.5) dur = 1.5;

    // colour
    NSString *hex = LFXPref(@"color");
    if (![hex isKindOfClass:[NSString class]]) hex = @"7C3AED";
    UIColor *color = nil;
    if ([hex isEqualToString:@"auto"]) color = LFXIconColor(bid);
    if (!color) color = LFXColorFromHex([hex isEqualToString:@"auto"] ? @"7C3AED" : hex);

    // where the effect grows from: the tapped icon
    CGPoint origin = CGPointMake([UIScreen mainScreen].bounds.size.width / 2,
                                 [UIScreen mainScreen].bounds.size.height / 2);
    if ([iconView respondsToSelector:@selector(iconImageCenter)]) {
        CGPoint c = ((CGPoint (*)(id, SEL))objc_msgSend)(iconView, @selector(iconImageCenter));
        CGPoint w = [(UIView *)iconView convertPoint:c toView:nil];
        if (w.x > 0 || w.y > 0) origin = w;
    }

    // hold the cover while iOS does its own zoom underneath, then reveal the app
    LFXPlay(idx, color, origin, 0.30, dur, nil);
}

static void (*orig_iconTapped)(id, SEL, id);
static void new_iconTapped(id self, SEL _cmd, id iconView) {
    @try { LFXHandleTap(self, iconView); } @catch (NSException *e) {}
    orig_iconTapped(self, _cmd, iconView);
}

__attribute__((constructor))
static void LFXInit(void) {
    @autoreleasepool {
        NSString *me = [[NSBundle mainBundle] bundleIdentifier];
        if (![me isEqualToString:@"com.apple.springboard"]) return;

        Class cls = NSClassFromString(@"SBIconController");
        Method m = cls ? class_getInstanceMethod(cls, @selector(iconTapped:)) : NULL;
        if (!m) { NSLog(@"[LaunchFX] SBIconController iconTapped: not found"); return; }
        orig_iconTapped = (void (*)(id, SEL, id))method_getImplementation(m);
        method_setImplementation(m, (IMP)new_iconTapped);
    }
}
