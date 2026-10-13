// PlugIn - by purplesquarecube
// A light sweep around the screen edge and a sound when a charger is connected.
#import "PKCommon.h"
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>

static NSString *const kDomain = @"com.purplesquarecube.plugin";
static const char *kPreview = "com.purplesquarecube.plugin/preview";

static BOOL sWasPlugged = NO, sHaveState = NO;
static UIWindow *sFxWin = nil;

static void PAnimate(BOOL connect, NSInteger style) {
    if (style <= 0) return;
    [sFxWin setHidden:YES];
    CGRect b = [UIScreen mainScreen].bounds;
    sFxWin = [[UIWindow alloc] initWithFrame:b];
    sFxWin.windowLevel = 1000040;
    sFxWin.userInteractionEnabled = NO;
    sFxWin.backgroundColor = [UIColor clearColor];
    UIView *root = [[UIView alloc] initWithFrame:b];
    root.userInteractionEnabled = NO;
    [sFxWin addSubview:root];
    sFxWin.hidden = NO;

    UIColor *col = connect ? [UIColor colorWithRed:0.20 green:0.80 blue:0.40 alpha:1]
                           : [UIColor colorWithRed:1.00 green:0.62 blue:0.04 alpha:1];
    CAShapeLayer *line = [CAShapeLayer layer];
    line.frame = b;
    line.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(b, 2, 2) cornerRadius:14].CGPath;
    line.fillColor = nil;
    line.strokeColor = col.CGColor;
    line.lineWidth = 5;
    line.lineCap = kCALineCapRound;
    line.shadowColor = col.CGColor;
    line.shadowOpacity = 0.95;
    line.shadowRadius = 9;
    line.shadowOffset = CGSizeZero;
    [root.layer addSublayer:line];

    CFTimeInterval dur = 1.0;
    if (style == 1) {                                 // sweep: a bright segment runs around the edge
        line.strokeStart = 0; line.strokeEnd = 0;
        CABasicAnimation *end = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        end.fromValue = @0; end.toValue = @1; end.duration = dur;
        end.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        CABasicAnimation *start = [CABasicAnimation animationWithKeyPath:@"strokeStart"];
        start.fromValue = @0; start.toValue = @1; start.duration = dur; start.beginTime = CACurrentMediaTime() + 0.25;
        start.fillMode = kCAFillModeBackwards;
        start.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        line.strokeEnd = 1; line.strokeStart = 1;
        [line addAnimation:end forKey:@"end"];
        [line addAnimation:start forKey:@"start"];
        dur += 0.4;
    } else {                                          // pulse: whole edge glows once
        line.strokeEnd = 1;
        line.opacity = 0;
        CAKeyframeAnimation *p = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        p.values = @[@0, @1, @0]; p.keyTimes = @[@0, @0.35, @1]; p.duration = 1.1;
        [line addAnimation:p forKey:@"pulse"];
        dur = 1.15;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((dur + 0.1) * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [sFxWin setHidden:YES]; sFxWin = nil; });
}

static void PTrigger(BOOL connect) {
    PKSync(kDomain);
    if (!PKBool(kDomain, @"enabled", YES)) return;
    if (!connect && !PKBool(kDomain, @"unplug", YES)) return;
    if (PKBool(kDomain, @"sound", YES)) {
        int sid = (int)PKInt(kDomain, @"soundID", 1100);
        if (sid > 0) AudioServicesPlaySystemSound((SystemSoundID)sid);
    }
    PAnimate(connect, PKInt(kDomain, @"style", 1));
}

static void PCheck(void) {
    UIDeviceBatteryState st = [UIDevice currentDevice].batteryState;
    if (st == UIDeviceBatteryStateUnknown) return;
    BOOL plugged = (st == UIDeviceBatteryStateCharging || st == UIDeviceBatteryStateFull);
    if (sHaveState && plugged != sWasPlugged) PTrigger(plugged);
    sWasPlugged = plugged;
    sHaveState = YES;
}

__attribute__((constructor))
static void PInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [UIDevice currentDevice].batteryMonitoringEnabled = YES;
            PCheck();
            [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryStateDidChangeNotification
                object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) { PCheck(); }];
            PKOnNotify(kPreview, ^{ PTrigger(YES); });
        });
    }
}
