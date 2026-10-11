// BatteryLine - by purplesquarecube
// A thin battery meter along the top or bottom edge of the screen, above every app.
#import "PKCommon.h"
#import <QuartzCore/QuartzCore.h>

static NSString *const kDomain = @"com.purplesquarecube.batteryline";
static const char *kNotif = "com.purplesquarecube.batteryline/prefsChanged";

static UIWindow *sWin = nil;
static UIView *sTrack = nil, *sBar = nil;

static UIColor *BLHex(NSString *hex, UIColor *fallback) {
    if (![hex isKindOfClass:[NSString class]] || hex.length != 6) return fallback;
    unsigned int v = 0;
    [[NSScanner scannerWithString:hex] scanHexInt:&v];
    return [UIColor colorWithRed:((v >> 16) & 0xFF) / 255.0 green:((v >> 8) & 0xFF) / 255.0
                            blue:(v & 0xFF) / 255.0 alpha:1];
}

static void BLUpdate(void) {
    PKSync(kDomain);
    BOOL on        = PKBool(kDomain, @"enabled", YES);
    NSInteger pos  = PKInt(kDomain, @"position", 0);
    CGFloat thick  = MAX(1, MIN(8, PKDouble(kDomain, @"thickness", 3)));
    CGFloat alpha  = MAX(0.2, MIN(1, PKDouble(kDomain, @"opacity", 0.9)));
    BOOL onlyChg   = PKBool(kDomain, @"onlyCharging", NO);
    BOOL pulse     = PKBool(kDomain, @"pulse", YES);
    BOOL showTrack = PKBool(kDomain, @"track", NO);
    NSString *col  = PKPref(kDomain, @"color");
    if (![col isKindOfClass:[NSString class]]) col = @"auto";

    UIDevice *d = [UIDevice currentDevice];
    d.batteryMonitoringEnabled = YES;
    float lvl = d.batteryLevel;                // -1 when unknown
    UIDeviceBatteryState st = d.batteryState;
    BOOL charging = (st == UIDeviceBatteryStateCharging || st == UIDeviceBatteryStateFull);
    if (lvl < 0) lvl = 1;

    if (!on || (onlyChg && !charging)) { sWin.hidden = YES; return; }

    CGRect scr = [UIScreen mainScreen].bounds;
    CGFloat W = scr.size.width, H = scr.size.height;
    sWin.frame = CGRectMake(0, pos == 1 ? H - thick : 0, W, thick);
    sWin.hidden = NO;
    sWin.alpha = alpha;

    UIColor *c;
    if ([col isEqualToString:@"auto"]) {
        if (charging)        c = [UIColor colorWithRed:0.20 green:0.80 blue:0.40 alpha:1];
        else if (lvl <= 0.2) c = [UIColor colorWithRed:0.95 green:0.26 blue:0.21 alpha:1];
        else if (lvl <= 0.5) c = [UIColor colorWithRed:1.00 green:0.70 blue:0.10 alpha:1];
        else                 c = [UIColor colorWithRed:0.20 green:0.80 blue:0.40 alpha:1];
    } else {
        c = BLHex(col, [UIColor colorWithRed:0.49 green:0.23 blue:0.93 alpha:1]);
    }

    sTrack.frame = CGRectMake(0, 0, W, thick);
    sTrack.backgroundColor = [UIColor colorWithWhite:1 alpha:0.18];
    sTrack.hidden = !showTrack;
    sBar.frame = CGRectMake(0, 0, W * lvl, thick);
    sBar.backgroundColor = c;

    [sBar.layer removeAnimationForKey:@"pulse"];
    if (charging && pulse) {
        CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"opacity"];
        a.fromValue = @1.0; a.toValue = @0.45; a.duration = 1.2;
        a.autoreverses = YES; a.repeatCount = HUGE_VALF;
        a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [sBar.layer addAnimation:a forKey:@"pulse"];
    }
}

static void BLCreate(void) {
    if (sWin) return;
    sWin = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 3)];
    sWin.windowLevel = 1000000;
    sWin.userInteractionEnabled = NO;
    sWin.backgroundColor = [UIColor clearColor];
    sTrack = [[UIView alloc] initWithFrame:CGRectZero];
    sBar = [[UIView alloc] initWithFrame:CGRectZero];
    sTrack.userInteractionEnabled = NO; sBar.userInteractionEnabled = NO;
    [sWin addSubview:sTrack];
    [sWin addSubview:sBar];
    sWin.hidden = NO;
    BLUpdate();
}

__attribute__((constructor))
static void BLInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            BLCreate();
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            [nc addObserverForName:UIDeviceBatteryLevelDidChangeNotification object:nil
                             queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) { BLUpdate(); }];
            [nc addObserverForName:UIDeviceBatteryStateDidChangeNotification object:nil
                             queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) { BLUpdate(); }];
            PKOnNotify(kNotif, ^{ BLUpdate(); });
            [NSTimer scheduledTimerWithTimeInterval:60 repeats:YES block:^(NSTimer *t) { BLUpdate(); }];
        });
    }
}
