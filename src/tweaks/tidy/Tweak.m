// Tidy - by purplepeanut4
// Hide icon labels, badges and page dots; make the dock background clear.
#import "PKCommon.h"

static NSString *const kDomain = @"com.purplesquarecube.tidy";
static const char *kNotif    = "com.purplesquarecube.tidy/prefsChanged";
static const char *kRespring = "com.purplesquarecube.tidy/respring";

static struct { BOOL on, labels, badges, dots, dock; } T;
static const void *kLabelKey = &kLabelKey, *kBadgeKey = &kBadgeKey;

static void TLoad(void) {
    PKSync(kDomain);
    T.on     = PKBool(kDomain, @"enabled", YES);
    T.labels = PKBool(kDomain, @"labels", YES);
    T.badges = PKBool(kDomain, @"badges", NO);
    T.dots   = PKBool(kDomain, @"dots", NO);
    T.dock   = PKBool(kDomain, @"dock", NO);
}

// hide a subview, remembering that *we* hid it so we can restore it later
static void TSetHidden(UIView *host, NSString *ivar, const void *flagKey, BOOL hide) {
    UIView *v = PKIvar(host, ivar);
    if (![v isKindOfClass:[UIView class]]) return;
    if (hide) {
        if (!v.hidden) { v.hidden = YES; objc_setAssociatedObject(host, flagKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    } else if ([objc_getAssociatedObject(host, flagKey) boolValue]) {
        v.hidden = NO;
        objc_setAssociatedObject(host, flagKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

// ---- icons: labels + badges ----
static void (*orig_iconLayout)(id, SEL);
static void new_iconLayout(id self, SEL _cmd) {
    orig_iconLayout(self, _cmd);
    TSetHidden(self, @"_labelView", kLabelKey, T.on && T.labels);
    TSetHidden(self, @"_accessoryView", kBadgeKey, T.on && T.badges);
}

// ---- page dots ----
static void (*orig_dotsAlpha)(id, SEL, CGFloat);
static void new_dotsAlpha(id self, SEL _cmd, CGFloat a) {
    orig_dotsAlpha(self, _cmd, (T.on && T.dots) ? 0 : a);
}
static void (*orig_dotsHidden)(id, SEL, BOOL);
static void new_dotsHidden(id self, SEL _cmd, BOOL h) {
    orig_dotsHidden(self, _cmd, (T.on && T.dots) ? YES : h);
}

// ---- dock background ----
static void (*orig_dockAlpha)(id, SEL, double);
static void new_dockAlpha(id self, SEL _cmd, double a) {
    orig_dockAlpha(self, _cmd, (T.on && T.dock) ? 0 : a);
}

static void TRefresh(void) {
    TLoad();
    Class pc = objc_getClass("SBIconListPageControl");
    Class dk = objc_getClass("SBDockView");
    PKWalkAllWindows(^(UIView *v) {
        if ([v isKindOfClass:objc_getClass("SBIconView")]) [v setNeedsLayout];
        if (pc && [v isKindOfClass:pc]) {
            BOOL hide = T.on && T.dots;
            v.hidden = hide;
            v.alpha = hide ? 0 : 1;
        }
        if (dk && [v isKindOfClass:dk]) {
            ((void (*)(id, SEL, double))objc_msgSend)(v, NSSelectorFromString(@"setBackgroundAlpha:"),
                                                       (T.on && T.dock) ? 0.0 : 1.0);
        }
    });
}

static void TRespring(void) {
    Class fbs = NSClassFromString(@"FBSystemService");
    id svc = fbs ? ((id (*)(id, SEL))objc_msgSend)(fbs, NSSelectorFromString(@"sharedInstance")) : nil;
    SEL sel = NSSelectorFromString(@"exitAndRelaunch:");
    if (svc && [svc respondsToSelector:sel]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(svc, sel, YES);
    } else {
        exit(0);
    }
}

__attribute__((constructor))
static void TInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        TLoad();
        PKHook("SBIconView", @selector(layoutSubviews), (IMP)new_iconLayout, (IMP *)&orig_iconLayout);
        PKHook("SBIconListPageControl", @selector(setAlpha:), (IMP)new_dotsAlpha, (IMP *)&orig_dotsAlpha);
        PKHook("SBIconListPageControl", @selector(setHidden:), (IMP)new_dotsHidden, (IMP *)&orig_dotsHidden);
        PKHook("SBDockView", @selector(setBackgroundAlpha:), (IMP)new_dockAlpha, (IMP *)&orig_dockAlpha);
        dispatch_async(dispatch_get_main_queue(), ^{
            PKOnNotify(kNotif, ^{ TRefresh(); });
            PKOnNotify(kRespring, ^{ TRespring(); });
        });
    }
}
