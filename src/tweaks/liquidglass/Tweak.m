// Sheer for iOS 12 - by purplepeanut4
//
// An iOS 12 take on Apple's Liquid Glass (iOS 26). Real Liquid Glass bends and refracts what is behind it;
// iOS 12 cannot do that, so Sheer recreates the look instead:
//   * the system blur is cleared or thinned so panels read as glass, not frosting
//   * a bright rim with a highlight that slides along the edge as you tilt the phone (specular light)
//   * a thick inner edge with faint cyan and magenta fringes (the light bending at the edge)
//   * a soft floating shadow, and a capsule-shaped dock that floats above the wallpaper
// Two styles: Clear (see-through utility glass) and Standard (thicker glass that keeps some blur).
//
// Applied to the Dock, open folders, notification and Control Center panels, and (optionally) app icons.
// With "Clear Every Blur" on, every blurred surface in SpringBoard is cleared (Control Center's background,
// the lock screen, the app switcher...).

#import "PKCommon.h"
#import <QuartzCore/QuartzCore.h>

static NSString *const kDomain = @"com.purplesquarecube.liquidglass";
static const char *kNotif = "com.purplesquarecube.liquidglass/prefsChanged";

#pragma mark - Preferences

typedef struct {
    BOOL enabled, dock, folders, panels, icons, tilt, all;
    CGFloat edge, shine, dockRadius, blur, refract, depth;
    int tint;    // 0 none, 1 light, 2 dark, 3 purple
    int style;   // 0 clear, 1 standard
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
    P.all        = PKBool(kDomain, @"all", YES);
    P.edge       = MAX(0, MIN(1, PKDouble(kDomain, @"edge", 0.85)));
    P.shine      = MAX(0, MIN(1, PKDouble(kDomain, @"shine", 0.45)));
    P.refract    = MAX(0, MIN(1, PKDouble(kDomain, @"refract", 0.6)));
    P.depth      = MAX(0, MIN(1, PKDouble(kDomain, @"depth", 0.5)));
    P.dockRadius = MAX(8, MIN(60, PKDouble(kDomain, @"dockRadius", 60)));
    P.blur       = MAX(0, MIN(1, PKDouble(kDomain, @"blur", 0.12)));
    P.tint       = (int)PKInt(kDomain, @"tint", 0);
    P.style      = (int)PKInt(kDomain, @"style", 0);
}

static BOOL LGClear(void) { return P.style == 0; }
static BOOL LGClearAll(void) { return P.enabled && P.all && P.style == 0; }

#pragma mark - The glass overlay

@interface LGGlassOverlay : UIView
@property (nonatomic, strong) CALayer *tintLayer;
@property (nonatomic, strong) CALayer *lift;
@property (nonatomic, strong) CAGradientLayer *sheen;
@property (nonatomic, strong) UIView *blob;
@property (nonatomic, strong) CAGradientLayer *blobGradient;
// soft inner glow, inner hairline, two colour fringes
@property (nonatomic, strong) UIView *glowView;     @property (nonatomic, strong) CAGradientLayer *glowGradient;   @property (nonatomic, strong) CAShapeLayer *glowMask;
@property (nonatomic, strong) UIView *hairView;     @property (nonatomic, strong) CAGradientLayer *hairGradient;   @property (nonatomic, strong) CAShapeLayer *hairMask;
@property (nonatomic, strong) UIView *cyanView;     @property (nonatomic, strong) CAGradientLayer *cyanGradient;   @property (nonatomic, strong) CAShapeLayer *cyanMask;
@property (nonatomic, strong) UIView *magView;      @property (nonatomic, strong) CAGradientLayer *magGradient;    @property (nonatomic, strong) CAShapeLayer *magMask;
// the bright rim; its highlight slides as the phone tilts
@property (nonatomic, strong) UIView *edgeClip;
@property (nonatomic, strong) UIView *edgeSlide;
@property (nonatomic, strong) CAGradientLayer *edgeGradient;
@property (nonatomic, strong) CAShapeLayer *edgeMask;
@property (nonatomic) BOOL tiltApplied;
- (void)applyRadius:(CGFloat)r tilt:(BOOL)tilt;
@end

static UIView *LGRingView(UIView *parent, CAGradientLayer **gOut, CAShapeLayer **mOut) {
    UIView *v = [[UIView alloc] initWithFrame:CGRectZero];
    v.userInteractionEnabled = NO;
    CAGradientLayer *g = [CAGradientLayer layer];
    g.startPoint = CGPointMake(0, 0);
    g.endPoint = CGPointMake(1, 1);
    CAShapeLayer *m = [CAShapeLayer layer];
    m.fillColor = nil;
    m.strokeColor = [UIColor blackColor].CGColor;
    g.mask = m;
    [v.layer addSublayer:g];
    [parent addSubview:v];
    *gOut = g;
    *mOut = m;
    return v;
}

// a ring `width` thick, `inset` points in from the edge, brightest top-left (a1) and bottom-right (a2)
static void LGSetRing(UIView *view, CAGradientLayer *grad, CAShapeLayer *mask, CGRect b, CGFloat r,
                      CGFloat width, CGFloat inset, UIColor *c1, CGFloat a1, UIColor *c2, CGFloat a2) {
    view.frame = b;
    grad.frame = view.bounds;
    CGFloat w1, w2, w3, w4;
    [c1 getRed:&w1 green:&w2 blue:&w3 alpha:NULL];
    CGFloat x1, x2, x3, x4;
    [c2 getRed:&x1 green:&x2 blue:&x3 alpha:NULL];
    (void)w4; (void)x4;
    grad.colors = @[(id)[UIColor colorWithRed:w1 green:w2 blue:w3 alpha:a1].CGColor,
                    (id)[UIColor colorWithRed:w1 green:w2 blue:w3 alpha:0.0].CGColor,
                    (id)[UIColor colorWithRed:x1 green:x2 blue:x3 alpha:0.0].CGColor,
                    (id)[UIColor colorWithRed:x1 green:x2 blue:x3 alpha:a2].CGColor];
    grad.locations = @[@0.0, @0.42, @0.58, @1.0];
    mask.frame = view.bounds;
    mask.lineWidth = width;
    CGRect ring = CGRectInset(view.bounds, inset + width / 2, inset + width / 2);
    mask.path = [UIBezierPath bezierPathWithRoundedRect:ring cornerRadius:MAX(0, r - inset - width / 2)].CGPath;
}

@implementation LGGlassOverlay

- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.layer.masksToBounds = YES;

        _tintLayer = [CALayer layer];
        [self.layer addSublayer:_tintLayer];

        // a faint additive lift so the glass looks luminous rather than grey
        _lift = [CALayer layer];
        @try { _lift.compositingFilter = @"plusL"; } @catch (NSException *e) {}
        [self.layer addSublayer:_lift];

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

        CAGradientLayer *g; CAShapeLayer *m;
        _glowView = LGRingView(self, &g, &m); _glowGradient = g; _glowMask = m;
        _hairView = LGRingView(self, &g, &m); _hairGradient = g; _hairMask = m;
        _cyanView = LGRingView(self, &g, &m); _cyanGradient = g; _cyanMask = m;
        _magView  = LGRingView(self, &g, &m); _magGradient = g;  _magMask = m;

        // bright rim: a big gradient that slides behind a ring-shaped window
        _edgeClip = [[UIView alloc] initWithFrame:CGRectZero];
        _edgeClip.userInteractionEnabled = NO;
        _edgeMask = [CAShapeLayer layer];
        _edgeMask.fillColor = nil;
        _edgeMask.strokeColor = [UIColor blackColor].CGColor;
        _edgeClip.layer.mask = _edgeMask;
        _edgeSlide = [[UIView alloc] initWithFrame:CGRectZero];
        _edgeSlide.userInteractionEnabled = NO;
        _edgeGradient = [CAGradientLayer layer];
        _edgeGradient.startPoint = CGPointMake(0, 0);
        _edgeGradient.endPoint = CGPointMake(1, 1);
        [_edgeSlide.layer addSublayer:_edgeGradient];
        [_edgeClip addSubview:_edgeSlide];
        [self addSubview:_edgeClip];
    }
    return self;
}

- (void)applyRadius:(CGFloat)r tilt:(BOOL)tilt {
    CGRect b = self.bounds;
    if (b.size.width < 2 || b.size.height < 2) return;
    r = MAX(0, MIN(r, MIN(b.size.width, b.size.height) / 2));
    BOOL clear = LGClear();
    CGFloat std = clear ? 0.0 : 1.0;                       // standard glass is thicker: stronger rim and edge

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.layer.cornerRadius = r;

    // tint (none by default so clear glass stays clear)
    UIColor *tc = [UIColor clearColor];
    if (P.tint == 1)      tc = [UIColor colorWithWhite:1 alpha:clear ? 0.06 : 0.12];
    else if (P.tint == 2) tc = [UIColor colorWithWhite:0 alpha:clear ? 0.14 : 0.20];
    else if (P.tint == 3) tc = [UIColor colorWithRed:0.49 green:0.23 blue:0.93 alpha:clear ? 0.16 : 0.22];
    _tintLayer.frame = b;
    _tintLayer.backgroundColor = tc.CGColor;

    _lift.frame = b;
    _lift.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05 + 0.05 * P.refract + 0.04 * std].CGColor;

    // broad soft sheen across the glass
    CGFloat sheenK = clear ? 0.55 : 1.0;
    _sheen.frame = b;
    _sheen.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.30 * P.shine * sheenK].CGColor,
                      (id)[UIColor colorWithWhite:1 alpha:0.06 * P.shine * sheenK].CGColor,
                      (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor];
    _sheen.locations = @[@0.0, @0.45, @1.0];

    // moving specular glint
    CGFloat big = MAX(b.size.width, b.size.height) * 0.9;
    CGPoint home = CGPointMake(b.size.width * 0.28, b.size.height * 0.12);
    _blob.bounds = CGRectMake(0, 0, big, big);
    if (!_tiltApplied) _blob.center = home;
    _blobGradient.frame = _blob.bounds;
    _blobGradient.colors = @[(id)[UIColor colorWithWhite:1 alpha:(clear ? 0.38 : 0.55) * P.shine].CGColor,
                             (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor];

    UIColor *white = [UIColor whiteColor], *black = [UIColor blackColor];
    UIColor *cyan = [UIColor colorWithRed:0.35 green:0.92 blue:1.0 alpha:1];
    UIColor *magenta = [UIColor colorWithRed:1.0 green:0.45 blue:0.90 alpha:1];

    // thick inner edge: soft glow, a dark hairline for depth, and colour fringes where the light bends
    CGFloat edgeStrength = P.edge * (0.8 + 0.4 * std);
    LGSetRing(_glowView, _glowGradient, _glowMask, b, r, 9.0, 0, white, 0.30 * edgeStrength * (0.6 + 0.8 * P.refract), white, 0.16 * edgeStrength);
    LGSetRing(_hairView, _hairGradient, _hairMask, b, r, 1.0, 9.0, black, 0.20 * P.refract, black, 0.26 * P.refract);
    LGSetRing(_cyanView, _cyanGradient, _cyanMask, b, r, 1.2, 1.6, cyan, 0.55 * P.refract * P.edge, cyan, 0.20 * P.refract * P.edge);
    LGSetRing(_magView, _magGradient, _magMask, b, r, 1.2, 2.8, magenta, 0.20 * P.refract * P.edge, magenta, 0.50 * P.refract * P.edge);

    // the bright rim itself, in a window that follows the corner radius
    _edgeClip.frame = b;
    _edgeMask.frame = b;
    _edgeMask.lineWidth = 1.5;
    _edgeMask.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(b, 0.75, 0.75)
                                                cornerRadius:MAX(0, r - 0.75)].CGPath;
    CGPoint slideHome = CGPointMake(b.size.width / 2, b.size.height / 2);
    _edgeSlide.bounds = CGRectMake(0, 0, b.size.width * 2, b.size.height * 2);
    if (!_tiltApplied) _edgeSlide.center = slideHome;
    _edgeGradient.frame = _edgeSlide.bounds;
    _edgeGradient.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.0].CGColor,
                             (id)[UIColor colorWithWhite:1 alpha:0.98 * edgeStrength].CGColor,
                             (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor,
                             (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor,
                             (id)[UIColor colorWithWhite:1 alpha:0.55 * edgeStrength].CGColor,
                             (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor];
    _edgeGradient.locations = @[@0.0, @0.22, @0.40, @0.60, @0.78, @1.0];

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

        // the rim highlight travels the other way, like light catching the edge of real glass
        CGFloat rr = MIN(b.size.width, b.size.height) * 0.55 + 20;
        UIInterpolatingMotionEffect *ex =
            [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x"
                                                            type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
        ex.minimumRelativeValue = @(rr);
        ex.maximumRelativeValue = @(-rr);
        UIInterpolatingMotionEffect *ey =
            [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y"
                                                            type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
        ey.minimumRelativeValue = @(rr * 0.6);
        ey.maximumRelativeValue = @(-rr * 0.6);
        UIMotionEffectGroup *g2 = [UIMotionEffectGroup new];
        g2.motionEffects = @[ex, ey];
        [_edgeSlide addMotionEffect:g2];
        _tiltApplied = YES;
    } else if (!tilt && _tiltApplied) {
        for (UIMotionEffect *e in [_blob.motionEffects copy]) [_blob removeMotionEffect:e];
        for (UIMotionEffect *e in [_edgeSlide.motionEffects copy]) [_edgeSlide removeMotionEffect:e];
        _tiltApplied = NO;
        _blob.center = home;
        _edgeSlide.center = slideHome;
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
        NSLog(@"[Sheer] %@", e);
    }
    sBusy = NO;
}

// ---- Dock: a floating capsule, like the floating bars in Liquid Glass ----
static void (*orig_dock)(id, SEL);
static void new_dock(id self, SEL _cmd) {
    orig_dock(self, _cmd);
    UIView *dock = self;
    UIView *bg  = PKIvar(dock, @"_backgroundView");
    UIView *img = PKIvar(dock, @"_backgroundImageView");
    BOOL on = P.enabled && P.dock;
    CGRect b = dock.bounds;
    CGRect r = CGRectMake(14, 10, b.size.width - 28, MAX(10, b.size.height - 22));
    CGFloat rad = MIN(P.dockRadius, r.size.height / 2);

    if (bg && [bg isKindOfClass:[UIView class]]) {
        if (on) {
            bg.frame = r;
            bg.layer.cornerRadius = rad;
            bg.layer.masksToBounds = YES;
            LGFade(bg, LGClear(), P.blur);
        } else {
            LGFade(bg, NO, 1);
            if (bg.layer.masksToBounds && bg.layer.cornerRadius > 0) {
                bg.layer.cornerRadius = 0;
                bg.layer.masksToBounds = NO;
            }
        }
    }
    if (img && [img isKindOfClass:[UIView class]]) LGHide(img, on);

    // soft shadow so the capsule sits above the wallpaper
    if (on && P.depth > 0.01) {
        dock.layer.shadowColor = [UIColor blackColor].CGColor;
        dock.layer.shadowOpacity = 0.32 * P.depth;
        dock.layer.shadowRadius = 16;
        dock.layer.shadowOffset = CGSizeMake(0, 8);
        dock.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:rad].CGPath;
    } else if (dock.layer.shadowOpacity > 0) {
        dock.layer.shadowOpacity = 0;
    }
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

// ---- Notification / Control Center / widget panels (and every other material) ----
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
    BOOL clear = (on && LGClear()) || LGClearAll();
    for (NSString *name in @[@"_backdropView", @"_baseOverlayView", @"_primaryOverlayView",
                              @"_secondaryOverlayView", @"_reducedTransparencyBackdropReplacementView"]) {
        LGFade(PKIvar(v, name), clear, P.blur);
    }
    LGDecorate(v, on, v.bounds, rad, P.tilt, nil);
}

// ---- Any blur effect view (switcher, search, lock screen...) ----
static void (*orig_effect)(id, SEL);
static void new_effect(id self, SEL _cmd) {
    orig_effect(self, _cmd);
    UIVisualEffectView *v = self;
    BOOL isBlur = [v.effect isKindOfClass:[UIBlurEffect class]];     // leave vibrancy effects alone
    LGFade(v, isBlur && LGClearAll(), P.blur);
}

// ---- Wallpaper blur (dock, lock screen, home screen backdrops) ----
static void (*orig_wall)(id, SEL);
static void new_wall(id self, SEL _cmd) {
    orig_wall(self, _cmd);
    BOOL clear = LGClearAll();
    for (NSString *name in @[@"_blurView", @"_grayscaleTintView", @"_colorTintView", @"_transitionBlurView",
                              @"_transitionGrayscaleTintView", @"_transitionColorTintView"]) {
        LGFade(PKIvar(self, name), clear, P.blur);
    }
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
        PKHook("UIVisualEffectView", lay, (IMP)new_effect, (IMP *)&orig_effect);
        PKHook("SBWallpaperEffectView", lay, (IMP)new_wall, (IMP *)&orig_wall);
        dispatch_async(dispatch_get_main_queue(), ^{
            PKOnNotify(kNotif, ^{ LGRefreshAll(); });
        });
    }
}
