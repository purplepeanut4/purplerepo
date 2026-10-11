// LaunchFX animation engine - by purplesquarecube
//
// Index layout:
//   0-9    Iris shapes growing from the icon (mask)
//   10-17  Soft wipes in 8 directions (gradient mask)
//   18-20  Clock / fan wipes (mask)
//   21-31  Panels and strips (curtains, blinds, bars...)
//   32-43  Whole-screen moves (fade, slide, flip, shrink...)
//   44-49  Tile effects (dissolves, ripple, explode, flip)

#import "LFXEngine.h"
#import <QuartzCore/QuartzCore.h>

#pragma mark - Names

NSArray<NSString *> *LFXAnimationNames(void) {
    static NSArray *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = @[
            // 0-9 iris
            @"Iris Circle", @"Iris Square", @"Iris Diamond", @"Iris Star", @"Iris Heart",
            @"Iris Hexagon", @"Iris Triangle", @"Iris Cross", @"Iris Octagon", @"Iris Squircle",
            // 10-17 wipes
            @"Wipe Right", @"Wipe Left", @"Wipe Down", @"Wipe Up",
            @"Wipe Diagonal Down-Right", @"Wipe Diagonal Up-Left",
            @"Wipe Diagonal Up-Right", @"Wipe Diagonal Down-Left",
            // 18-20 clock
            @"Clock Wipe", @"Clock Wipe Reverse", @"Fan Open",
            // 21-31 panels
            @"Curtains", @"Split Open", @"Barn Doors", @"Four Corners",
            @"Horizontal Blinds", @"Vertical Blinds", @"Zipper",
            @"Slide Bars Right", @"Slide Bars Left", @"Columns Down", @"Columns Up",
            // 32-43 whole screen
            @"Fade", @"Slide Up", @"Slide Down", @"Slide Left", @"Slide Right",
            @"Zoom Burst", @"Shrink to Icon", @"Spin Away",
            @"Flip Horizontal", @"Flip Vertical", @"Drop & Bounce", @"Elastic Pop",
            // 44-49 tiles
            @"Random Dissolve", @"Diagonal Dissolve", @"Spiral Dissolve",
            @"Ripple", @"Explode", @"Tile Flip"
        ];
    });
    return names;
}

UIColor *LFXColorFromHex(NSString *hex) {
    if (![hex isKindOfClass:[NSString class]] || hex.length != 6) {
        return [UIColor colorWithRed:0x7C/255.0 green:0x3A/255.0 blue:0xED/255.0 alpha:1];
    }
    unsigned int v = 0;
    [[NSScanner scannerWithString:hex] scanHexInt:&v];
    return [UIColor colorWithRed:((v >> 16) & 0xFF) / 255.0
                           green:((v >> 8) & 0xFF) / 255.0
                            blue:(v & 0xFF) / 255.0
                           alpha:1];
}

#pragma mark - State

static UIWindow *sWindow = nil;
static CADisplayLink *sLink = nil;
static NSInteger sGen = 0;

@interface LFXLinkTarget : NSObject {
@public
    void (^tick)(CADisplayLink *);
}
- (void)fire:(CADisplayLink *)link;
@end
@implementation LFXLinkTarget
- (void)fire:(CADisplayLink *)link { if (tick) tick(link); }
@end

void LFXCancel(void) {
    sGen++;
    if (sLink) { [sLink invalidate]; sLink = nil; }
    if (sWindow) { sWindow.hidden = YES; sWindow = nil; }
}

#pragma mark - Helpers

static double LFXEase(double t) {                       // ease in-out
    t = MAX(0.0, MIN(1.0, t));
    return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2;
}
static double LFXEaseIn(double t) { t = MAX(0.0, MIN(1.0, t)); return t * t; }
static double LFXClamp01(double v) { return MAX(0.0, MIN(1.0, v)); }

static CALayer *LFXPiece(CALayer *parent, CGRect f, UIColor *c) {
    CALayer *l = [CALayer layer];
    l.frame = f;
    l.backgroundColor = c.CGColor;
    [parent addSublayer:l];
    return l;
}

static void LFXFinishAnim(CAAnimation *a, CALayer *l, CFTimeInterval begin, CFTimeInterval dur, NSString *key) {
    a.duration = MAX(dur, 0.01);
    a.beginTime = [l convertTime:CACurrentMediaTime() fromLayer:nil] + begin;
    a.fillMode = kCAFillModeBoth;
    a.removedOnCompletion = NO;
    [l addAnimation:a forKey:key];
}

// single-property animation
static void LFXAnim(CALayer *l, NSString *keyPath, id from, id to,
                    CFTimeInterval begin, CFTimeInterval dur, NSString *timing) {
    CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:keyPath];
    a.fromValue = from;
    a.toValue = to;
    a.timingFunction = [CAMediaTimingFunction functionWithName:timing ?: kCAMediaTimingFunctionEaseInEaseOut];
    LFXFinishAnim(a, l, begin, dur, keyPath);
}

// move a layer by (dx, dy) using `position`
static void LFXMove(CALayer *l, CGFloat dx, CGFloat dy,
                    CFTimeInterval begin, CFTimeInterval dur, NSString *timing) {
    CGPoint p = l.position;
    LFXAnim(l, @"position", [NSValue valueWithCGPoint:p],
            [NSValue valueWithCGPoint:CGPointMake(p.x + dx, p.y + dy)], begin, dur, timing);
}

// transform animation driven by a function of progress p (0...1), sampled into keyframes
static void LFXTransformAnim(CALayer *l, CFTimeInterval begin, CFTimeInterval dur, BOOL easeInOut,
                             CATransform3D (^fn)(double p)) {
    const int steps = 30;
    NSMutableArray *vals = [NSMutableArray arrayWithCapacity:steps + 1];
    for (int i = 0; i <= steps; i++) {
        double p = (double)i / steps;
        [vals addObject:[NSValue valueWithCATransform3D:fn(easeInOut ? LFXEase(p) : p)]];
    }
    CAKeyframeAnimation *a = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    a.values = vals;
    a.calculationMode = kCAAnimationLinear;
    a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    LFXFinishAnim(a, l, begin, dur, @"transform");
}

static CATransform3D LFXPerspective(CGFloat d) {
    CATransform3D t = CATransform3DIdentity;
    t.m34 = -1.0 / d;
    return t;
}

static void LFXAnchorAt(CALayer *l, CGPoint pt, CGSize size) {
    l.anchorPoint = CGPointMake(pt.x / size.width, pt.y / size.height);
    l.position = pt;
}

#pragma mark - Shapes for the iris effects

static UIBezierPath *LFXPolygon(CGPoint c, CGFloat r, int n, CGFloat start) {
    UIBezierPath *p = [UIBezierPath bezierPath];
    for (int i = 0; i < n; i++) {
        CGFloat a = start + i * 2 * M_PI / n;
        CGPoint pt = CGPointMake(c.x + r * cos(a), c.y + r * sin(a));
        if (i == 0) [p moveToPoint:pt]; else [p addLineToPoint:pt];
    }
    [p closePath];
    return p;
}

static UIBezierPath *LFXShape(int shape, CGPoint c, CGFloat r, CGFloat rot) {
    UIBezierPath *p = nil;
    switch (shape) {
        case 0:  // circle
            p = [UIBezierPath bezierPathWithArcCenter:c radius:r startAngle:0 endAngle:2 * M_PI clockwise:YES];
            break;
        case 1:  // square
            p = [UIBezierPath bezierPathWithRect:CGRectMake(c.x - r, c.y - r, 2 * r, 2 * r)];
            break;
        case 2:  // diamond
            p = LFXPolygon(c, r, 4, -M_PI_2);
            break;
        case 3: {  // star
            p = [UIBezierPath bezierPath];
            for (int i = 0; i < 10; i++) {
                CGFloat a = -M_PI_2 + i * M_PI / 5;
                CGFloat rr = (i % 2 == 0) ? r : r * 0.4;
                CGPoint pt = CGPointMake(c.x + rr * cos(a), c.y + rr * sin(a));
                if (i == 0) [p moveToPoint:pt]; else [p addLineToPoint:pt];
            }
            [p closePath];
            break;
        }
        case 4: {  // heart
            #define HPT(px, py) CGPointMake(c.x + (px) * r, c.y + (py) * r)
            p = [UIBezierPath bezierPath];
            [p moveToPoint:HPT(0, 0.8)];
            [p addCurveToPoint:HPT(-0.55, -0.75) controlPoint1:HPT(-0.9, 0.2) controlPoint2:HPT(-1.1, -0.5)];
            [p addCurveToPoint:HPT(0, -0.45) controlPoint1:HPT(-0.25, -0.9) controlPoint2:HPT(0, -0.65)];
            [p addCurveToPoint:HPT(0.55, -0.75) controlPoint1:HPT(0, -0.65) controlPoint2:HPT(0.25, -0.9)];
            [p addCurveToPoint:HPT(0, 0.8) controlPoint1:HPT(1.1, -0.5) controlPoint2:HPT(0.9, 0.2)];
            [p closePath];
            #undef HPT
            break;
        }
        case 5:  // hexagon
            p = LFXPolygon(c, r, 6, 0);
            break;
        case 6:  // triangle
            p = LFXPolygon(c, r, 3, -M_PI_2);
            break;
        case 7: {  // cross
            CGFloat w = r * 0.6;
            CGPoint pts[12] = {
                {-w, -r}, {w, -r}, {w, -w}, {r, -w}, {r, w}, {w, w},
                {w, r}, {-w, r}, {-w, w}, {-r, w}, {-r, -w}, {-w, -w}
            };
            p = [UIBezierPath bezierPath];
            for (int i = 0; i < 12; i++) {
                CGPoint pt = CGPointMake(c.x + pts[i].x, c.y + pts[i].y);
                if (i == 0) [p moveToPoint:pt]; else [p addLineToPoint:pt];
            }
            [p closePath];
            break;
        }
        case 8:  // octagon
            p = LFXPolygon(c, r, 8, M_PI / 8);
            break;
        default: // squircle
            p = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(c.x - r, c.y - r, 2 * r, 2 * r)
                                           cornerRadius:r * 0.6];
            break;
    }
    if (rot != 0) {
        CGAffineTransform t = CGAffineTransformMakeTranslation(c.x, c.y);
        t = CGAffineTransformRotate(t, rot);
        t = CGAffineTransformTranslate(t, -c.x, -c.y);
        [p applyTransform:t];
    }
    return p;
}

// how much bigger than the farthest-corner distance each shape must grow to cover the screen
static const CGFloat kIrisFactor[10] = {1.03, 1.05, 1.5, 3.4, 2.4, 1.2, 2.15, 1.25, 1.1, 1.05};
// how far each shape spins while growing (radians)
static const CGFloat kIrisSpin[10]   = {0, M_PI_2, 0, 0.4 * M_PI, 0, M_PI / 3, 2 * M_PI / 3, M_PI_2, 0, 0};

static UIBezierPath *LFXHolePath(CGRect b, UIBezierPath *hole) {
    UIBezierPath *p = [UIBezierPath bezierPathWithRect:CGRectInset(b, -2, -2)];
    [p appendPath:hole];
    return p;
}

static UIBezierPath *LFXSector(CGPoint c, CGFloat R, CGFloat a0, CGFloat a1, BOOL clockwise) {
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:c];
    [p addLineToPoint:CGPointMake(c.x + R * cos(a0), c.y + R * sin(a0))];
    [p addArcWithCenter:c radius:R startAngle:a0 endAngle:a1 clockwise:clockwise];
    [p closePath];
    return p;
}

#pragma mark - Play

void LFXPlay(NSInteger index, UIColor *color, CGPoint origin,
             CFTimeInterval hold, CFTimeInterval dur, void (^completion)(void)) {
    LFXCancel();
    NSInteger gen = sGen;

    if (index < 0 || index >= LFX_COUNT) index = 0;
    if (!color) color = LFXColorFromHex(nil);
    if (dur < 0.1) dur = 0.1;
    if (hold < 0) hold = 0;

    CGRect b = [UIScreen mainScreen].bounds;
    CGFloat W = b.size.width, H = b.size.height;
    origin.x = MAX(0, MIN(W, origin.x));
    origin.y = MAX(0, MIN(H, origin.y));
    CGFloat mdx = MAX(origin.x, W - origin.x), mdy = MAX(origin.y, H - origin.y);
    CGFloat maxDist = hypot(mdx, mdy);

    UIWindow *win = [[UIWindow alloc] initWithFrame:b];
    win.windowLevel = 1000000;
    win.userInteractionEnabled = NO;
    win.backgroundColor = [UIColor clearColor];

    UIView *cover = [[UIView alloc] initWithFrame:b];
    cover.backgroundColor = [UIColor clearColor];
    cover.userInteractionEnabled = NO;
    [win addSubview:cover];
    win.hidden = NO;
    sWindow = win;

    CALayer *root = cover.layer;
    BOOL solid = (index <= 20) || (index >= 32 && index <= 43);
    if (solid) cover.backgroundColor = color;

    // quick fade-in so the cover doesn't pop
    cover.alpha = 0;
    [UIView animateWithDuration:0.08 animations:^{ cover.alpha = 1; }];

    NSString *easeIn  = kCAMediaTimingFunctionEaseIn;
    NSString *easeIO  = kCAMediaTimingFunctionEaseInEaseOut;

    // ---------- 0-20: mask effects driven frame by frame ----------
    if (index <= 20) {
        __block void (^update)(double) = nil;

        if (index <= 9) {
            int shape = (int)index;
            CAShapeLayer *mask = [CAShapeLayer layer];
            mask.frame = b;
            mask.fillRule = kCAFillRuleEvenOdd;
            mask.fillColor = [UIColor blackColor].CGColor;
            mask.path = LFXHolePath(b, LFXShape(shape, origin, 0.5, 0)).CGPath;
            root.mask = mask;
            CGFloat maxR = maxDist * kIrisFactor[shape];
            CGFloat spin = kIrisSpin[shape];
            update = ^(double e) {
                CGFloat r = MAX(0.5, maxR * e);
                mask.path = LFXHolePath(b, LFXShape(shape, origin, r, spin * e)).CGPath;
            };
        } else if (index <= 17) {
            CAGradientLayer *g = [CAGradientLayer layer];
            g.frame = b;
            g.colors = @[(id)[UIColor clearColor].CGColor, (id)[UIColor blackColor].CGColor];
            g.locations = @[@0.0, @0.0];
            static const CGFloat dirs[8][4] = {
                {0, 0.5, 1, 0.5}, {1, 0.5, 0, 0.5}, {0.5, 0, 0.5, 1}, {0.5, 1, 0.5, 0},
                {0, 0, 1, 1}, {1, 1, 0, 0}, {0, 1, 1, 0}, {1, 0, 0, 1}
            };
            const CGFloat *d = dirs[index - 10];
            g.startPoint = CGPointMake(d[0], d[1]);
            g.endPoint = CGPointMake(d[2], d[3]);
            root.mask = g;
            const double soft = 0.25;
            update = ^(double e) {
                double f = -soft + e * (1 + 2 * soft);
                g.locations = @[@(LFXClamp01(f - soft)), @(LFXClamp01(f))];
            };
        } else {
            CAShapeLayer *mask = [CAShapeLayer layer];
            mask.frame = b;
            mask.fillRule = kCAFillRuleEvenOdd;
            mask.fillColor = [UIColor blackColor].CGColor;
            mask.path = LFXHolePath(b, LFXSector(origin, 1, -M_PI_2, -M_PI_2 + 0.001, YES)).CGPath;
            root.mask = mask;
            CGFloat R = maxDist * 1.1;
            NSInteger kind = index;
            update = ^(double e) {
                e = MAX(e, 0.0005);
                UIBezierPath *hole;
                if (kind == 18)      hole = LFXSector(origin, R, -M_PI_2, -M_PI_2 + 2 * M_PI * e, YES);
                else if (kind == 19) hole = LFXSector(origin, R, -M_PI_2, -M_PI_2 - 2 * M_PI * e, NO);
                else                 hole = LFXSector(origin, R, -M_PI_2 - M_PI * e, -M_PI_2 + M_PI * e, YES);
                mask.path = LFXHolePath(b, hole).CGPath;
            };
        }

        CFTimeInterval start = CACurrentMediaTime() + hold;
        LFXLinkTarget *tgt = [LFXLinkTarget new];
        tgt->tick = ^(CADisplayLink *l) {
            if (gen != sGen) { [l invalidate]; return; }
            double t = (CACurrentMediaTime() - start) / dur;
            if (t < 0) return;
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            update(LFXEase(t));
            [CATransaction commit];
            if (t >= 1) [l invalidate];
        };
        sLink = [CADisplayLink displayLinkWithTarget:tgt selector:@selector(fire:)];
        [sLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }

    // ---------- 21-31: panels and strips ----------
    else if (index <= 31) {
        switch (index) {
            case 21: {  // curtains
                CALayer *L = LFXPiece(root, CGRectMake(0, 0, W / 2 + 0.5, H), color);
                CALayer *R = LFXPiece(root, CGRectMake(W / 2 - 0.5, 0, W / 2 + 0.5, H), color);
                LFXMove(L, -W / 2 - 2, 0, hold, dur, easeIO);
                LFXMove(R,  W / 2 + 2, 0, hold, dur, easeIO);
                break;
            }
            case 22: {  // split open
                CALayer *T = LFXPiece(root, CGRectMake(0, 0, W, H / 2 + 0.5), color);
                CALayer *B = LFXPiece(root, CGRectMake(0, H / 2 - 0.5, W, H / 2 + 0.5), color);
                LFXMove(T, 0, -H / 2 - 2, hold, dur, easeIO);
                LFXMove(B, 0,  H / 2 + 2, hold, dur, easeIO);
                break;
            }
            case 23: {  // barn doors
                root.sublayerTransform = LFXPerspective(900);
                CALayer *L = [CALayer layer];
                L.bounds = CGRectMake(0, 0, W / 2 + 0.5, H);
                L.anchorPoint = CGPointMake(0, 0.5);
                L.position = CGPointMake(0, H / 2);
                L.backgroundColor = color.CGColor;
                CALayer *R = [CALayer layer];
                R.bounds = CGRectMake(0, 0, W / 2 + 0.5, H);
                R.anchorPoint = CGPointMake(1, 0.5);
                R.position = CGPointMake(W, H / 2);
                R.backgroundColor = color.CGColor;
                [root addSublayer:L];
                [root addSublayer:R];
                LFXTransformAnim(L, hold, dur, YES, ^CATransform3D(double p) {
                    return CATransform3DMakeRotation(-p * M_PI_2, 0, 1, 0); });
                LFXTransformAnim(R, hold, dur, YES, ^CATransform3D(double p) {
                    return CATransform3DMakeRotation(p * M_PI_2, 0, 1, 0); });
                break;
            }
            case 24: {  // four corners
                CGFloat hw = W / 2, hh = H / 2;
                CGRect fr[4] = {
                    CGRectMake(0, 0, hw + 0.5, hh + 0.5), CGRectMake(hw - 0.5, 0, hw + 0.5, hh + 0.5),
                    CGRectMake(0, hh - 0.5, hw + 0.5, hh + 0.5), CGRectMake(hw - 0.5, hh - 0.5, hw + 0.5, hh + 0.5)
                };
                CGFloat sx[4] = {-1, 1, -1, 1}, sy[4] = {-1, -1, 1, 1};
                for (int i = 0; i < 4; i++) {
                    CALayer *q = LFXPiece(root, fr[i], color);
                    LFXMove(q, sx[i] * (hw + 2), sy[i] * (hh + 2), hold, dur, easeIO);
                }
                break;
            }
            case 25: {  // horizontal blinds
                int n = 12;
                for (int i = 0; i < n; i++) {
                    CALayer *s = LFXPiece(root, CGRectMake(0, i * H / n - 0.5, W, H / n + 1), color);
                    LFXAnim(s, @"transform.scale.y", @1.0, @0.0001, hold, dur, easeIO);
                }
                break;
            }
            case 26: {  // vertical blinds
                int n = 9;
                for (int i = 0; i < n; i++) {
                    CALayer *s = LFXPiece(root, CGRectMake(i * W / n - 0.5, 0, W / n + 1, H), color);
                    LFXAnim(s, @"transform.scale.x", @1.0, @0.0001, hold, dur, easeIO);
                }
                break;
            }
            case 27: case 28: case 29: {  // zipper / bars right / bars left (horizontal strips)
                int n = (index == 27) ? 14 : 12;
                for (int i = 0; i < n; i++) {
                    CALayer *s = LFXPiece(root, CGRectMake(0, i * H / n - 0.5, W, H / n + 1), color);
                    CGFloat dir = (index == 28) ? 1 : (index == 29 ? -1 : ((i % 2 == 0) ? -1 : 1));
                    CFTimeInterval delay = ((double)i / (n - 1)) * 0.35 * dur;
                    LFXMove(s, dir * (W + 2), 0, hold + delay, 0.65 * dur, easeIn);
                }
                break;
            }
            default: {  // 30, 31: columns down / up
                int n = 9;
                for (int i = 0; i < n; i++) {
                    CALayer *s = LFXPiece(root, CGRectMake(i * W / n - 0.5, 0, W / n + 1, H), color);
                    CGFloat dir = (index == 30) ? 1 : -1;
                    CFTimeInterval delay = ((double)i / (n - 1)) * 0.35 * dur;
                    LFXMove(s, 0, dir * (H + 2), hold + delay, 0.65 * dur, easeIn);
                }
                break;
            }
        }
    }

    // ---------- 32-43: whole-screen moves ----------
    else if (index <= 43) {
        switch (index) {
            case 32:
                LFXAnim(root, @"opacity", @1.0, @0.0, hold, dur, easeIO);
                break;
            case 33: LFXMove(root, 0, -H - 2, hold, dur, easeIO); break;
            case 34: LFXMove(root, 0,  H + 2, hold, dur, easeIO); break;
            case 35: LFXMove(root, -W - 2, 0, hold, dur, easeIO); break;
            case 36: LFXMove(root,  W + 2, 0, hold, dur, easeIO); break;
            case 37:  // zoom burst
                LFXTransformAnim(root, hold, dur, NO, ^CATransform3D(double p) {
                    double s = 1 + 2.5 * LFXEaseIn(p);
                    return CATransform3DMakeScale(s, s, 1); });
                LFXAnim(root, @"opacity", @1.0, @0.0, hold, dur, easeIn);
                break;
            case 38:  // shrink to icon
                LFXAnchorAt(root, origin, b.size);
                LFXTransformAnim(root, hold, dur, YES, ^CATransform3D(double p) {
                    double s = MAX(0.001, 1 - p);
                    return CATransform3DMakeScale(s, s, 1); });
                LFXAnim(root, @"cornerRadius", @0.0, @(MIN(W, H) * 0.25), hold, dur, easeIO);
                break;
            case 39:  // spin away
                LFXAnchorAt(root, origin, b.size);
                LFXTransformAnim(root, hold, dur, YES, ^CATransform3D(double p) {
                    double s = MAX(0.001, 1 - p);
                    CATransform3D t = CATransform3DMakeRotation(p * M_PI, 0, 0, 1);
                    return CATransform3DScale(t, s, s, 1); });
                LFXAnim(root, @"cornerRadius", @0.0, @(MIN(W, H) * 0.25), hold, dur, easeIO);
                break;
            case 40:  // flip horizontal
                LFXTransformAnim(root, hold, dur, YES, ^CATransform3D(double p) {
                    return CATransform3DRotate(LFXPerspective(900), p * M_PI_2, 0, 1, 0); });
                break;
            case 41:  // flip vertical
                LFXTransformAnim(root, hold, dur, YES, ^CATransform3D(double p) {
                    return CATransform3DRotate(LFXPerspective(900), p * M_PI_2, 1, 0, 0); });
                break;
            case 42: {  // drop & bounce
                CGPoint p0 = root.position;
                CGFloat up = H * 0.05;
                CFTimeInterval d1 = 0.2 * dur, d2 = 0.8 * dur;
                LFXAnim(root, @"position", [NSValue valueWithCGPoint:p0],
                        [NSValue valueWithCGPoint:CGPointMake(p0.x, p0.y - up)], hold, d1,
                        kCAMediaTimingFunctionEaseOut);
                LFXAnim(root, @"position", [NSValue valueWithCGPoint:CGPointMake(p0.x, p0.y - up)],
                        [NSValue valueWithCGPoint:CGPointMake(p0.x, p0.y + H + 2)], hold + d1, d2,
                        kCAMediaTimingFunctionEaseIn);
                break;
            }
            default:  // 43 elastic pop
                LFXAnchorAt(root, origin, b.size);
                LFXTransformAnim(root, hold, dur, NO, ^CATransform3D(double p) {
                    double s;
                    if (p < 0.25) s = 1 + 0.12 * (p / 0.25);
                    else          s = MAX(0.001, 1.12 * (1 - LFXEaseIn((p - 0.25) / 0.75)));
                    return CATransform3DMakeScale(s, s, 1); });
                LFXAnim(root, @"cornerRadius", @0.0, @(MIN(W, H) * 0.25), hold + 0.25 * dur, 0.75 * dur, easeIn);
                break;
        }
    }

    // ---------- 44-49: tiles ----------
    else {
        const int cols = 8, rows = 14;
        const int N = cols * rows;
        CGFloat tw = W / cols, th = H / rows;

        // spiral order (outside in)
        int *spiral = calloc(N, sizeof(int));
        {
            int top = 0, bottom = rows - 1, left = 0, right = cols - 1, k = 0;
            while (top <= bottom && left <= right) {
                for (int c = left; c <= right; c++) spiral[top * cols + c] = k++;
                top++;
                for (int r = top; r <= bottom; r++) spiral[r * cols + right] = k++;
                right--;
                if (top <= bottom) { for (int c = right; c >= left; c--) spiral[bottom * cols + c] = k++; bottom--; }
                if (left <= right) { for (int r = bottom; r >= top; r--) spiral[r * cols + left] = k++; left++; }
            }
        }

        if (index == 49) root.sublayerTransform = LFXPerspective(700);

        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                CGRect fr = CGRectMake(c * tw - 0.5, r * th - 0.5, tw + 1, th + 1);
                CALayer *t = LFXPiece(root, fr, color);
                CGPoint ctr = CGPointMake(c * tw + tw / 2, r * th + th / 2);
                double dist = LFXClamp01(hypot(ctr.x - origin.x, ctr.y - origin.y) / maxDist);

                switch (index) {
                    case 44: case 45: case 46: {  // dissolves
                        double d;
                        if (index == 44)      d = arc4random_uniform(1000) / 1000.0;
                        else if (index == 45) d = ((double)c / (cols - 1) + (double)r / (rows - 1)) / 2;
                        else                  d = (double)spiral[r * cols + c] / (N - 1);
                        LFXAnim(t, @"opacity", @1.0, @0.0, hold + d * 0.6 * dur, 0.4 * dur, easeIO);
                        break;
                    }
                    case 47: {  // ripple
                        CFTimeInterval delay = dist * 0.6 * dur;
                        LFXTransformAnim(t, hold + delay, 0.4 * dur, YES, ^CATransform3D(double p) {
                            double s = MAX(0.001, 1 - p);
                            return CATransform3DMakeScale(s, s, 1); });
                        break;
                    }
                    case 48: {  // explode
                        CGFloat vx = ctr.x - origin.x, vy = ctr.y - origin.y;
                        CGFloat len = MAX(1, hypot(vx, vy));
                        CGFloat push = maxDist * (0.5 + (arc4random_uniform(100) / 100.0) * 0.4);
                        CGFloat dx = vx / len * push, dy = vy / len * push;
                        CGFloat spin = ((arc4random_uniform(200) / 100.0) - 1.0) * 1.5 * M_PI;
                        CFTimeInterval delay = dist * 0.5 * dur;
                        LFXTransformAnim(t, hold + delay, 0.5 * dur, NO, ^CATransform3D(double p) {
                            double e = LFXEaseIn(p);
                            CATransform3D m = CATransform3DMakeTranslation(dx * e, dy * e, 0);
                            m = CATransform3DRotate(m, spin * e, 0, 0, 1);
                            double s = MAX(0.001, 1 - 0.5 * e);
                            return CATransform3DScale(m, s, s, 1); });
                        LFXAnim(t, @"opacity", @1.0, @0.0, hold + delay, 0.5 * dur, easeIn);
                        break;
                    }
                    default: {  // 49 tile flip
                        double d = ((double)c / (cols - 1)) * 0.8 + ((r % 2) ? 0.2 : 0.0);
                        LFXTransformAnim(t, hold + d * 0.6 * dur, 0.4 * dur, YES, ^CATransform3D(double p) {
                            return CATransform3DMakeRotation(p * M_PI_2, 1, 0, 0); });
                        break;
                    }
                }
            }
        }
        free(spiral);
    }

    // ---------- tidy up once the reveal has finished ----------
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((hold + dur + 0.05) * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (gen != sGen) return;
        [UIView animateWithDuration:0.12 animations:^{ cover.alpha = 0; } completion:^(BOOL finished) {
            if (gen != sGen) return;
            LFXCancel();
            if (completion) completion();
        }];
    });
}
