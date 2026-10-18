// WakeUp - by purplepeanut4
// Lights up the screen when you connect (or disconnect) a charger.
#import "PKCommon.h"

static NSString *const kDomain = @"com.purplesquarecube.wakeup";
static BOOL sPlugged = NO, sHave = NO;

static void WWake(void) {
    Class bc = NSClassFromString(@"SBBacklightController");
    id inst = bc ? ((id (*)(id, SEL))objc_msgSend)(bc, NSSelectorFromString(@"sharedInstance")) : nil;
    SEL sel = NSSelectorFromString(@"turnOnScreenFullyWithBacklightSource:");
    if (inst && [inst respondsToSelector:sel]) ((void (*)(id, SEL, long long))objc_msgSend)(inst, sel, 1);
}

static void WCheck(void) {
    UIDeviceBatteryState st = [UIDevice currentDevice].batteryState;
    if (st == UIDeviceBatteryStateUnknown) return;
    BOOL plugged = (st == UIDeviceBatteryStateCharging || st == UIDeviceBatteryStateFull);
    if (sHave && plugged != sPlugged) {
        PKSync(kDomain);
        if (PKBool(kDomain, @"enabled", YES)) {
            if (plugged && PKBool(kDomain, @"plug", YES)) WWake();
            if (!plugged && PKBool(kDomain, @"unplug", NO)) WWake();
        }
    }
    sPlugged = plugged;
    sHave = YES;
}

__attribute__((constructor))
static void WInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [UIDevice currentDevice].batteryMonitoringEnabled = YES;
            WCheck();
            [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryStateDidChangeNotification
                object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) { WCheck(); }];
        });
    }
}
