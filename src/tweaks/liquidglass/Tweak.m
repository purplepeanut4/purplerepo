// Liquid Glass for iOS 12 - by purplesquarecube
//
// Two styles:
//   Clear   - the system blur is faded out so panels are see-through; only a glass
//             edge, a faint inner glow and a tilt-reactive highlight remain.
//   Frosted - keeps the system blur and adds the same edge, sheen and highlight.
//
// Applied to the Dock, open folders, notification and Control Center panels, and
// (optionally) app icons.

#import "PKCommon.h"
#import <QuartzCore/QuartzCore.h>

static NSString *const kDomain = @"com.purplesquarecube.liquidglass";
static const char *kNotif = "com.purplesquarecube.liquidglass/prefsChanged";

#pragma mark - Preferences

typedef struct {
    BOOL enabled, dock, folders, panels, icons, tilt;
    CGFloat edge, shine, dockRadius, blur;
    int tint;    // 0 none, 1 light, 2 dark, 3 purple
    int style;   // 0 clear, 1 frosted
} LGPrefs;

static LGPrefs P;

static void LGLoadPrefs(void) {
    PKSync(kDomain);
    P.enabled    = PKBool(kDomain, @"enabled", YES);
    P.dock       = PKBool(kDomain, @"dock", YES);
    P.folders    = PKBool(kDomain, @"folders", YES);
    P.panels     = PKBool(kDomain, @"panels", YES);
    P.icons      = PKBool(kDomain, @"icons", NO);
    P.tilt       = PKBool(kDomain, @"tilt", YES);
    P.edge       = MAX(0, MIN(1, PKDouble(kDomain, @"edge", 0.8)));
    P.shine      = MAX(0, MIN(1, PKDouble(kDomain, @"shine", 0.45)));
    P.dockRadius = MAX(8, MIN(44, PKDouble(kDomain, @"dockRadius", 28)));
    P.blur       = MAX(0, MIN(1, PKDouble(kDomain, @"blur", 0.12)));
    P.tint       = (int)PKInt(kDomain, @"tint", 0);
    P.style      = (int)PKInt(kDomain, @"style", 0);
}

static BOOL LGClear(void) { return P.style == 0; }

#pragma mark - The glass overlay

@interface LGGlassOverlay : UIView
@property (nonatomic, strong) CALayer *tintLayer;
@property (nonatomic, strong) CAGradientLayer *sheen;
@property (nonatomic, strong) UIView *blob;
@property (nonatomic, strong) CAGradientLayer *blobGradient;
@property (nonatomic, strong) UIView *glowView;
@property (nonatomic, strong) CAGradientLayer *glowGradient;
@property (nonatomic, strong) CAShapeLayer *glowMask;
@property (nonatomic, strong) UIView *edgeView;
@property (nonatomic, strong) CAGradientLayer *edgeGradient;
@property (nonatomic, strong) CAShapeLayer *edgeMask;
@property (nonatomic) BOOL tiltApplied;
- (void)applyRadius:(CGFloat)r tilt:(BOOL)tilt;
@end

static void LGMakeRing(UIView *container, CAGradientLayer **gradOut, CAShapeLayer **maskOut) {
    CAGradientLayer *g = [CAGradientLayer layer];
    g.startPoint = CGPointMake(0, 0);
    g.endPoint = CGPointMake(1, 1);
    CAShapeLayer *m = [CAShapeLayer layer];
    m.fillColor = nil;
    m.strokeColor = [UIColor blackColor].CGColor;
    g.mask = m;
    [container.layer addSublayer:g];
    *gradOut = g;
    *maskOut = m;
}

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

        _glowView = [[UIView alloc] initWithFrame:CGRectZero];
        _glowView.userInteractionEnabled = NO;
        CAGradientLayer *gg = nil; CAShapeLayer *gm = nil;
        LGMakeRing(_glowView, &gg, &gm);
        _glowGradient = gg; _glowMask = gm;
        [self addSubview:_glowView];

        _edgeView = [[UIView alloc] initWithFrame:CGRectZero];
        _edgeView.userInteractionEnabled = NO;
        CAGradientLayer *eg = nil; CAShapeLayer *em = nil;
        LGMakeRing(_edgeView, &eg, &em);
        _edgeGradient = eg; _edgeMask = em;
        [self addSubview:_edgeView];
    }
    return self;
}

static void LGSetRing(UIView *view, CAGradientLayer *grad, CAShapeLayer *mask, CGRect b, CGFloat r,
                      CGFloat width, CGFloat a1, CGFloat a2) {
    view.frame = b;
    grad.frame = view.bounds;
    grad.colors = @[(id)[UIColor colorWithWhite:1 alpha:a1].CGColor,
                    (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor,
                    (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor,
                    (id)[UIColor colorWithWhite:1 alpha:a2].CGColor];
    grad.locations = @[@0.0, @0.42, @0.58, @1.0];
    mask.frame = view.bounds;
    mask.lineWidth = width;
    mask.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(view.bounds, width / 2, width / 2)
                                           cornerRadius:MAX(0, r - width / 2)].CGPath;
}

- (void)applyRadius:(CGFloat)r tilt:(BOOL)tilt {
    CGRect b = self.bounds;
    if (b.size.width < 2 || b.size.height < 2) return;
    r = MAX(0, MIN(r, MIN(b.size.width, b.size.height) / 2));
    BOOL clear = LGClear();

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.layer.cornerRadius = r;

    // tint (none by default so clear glass stays clear)
    UIColor *tc = [UIColor clearColor];
    if (P.tint == 1)      tc = [UIColor colorWithWhite:1 alpha:clear ? 0.06 : 0.10];
    else if (P.tint == 2) tc = [UIColor colorWithWhite:0 alpha:clear ? 0.14 : 0.18];
    else if (P.tint == 3) tc = [UIColor colorWithRed:0.49 green:0.23 blue:0.93 alpha:clear ? 0.16 : 0.20];
    _tintLayer.frame = b;
    _tintLayer.backgroundColor = tc.CGColor;

    // broad soft sheen (lighter on clear glass)
    CGFloat sheenK = clear ? 0.55 : 1.0;
    _sheen.frame = b;
    _sheen.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.30 * P.shine * sheenK].CGColor,
                      (id)[UIColor colorWithWhite:1 alpha:0.06 * P.shine * sheenK].CGColor,
                      (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor];
    _sheen.locations = @[@0.0, @0.45, @1.0];

    // moving specular highlight
    CGFloat big = MAX(b.size.width, b.size.height) * 0.9;
    CGPoint home = CGPointMake(b.size.width * 0.28, b.size.height * 0.12);
    _blob.bounds = CGRectMake(0, 0, big, big);
    if (!_tiltApplied) _blob.center = home;
    _blobGradient.frame = _blob.bounds;
    _blobGradient.colors = @[(id)[UIColor colorWithWhite:1 alpha:(clear ? 0.38 : 0.55) * P.shine].CGColor,
                             (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor];

    // soft inner glow (clear style only) and the bright edge
    _glowView.hidden = !clear;
    if (clear) LGSetRing(_glowView, _glowGradient, _glowMask, b, r, 7.0, 0.30 * P.edge, 0.16 * P.edge);
    LGSetRing(_edgeView, _edgeGradient, _edgeMask, b, r, 1.0, 0.95 * P.edge, 0.50 * P.edge);

    [CATransaction commit];

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

#pragma mark - Fading the system blur (clear style)

static const void *kOrigAlphaKey = &kOrigAlphaKey;
static const void *kOrigHiddenKey = &kOrigHiddenKey;

// Scale a view's alpha down (remembering the original), or put it back.
static void LGFade(UIView *v, BOOL clear, CGFloat amount) {
    if (![v isKindOfClass:[UIView class]]) return;
    NSNumber *orig = objc_getAssociatedObject(v, kOrigAlphaKey);
    if (clear) {
        if (!orig) { orig = @(v.alpha); objc_setAssociatedObject(v, kOrigAlphaKey, orig, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        CGFloat target = [orig doubleValue] * amount;
        if (fabs(v.alpha - target) > 0.001) v.alpha = target;
    } else if (orig) {
        v.alpha = [orig doubleValue];
        objc_setAssociatedObject(v, kOrigAlphaKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void LGHide(UIView *v, BOOL hide) {
    if (![v isKindOfClass:[UIView class]]) return;
    if (hide) {
        if (!v.hidden) { v.hidden = YES; objc_setAssociatedObject(v, kOrigHiddenKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    } else if ([objc_getAssociatedObject(v, kOrigHiddenKey) boolValue]) {
        v.hidden = NO;
        objc_setAssociatedObject(v, kOrigHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

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

// ---- Dock ----
static void (*orig_dock)(id, SEL);
static void new_dock(id self, SEL _cmd) {
    orig_dock(self, _cmd);
    UIView *dock = self;
    UIView *bg  = PKIvar(dock, @"_backgroundView");
    UIView *img = PKIvar(dock, @"_backgroundImageView");
    BOOL on = P.enabled && P.dock;
    CGRect b = dock.bounds;
    CGRect r = CGRectMake(12, 8, b.size.width - 24, MAX(10, b.size.height - 16));
    CGFloat rad = MIN(P.dockRadius, r.size.height / 2);

    if (bg && [bg isKindOfClass:[UIView class]]) {
        if (on) {
            bg.frame = r;
            bg.layer.cornerRadius = rad;
            bg.layer.masksToBounds = YES;
            LGFade(bg, LGClear(), P.blur);          // clear: fade the system blur right down
        } else {
            LGFade(bg, NO, 1);
            if (bg.layer.masksToBounds && bg.layer.cornerRadius > 0) {
                bg.layer.cornerRadius = 0;
                bg.layer.masksToBounds = NO;
            }
        }
    }
    if (img && [img isKindOfClass:[UIView class]]) LGHide(img, on);
    LGDecorate(dock, on, r, rad, P.tilt, bg);
}

// ---- Open folder background ----
static void (*orig_folder)(id, SEL);
static void new_folder(id self, SEL _cmd) {
    orig_folder(self, _cmd);
    UIView *v = self;
    BOOL on = P.enabled && P.folders;
    CGFloat rad = 35;
    id n = PKIvar(v, @"_continuousCornerRadius");
    if ([n respondsToSelector:@selector(doubleValue)] && [n doubleValue] > 1) rad = [n doubleValue];
    BOOL clear = on && LGClear();
    LGFade(PKIvar(v, @"_blurView"), clear, P.blur);
    LGFade(PKIvar(v, @"_tintView"), clear, P.blur);
    LGDecorate(v, on, v.bounds, rad, P.tilt, nil);
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
    BOOL clear = on && LGClear();

    // MTMaterialView builds its look from a backdrop view plus overlay views
    for (NSString *name in @[@"_backdropView", @"_baseOverlayView", @"_primaryOverlayView",
                              @"_secondaryOverlayView", @"_reducedTransparencyBackdropReplacementView"]) {
        LGFade(PKIvar(v, name), clear, P.blur);
    }
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

static void LGRefreshAll(void) {
    LGLoadPrefs();
    PKWalkAllWindows(^(UIView *v) { [v setNeedsLayout]; });
}

__attribute__((constructor))
static void LGInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        LGLoadPrefs();
        SEL lay = @selector(layoutSubviews);
        PKHook("SBDockView", lay, (IMP)new_dock, (IMP *)&orig_dock);
        PKHook("SBFolderBackgroundView", lay, (IMP)new_folder, (IMP *)&orig_folder);
        PKHook("MTMaterialView", lay, (IMP)new_material, (IMP *)&orig_material);
        PKHook("SBIconImageView", lay, (IMP)new_icon, (IMP *)&orig_icon);
        dispatch_async(dispatch_get_main_queue(), ^{
            PKOnNotify(kNotif, ^{ LGRefreshAll(); });
        });
    }
}
