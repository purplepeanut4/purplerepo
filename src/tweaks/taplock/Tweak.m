// TapLock - by purplepeanut4
// Double-tap empty space on the Home Screen (or the Dock) to lock the device.
#import "PKCommon.h"

static NSString *const kDomain = @"com.purplesquarecube.taplock";
static const char *kNotif = "com.purplesquarecube.taplock/prefsChanged";

static struct { BOOL on, home, dock; } T;
static const void *kGestureKey = &kGestureKey;

static void TLoad(void) {
    PKSync(kDomain);
    T.on   = PKBool(kDomain, @"enabled", YES);
    T.home = PKBool(kDomain, @"home", YES);
    T.dock = PKBool(kDomain, @"dock", YES);
}

static void TLock(void) {
    UIApplication *app = [UIApplication sharedApplication];
    SEL sel = NSSelectorFromString(@"_simulateLockButtonPress");
    if ([app respondsToSelector:sel]) {
        ((void (*)(id, SEL))objc_msgSend)(app, sel);
        return;
    }
    Class mgr = NSClassFromString(@"SBLockScreenManager");
    id m = mgr ? ((id (*)(id, SEL))objc_msgSend)(mgr, NSSelectorFromString(@"sharedInstance")) : nil;
    SEL l = NSSelectorFromString(@"lockUIFromSource:withOptions:");
    if (m && [m respondsToSelector:l]) ((void (*)(id, SEL, int, id))objc_msgSend)(m, l, 1, nil);
}

@interface TLHandler : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)shared;
- (void)tapped:(UITapGestureRecognizer *)g;
@end

@implementation TLHandler
+ (instancetype)shared {
    static TLHandler *h; static dispatch_once_t once;
    dispatch_once(&once, ^{ h = [TLHandler new]; });
    return h;
}
- (void)tapped:(UITapGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateRecognized && T.on) TLock();
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g { return T.on; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)o { return YES; }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldReceiveTouch:(UITouch *)touch {
    if (!T.on) return NO;
    UIView *host = g.view;
    BOOL isDock = [NSStringFromClass([host class]) hasPrefix:@"SBDock"];
    if (isDock ? !T.dock : !T.home) return NO;
    // ignore taps on icons, widgets, search, controls and text fields
    for (UIView *v = touch.view; v && v != host.superview; v = v.superview) {
        NSString *n = NSStringFromClass([v class]);
        if ([n hasPrefix:@"SBIconView"] || [n hasPrefix:@"SBFolderIconView"] ||
            [n hasPrefix:@"WG"] || [n containsString:@"Widget"] || [n containsString:@"Search"] ||
            [n containsString:@"Platter"] || [n hasPrefix:@"SBFolderTitle"]) return NO;
        if ([v isKindOfClass:[UIControl class]] || [v isKindOfClass:[UITextField class]]) return NO;
        if (v == host) break;
    }
    return YES;
}
@end

static void TAttach(UIView *v) {
    if (objc_getAssociatedObject(v, kGestureKey)) return;
    UITapGestureRecognizer *g = [[UITapGestureRecognizer alloc] initWithTarget:[TLHandler shared]
                                                                       action:@selector(tapped:)];
    g.numberOfTapsRequired = 2;
    g.cancelsTouchesInView = NO;
    g.delaysTouchesBegan = NO;
    g.delaysTouchesEnded = NO;
    g.delegate = [TLHandler shared];
    [v addGestureRecognizer:g];
    objc_setAssociatedObject(v, kGestureKey, g, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void (*orig_rootMove)(id, SEL);
static void new_rootMove(id self, SEL _cmd) {
    orig_rootMove(self, _cmd);
    if ([(UIView *)self window]) TAttach(self);
}
static void (*orig_dockMove)(id, SEL);
static void new_dockMove(id self, SEL _cmd) {
    orig_dockMove(self, _cmd);
    if ([(UIView *)self window]) TAttach(self);
}

__attribute__((constructor))
static void TInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        TLoad();
        PKHook("SBRootFolderView", @selector(didMoveToWindow), (IMP)new_rootMove, (IMP *)&orig_rootMove);
        PKHook("SBDockView", @selector(didMoveToWindow), (IMP)new_dockMove, (IMP *)&orig_dockMove);
        dispatch_async(dispatch_get_main_queue(), ^{
            PKOnNotify(kNotif, ^{ TLoad(); });
            // views that already exist when the tweak loads
            PKWalkAllWindows(^(UIView *v) {
                NSString *n = NSStringFromClass([v class]);
                if ([n isEqualToString:@"SBRootFolderView"] || [n isEqualToString:@"SBDockView"]) TAttach(v);
            });
        });
    }
}
