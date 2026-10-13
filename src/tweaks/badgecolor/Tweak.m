// BadgeColor - by purplesquarecube
// Recolor and resize the red notification badges on app icons.
#import "PKCommon.h"

static NSString *const kDomain = @"com.purplesquarecube.badgecolor";
static const char *kNotif = "com.purplesquarecube.badgecolor/prefsChanged";

static struct { BOOL on; CGFloat scale; } B;
static NSString *sColor = nil;
static const void *kOrigImg = &kOrigImg;

static UIColor *BHex(NSString *hex) {
    if (![hex isKindOfClass:[NSString class]] || hex.length != 6) return nil;
    unsigned int v = 0;
    [[NSScanner scannerWithString:hex] scanHexInt:&v];
    return [UIColor colorWithRed:((v >> 16) & 0xFF) / 255.0 green:((v >> 8) & 0xFF) / 255.0
                            blue:(v & 0xFF) / 255.0 alpha:1];
}

static void BLoad(void) {
    PKSync(kDomain);
    B.on = PKBool(kDomain, @"enabled", YES);
    B.scale = MAX(0.6, MIN(1.5, PKDouble(kDomain, @"size", 1.0)));
    id c = PKPref(kDomain, @"color");
    sColor = [c isKindOfClass:[NSString class]] ? c : @"7C3AED";
}

static void (*orig_badge)(id, SEL);
static void new_badge(id self, SEL _cmd) {
    orig_badge(self, _cmd);
    UIView *badge = self;
    UIImageView *bg = PKIvar(badge, @"_backgroundView");
    if ([bg isKindOfClass:[UIImageView class]]) {
        UIImage *orig = objc_getAssociatedObject(bg, kOrigImg);
        UIColor *tint = (B.on && ![sColor isEqualToString:@"default"]) ? BHex(sColor) : nil;
        if (tint && bg.image) {
            if (!orig) { orig = bg.image; objc_setAssociatedObject(bg, kOrigImg, orig, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
            bg.image = [orig imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            bg.tintColor = tint;
        } else if (orig) {
            bg.image = orig;
            objc_setAssociatedObject(bg, kOrigImg, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    CGFloat s = B.on ? B.scale : 1.0;
    badge.transform = (s == 1.0) ? CGAffineTransformIdentity : CGAffineTransformMakeScale(s, s);
}

__attribute__((constructor))
static void BInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        BLoad();
        PKHook("SBIconBadgeView", @selector(layoutSubviews), (IMP)new_badge, (IMP *)&orig_badge);
        dispatch_async(dispatch_get_main_queue(), ^{
            PKOnNotify(kNotif, ^{
                BLoad();
                Class bc = objc_getClass("SBIconBadgeView");
                PKWalkAllWindows(^(UIView *v) { if (bc && [v isKindOfClass:bc]) [v setNeedsLayout]; });
            });
        });
    }
}
