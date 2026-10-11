// Liquid Glass for iOS 12 - by purplesquarecube
//
// iOS 12 has no real "Liquid Glass", so this recreates the look on top of the
// system blurs: a bright glass edge, a soft specular sheen, and a highlight that
// slides as you tilt the phone. Applied to the Dock, open folders, notification
// and Control Center panels, and (optionally) app icons.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <notify.h>

static NSString *const kDomain = @"com.purplesquarecube.liquidglass";
static const char *kNotif = "com.purplesquarecube.liquidglass/prefsChanged";

#pragma mark - Preferences

typedef struct {
    BOOL enabled, dock, folders, panels, icons, tilt;
    CGFloat edge, shine, dockRadius;
    int tint;   // 0 none, 1 light, 2 dark, 3 purple
} LGPrefs;

static LGPrefs P;

static id LGPref(NSString *key) {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                       (__bridge CFStringRef)kDomain));
}
static BOOL LGBool(NSString *key, BOOL def) { id v = LGPref(key); return v ? [v boolValue] : def; }
static CGFloat LGFloat(NSString *key, CGFloat def) { id v = LGPref(key); return v ? [v doubleValue] : def; }

static void LGLoadPrefs(void) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
    P.enabled    = LGBool(@"enabled", YES);
    P.dock       = LGBool(@"dock", YES);
    P.folders    = LGBool(@"folders", YES);
    P.panels     = LGBool(@"panels", YES);
    P.icons      = LGBool(@"icons", NO);
    P.tilt       = LGBool(@"tilt", YES);
    P.edge       = MAX(0, MIN(1, LGFloat(@"edge", 0.8)));
    P.shine      = MAX(0, MIN(1, LGFloat(@"shine", 0.45)));
    P.dockRadius = MAX(8, MIN(44, LGFloat(@"dockRadius", 28)));
    id t = LGPref(@"tint");
    P.tint = t ? [t intValue] : 1;
}

#pragma mark - The glass overlay

@interface LGGlassOverlay : UIView
@property (nonatomic, strong) CALayer *tintLayer;
@property (nonatomic, strong) CAGradientLayer *sheen;
@property (nonatomic, strong) UIView *blob;
@property (nonatomic, strong) CAGradientLayer *blobGradient;
@property (nonatomic, strong) UIView *edgeView;
@property (nonatomic, strong) CAGradientLayer *edgeGradient;
@property (nonatomic, strong) CAShapeLayer *edgeMask;
@property (nonatomic) BOOL tiltApplied;
- (void)applyRadius:(CGFloat)r tilt:(BOOL)tilt;
@end

@implementation LGGlassOverlay

- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.layer.masksToBounds = YES;

        _tintLayer = [CALayer layer];
        [self.layer addSublayer:_tintLayer];

        _sheen = [CAGradientLayer layer];
        _sheen.startPoint = CGPointMake(0, 0);
        _sheen.endPoint = CGPointMake(0.75, 0.9);
        [self.layer addSublayer:_sheen];

        _blob = [[UIView alloc] initWithFrame:CGRectZero];
        _blob.userInteractionEnabled = NO;
        _blobGradient = [CAGradientLayer layer];
        _blobGradient.type = kCAGradientLayerRadial;
        _blobGradient.startPoint = CGPointMake(0.5, 0.5);
        _blobGradient.endPoint = CGPointMake(1.0, 1.0);
        [_blob.layer addSublayer:_blobGradient];
        [self addSubview:_blob];

        _edgeView = [[UIView alloc] initWithFrame:CGRectZero];
        _edgeView.userInteractionEnabled = NO;
        _edgeGradient = [CAGradientLayer layer];
        _edgeGradient.startPoint = CGPointMake(0, 0);
        _edgeGradient.endPoint = CGPointMake(1, 1);
        _edgeMask = [CAShapeLayer layer];
        _edgeMask.fillColor = nil;
        _edgeMask.strokeColor = [UIColor blackColor].CGColor;
        _edgeGradient.mask = _edgeMask;
        [_edgeView.layer addSublayer:_edgeGradient];
        [self addSubview:_edgeView];
    }
    return self;
}

- (void)applyRadius:(CGFloat)r tilt:(BOOL)tilt {
    CGRect b = self.bounds;
    if (b.size.width < 2 || b.size.height < 2) return;
    r = MAX(0, MIN(r, MIN(b.size.width, b.size.height) / 2));

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    self.layer.cornerRadius = r;

    // tint
    UIColor *tc = [UIColor clearColor];
    if (P.tint == 1)      tc = [UIColor colorWithWhite:1 alpha:0.10];
    else if (P.tint == 2) tc = [UIColor colorWithWhite:0 alpha:0.18];
    else if (P.tint == 3) tc = [UIColor colorWithRed:0.49 green:0.23 blue:0.93 alpha:0.20];
    _tintLayer.frame = b;
    _tintLayer.backgroundColor = tc.CGColor;

    // broad soft sheen across the glass
    _sheen.frame = b;
    _sheen.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.30 * P.shine].CGColor,
                      (id)[UIColor colorWithWhite:1 alpha:0.06 * P.shine].CGColor,
                      (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor];
    _sheen.locations = @[@0.0, @0.45, @1.0];

    // moving specular highlight
    CGFloat big = MAX(b.size.width, b.size.height) * 0.9;
    CGPoint home = CGPointMake(b.size.width * 0.28, b.size.height * 0.12);
    if (!_tiltApplied) {
        _blob.bounds = CGRectMake(0, 0, big, big);
        _blob.center = home;
    } else {
        _blob.bounds = CGRectMake(0, 0, big, big);
    }
    _blobGradient.frame = _blob.bounds;
    _blobGradient.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.55 * P.shine].CGColor,
                             (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor];

    // bright glass edge (strongest top-left, faint bottom-right)
    CGFloat bw = 1.0;
    _edgeView.frame = b;
    _edgeGradient.frame = _edgeView.bounds;
    _edgeGradient.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.95 * P.edge].CGColor,
                             (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor,
                             (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor,
                             (id)[UIColor colorWithWhite:1 alpha:0.50 * P.edge].CGColor];
    _edgeGradient.locations = @[@0.0, @0.42, @0.58, @1.0];
    _edgeMask.frame = _edgeView.bounds;
    _edgeMask.lineWidth = bw;
    _edgeMask.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(_edgeView.bounds, bw / 2, bw / 2)
                                                cornerRadius:MAX(0, r - bw / 2)].CGPath;

    [CATransaction commit];

    // tilt-reactive highlight
    if (tilt && !_tiltApplied) {
        CGFloat range = MAX(b.size.width, b.size.height) * 0.18;
        UIInterpolatingMotionEffect *mx =
            [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x"
                                                            type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
        mx.minimumRelativeValue = @(-range);
        mx.maximumRelativeValue = @(range);
        UIInterpolatingMotionEffect *my =
            [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y"
                                                            type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
        my.minimumRelativeValue = @(-range * 0.6);
        my.maximumRelativeValue = @(range * 0.6);
        UIMotionEffectGroup *g = [UIMotionEffectGroup new];
        g.motionEffects = @[mx, my];
        [_blob addMotionEffect:g];
        _tiltApplied = YES;
    } else if (!tilt && _tiltApplied) {
        for (UIMotionEffect *e in [_blob.motionEffects copy]) [_blob removeMotionEffect:e];
        _tiltApplied = NO;
        _blob.center = home;
    }
}

@end

#pragma mark - Decorating views

static NSHashTable *sHosts = nil;
static BOOL sBusy = NO;

static LGGlassOverlay *LGFindOverlay(UIView *host) {
    for (UIView *v in host.subviews) if ([v isKindOfClass:[LGGlassOverlay class]]) return (LGGlassOverlay *)v;
    return nil;
}

// Add / update / remove the overlay on `host`.
static void LGDecorate(UIView *host, BOOL on, CGRect frame, CGFloat radius, BOOL tilt, UIView *above) {
    if (sBusy) return;
    sBusy = YES;
    @try {
        LGGlassOverlay *ov = LGFindOverlay(host);
        if (!on || radius < 1) {
            if (ov) [ov removeFromSuperview];
        } else {
            if (!ov) {
                ov = [[LGGlassOverlay alloc] initWithFrame:frame];
                if (above && above.superview == host) [host insertSubview:ov aboveSubview:above];
                else [host addSubview:ov];
            }
            if (!CGRectEqualToRect(ov.frame, frame)) ov.frame = frame;
            [ov applyRadius:radius tilt:tilt];
            if (!sHosts) sHosts = [NSHashTable weakObjectsHashTable];
            [sHosts addObject:host];
        }
    } @catch (NSException *e) {
        NSLog(@"[LiquidGlass] %@", e);
    }
    sBusy = NO;
}

static id LGIvar(id obj, NSString *name) {
    @try { return [obj valueForKey:name]; } @catch (NSException *e) { return nil; }
}

// ---- Dock ----
static void (*orig_dock)(id, SEL);
static void new_dock(id self, SEL _cmd) {
    orig_dock(self, _cmd);
    UIView *dock = self;
    UIView *bg  = LGIvar(dock, @"_backgroundView");
    UIView *img = LGIvar(dock, @"_backgroundImageView");
    BOOL on = P.enabled && P.dock;
    CGRect b = dock.bounds;
    CGRect r = CGRectMake(12, 8, b.size.width - 24, MAX(10, b.size.height - 16));
    CGFloat rad = MIN(P.dockRadius, r.size.height / 2);

    if (bg && [bg isKindOfClass:[UIView class]]) {
        if (on) {
            bg.frame = r;
            bg.layer.cornerRadius = rad;
            bg.layer.masksToBounds = YES;
        } else if (bg.layer.masksToBounds && bg.layer.cornerRadius > 0) {
            bg.layer.cornerRadius = 0;
            bg.layer.masksToBounds = NO;
        }
    }
    if (img && [img isKindOfClass:[UIView class]] && on) img.hidden = YES;
    LGDecorate(dock, on, r, rad, P.tilt, bg);
}

// ---- Open folder background ----
static void (*orig_folder)(id, SEL);
static void new_folder(id self, SEL _cmd) {
    orig_folder(self, _cmd);
    UIView *v = self;
    CGFloat rad = 35;
    id n = LGIvar(v, @"_continuousCornerRadius");
    if ([n respondsToSelector:@selector(doubleValue)] && [n doubleValue] > 1) rad = [n doubleValue];
    LGDecorate(v, P.enabled && P.folders, v.bounds, rad, P.tilt, nil);
}

// ---- Notification / Control Center / widget panels ----
static void (*orig_material)(id, SEL);
static void new_material(id self, SEL _cmd) {
    orig_material(self, _cmd);
    UIView *v = self;
    CGSize s = v.bounds.size, scr = [UIScreen mainScreen].bounds.size;
    CGFloat rad = v.layer.cornerRadius;
    if (rad < 1 && [v respondsToSelector:NSSelectorFromString(@"cornerRadius")]) {
        rad = ((CGFloat (*)(id, SEL))objc_msgSend)(v, NSSelectorFromString(@"cornerRadius"));
    }
    BOOL fullBleed = (s.width >= scr.width - 1 && s.height >= scr.height - 1);
    BOOL tiny = (s.width < 40 || s.height < 24);
    BOOL on = P.enabled && P.panels && !fullBleed && !tiny && rad >= 6 && v.window != nil;
    LGDecorate(v, on, v.bounds, rad, P.tilt, nil);
}

// ---- App icons (optional) ----
static void (*orig_icon)(id, SEL);
static void new_icon(id self, SEL _cmd) {
    orig_icon(self, _cmd);
    UIView *v = self;
    CGSize s = v.bounds.size;
    BOOL on = P.enabled && P.icons && s.width >= 30 && s.width <= 130 && fabs(s.width - s.height) < 2;
    LGDecorate(v, on, v.bounds, s.width * 0.2237, NO, nil);
}

#pragma mark - Setup

// Override `sel` on `cls` without touching a superclass's implementation.
static BOOL LGHook(const char *clsName, SEL sel, IMP newImp, IMP *orig) {
    Class cls = objc_getClass(clsName);
    if (!cls) { NSLog(@"[LiquidGlass] class %s not found", clsName); return NO; }
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) { NSLog(@"[LiquidGlass] %s missing method", clsName); return NO; }
    IMP o = method_getImplementation(m);
    if (!class_addMethod(cls, sel, newImp, method_getTypeEncoding(m))) {
        o = method_setImplementation(m, newImp);
    }
    *orig = o;
    return YES;
}

static void LGWalk(UIView *v) {
    [v setNeedsLayout];
    for (UIView *s in v.subviews) LGWalk(s);
}

static void LGRefreshAll(void) {
    LGLoadPrefs();
    for (UIWindow *win in [UIApplication sharedApplication].windows) LGWalk(win);
}

__attribute__((constructor))
static void LGInit(void) {
    @autoreleasepool {
        NSString *me = [[NSBundle mainBundle] bundleIdentifier];
        if (![me isEqualToString:@"com.apple.springboard"]) return;

        LGLoadPrefs();
        SEL lay = @selector(layoutSubviews);
        LGHook("SBDockView", lay, (IMP)new_dock, (IMP *)&orig_dock);
        LGHook("SBFolderBackgroundView", lay, (IMP)new_folder, (IMP *)&orig_folder);
        LGHook("MTMaterialView", lay, (IMP)new_material, (IMP *)&orig_material);
        LGHook("SBIconImageView", lay, (IMP)new_icon, (IMP *)&orig_icon);

        dispatch_async(dispatch_get_main_queue(), ^{
            int tok;
            notify_register_dispatch(kNotif, &tok, dispatch_get_main_queue(), ^(int t) {
                LGRefreshAll();
            });
        });
    }
}
