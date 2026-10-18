// IconStyle - by purplepeanut4
// A soft shadow (or glow) under app icons, and an adjustable icon size.
#import "PKCommon.h"
#import <QuartzCore/QuartzCore.h>

static NSString *const kDomain = @"com.purplesquarecube.iconstyle";
static const char *kNotif = "com.purplesquarecube.iconstyle/prefsChanged";

static struct { BOOL on, shadow; CGFloat opacity, radius, offset, scale; } I;
static NSString *sColor = nil;
static const void *kScaledKey = &kScaledKey, *kShadowKey = &kShadowKey;

static UIColor *IHex(NSString *hex) {
    unsigned int v = 0;
    if ([hex isKindOfClass:[NSString class]] && hex.length == 6) [[NSScanner scannerWithString:hex] scanHexInt:&v];
    return [UIColor colorWithRed:((v >> 16) & 0xFF) / 255.0 green:((v >> 8) & 0xFF) / 255.0 blue:(v & 0xFF) / 255.0 alpha:1];
}

static void ILoad(void) {
    PKSync(kDomain);
    I.on      = PKBool(kDomain, @"enabled", YES);
    I.shadow  = PKBool(kDomain, @"shadow", YES);
    I.opacity = MAX(0, MIN(1, PKDouble(kDomain, @"opacity", 0.35)));
    I.radius  = MAX(0, MIN(24, PKDouble(kDomain, @"radius", 8)));
    I.offset  = MAX(0, MIN(14, PKDouble(kDomain, @"offset", 5)));
    I.scale   = MAX(0.75, MIN(1.2, PKDouble(kDomain, @"scale", 1.0)));
    id c = PKPref(kDomain, @"color");
    sColor = [c isKindOfClass:[NSString class]] ? c : @"000000";
}

static void (*orig_icon)(id, SEL);
static void new_icon(id self, SEL _cmd) {
    orig_icon(self, _cmd);
    UIView *v = self;
    CGSize s = v.bounds.size;
    if (s.width < 30 || s.width > 140) return;           // only real home-screen icon images

    if (I.on && I.shadow) {
        v.layer.shadowColor = IHex(sColor).CGColor;
        v.layer.shadowOpacity = I.opacity;
        v.layer.shadowRadius = I.radius;
        v.layer.shadowOffset = CGSizeMake(0, I.offset);
        v.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:v.bounds cornerRadius:s.width * 0.2237].CGPath;
        objc_setAssociatedObject(v, kShadowKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if ([objc_getAssociatedObject(v, kShadowKey) boolValue]) {
        v.layer.shadowOpacity = 0;
        objc_setAssociatedObject(v, kShadowKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    BOOL scaled = (I.on && fabs(I.scale - 1.0) > 0.005);
    if (scaled) {
        v.transform = CGAffineTransformMakeScale(I.scale, I.scale);
        objc_setAssociatedObject(v, kScaledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if ([objc_getAssociatedObject(v, kScaledKey) boolValue]) {
        v.transform = CGAffineTransformIdentity;
        objc_setAssociatedObject(v, kScaledKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

__attribute__((constructor))
static void IInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        ILoad();
        PKHook("SBIconImageView", @selector(layoutSubviews), (IMP)new_icon, (IMP *)&orig_icon);
        dispatch_async(dispatch_get_main_queue(), ^{
            PKOnNotify(kNotif, ^{
                ILoad();
                Class c = objc_getClass("SBIconImageView");
                PKWalkAllWindows(^(UIView *v) { if (c && [v isKindOfClass:c]) [v setNeedsLayout]; });
            });
        });
    }
}
