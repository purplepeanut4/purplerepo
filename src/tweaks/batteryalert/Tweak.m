// BatteryAlert - by purplepeanut4
// A notice (and sound) when the battery reaches the level you charge to, or runs low.
#import "PKCommon.h"
#import <AudioToolbox/AudioToolbox.h>

static NSString *const kDomain = @"com.purplesquarecube.batteryalert";
static int sLast = -1;

static void AAlert(NSString *msg, UIColor *ring) {
    PKSync(kDomain);
    if (PKBool(kDomain, @"sound", YES)) {
        int sid = (int)PKInt(kDomain, @"soundID", 1111);
        if (sid > 0) AudioServicesPlaySystemSound((SystemSoundID)sid);
    }
    PKShowPill(msg, ring, 4.0);
}

static void ACheck(void) {
    UIDevice *d = [UIDevice currentDevice];
    if (d.batteryLevel < 0) return;
    int lvl = (int)lroundf(d.batteryLevel * 100);
    BOOL charging = (d.batteryState == UIDeviceBatteryStateCharging || d.batteryState == UIDeviceBatteryStateFull);
    PKSync(kDomain);
    if (PKBool(kDomain, @"enabled", YES) && sLast >= 0 && lvl != sLast) {
        int target = (int)PKInt(kDomain, @"target", 80);
        int low = (int)PKInt(kDomain, @"low", 15);
        if (charging && PKBool(kDomain, @"chargeAlert", YES) && sLast < target && lvl >= target)
            AAlert([NSString stringWithFormat:@"Battery at %d%%. You can unplug now.", lvl],
                   [UIColor colorWithRed:0.20 green:0.80 blue:0.40 alpha:1]);
        if (!charging && PKBool(kDomain, @"lowAlert", YES) && sLast > low && lvl <= low)
            AAlert([NSString stringWithFormat:@"Battery low: %d%% left.", lvl],
                   [UIColor colorWithRed:1.00 green:0.62 blue:0.04 alpha:1]);
    }
    sLast = lvl;
}

__attribute__((constructor))
static void AInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [UIDevice currentDevice].batteryMonitoringEnabled = YES;
            ACheck();
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            [nc addObserverForName:UIDeviceBatteryLevelDidChangeNotification object:nil
                             queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) { ACheck(); }];
            [nc addObserverForName:UIDeviceBatteryStateDidChangeNotification object:nil
                             queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) { ACheck(); }];
        });
    }
}
