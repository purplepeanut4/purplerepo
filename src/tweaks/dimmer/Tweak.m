// Dimmer - by purplepeanut4
// Dims the screen below the normal minimum and adds an optional warm tint, over everything.
#import "PKCommon.h"
#import <QuartzCore/QuartzCore.h>

static NSString *const kDomain = @"com.purplesquarecube.dimmer";
static const char *kNotif = "com.purplesquarecube.dimmer/prefsChanged";

static UIWindow *sWin = nil;
static UIView *sDim = nil, *sWarm = nil;

static BOOL DInSchedule(NSInteger mode, NSInteger start, NSInteger end) {
    if (mode == 0 || start == end) return YES;
    NSDateComponents *dc = [[NSCalendar currentCalendar] components:(NSCalendarUnitHour | NSCalendarUnitMinute)
                                                           fromDate:[NSDate date]];
    double now = dc.hour + dc.minute / 60.0;
    if (start < end) return now >= start && now < end;
    return now >= start || now < end;               // runs overnight, e.g. 21 to 7
}

static void DUpdate(void) {
    PKSync(kDomain);
    BOOL on        = PKBool(kDomain, @"enabled", YES);
    CGFloat dim    = MAX(0, MIN(0.85, PKDouble(kDomain, @"dim", 0.35)));
    CGFloat warm   = MAX(0, MIN(0.5, PKDouble(kDomain, @"warm", 0.15)));
    NSInteger mode = PKInt(kDomain, @"schedule", 0);
    NSInteger from = PKInt(kDomain, @"start", 21);
    NSInteger to   = PKInt(kDomain, @"end", 7);

    BOOL show = on && DInSchedule(mode, from, to) && (dim > 0.005 || warm > 0.005);
    sDim.backgroundColor = [UIColor colorWithWhite:0 alpha:dim];
    sWarm.backgroundColor = [UIColor colorWithRed:1.0 green:0.55 blue:0.16 alpha:warm];

    if (show) {
        sWin.hidden = NO;
        [UIView animateWithDuration:0.35 animations:^{ sWin.alpha = 1; }];
    } else if (!sWin.hidden) {
        [UIView animateWithDuration:0.35 animations:^{ sWin.alpha = 0; }
                         completion:^(BOOL f) { if (sWin.alpha == 0) sWin.hidden = YES; }];
    }
}

static void DCreate(void) {
    if (sWin) return;
    CGRect b = [UIScreen mainScreen].bounds;
    sWin = [[UIWindow alloc] initWithFrame:b];
    sWin.windowLevel = 1000050;
    sWin.userInteractionEnabled = NO;
    sWin.backgroundColor = [UIColor clearColor];
    sWin.alpha = 0;
    sDim = [[UIView alloc] initWithFrame:b];
    sWarm = [[UIView alloc] initWithFrame:b];
    sDim.userInteractionEnabled = NO; sWarm.userInteractionEnabled = NO;
    [sWin addSubview:sWarm];
    [sWin addSubview:sDim];
    sWin.hidden = YES;
    DUpdate();
}

__attribute__((constructor))
static void DInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            DCreate();
            PKOnNotify(kNotif, ^{ DUpdate(); });
            [NSTimer scheduledTimerWithTimeInterval:60 repeats:YES block:^(NSTimer *t) { DUpdate(); }];
        });
    }
}
