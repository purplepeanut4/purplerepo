// Breather - by purplepeanut4
// A gentle reminder to take a break after a stretch of screen time.
#import "PKCommon.h"
#import <AudioToolbox/AudioToolbox.h>

static NSString *const kDomain = @"com.purplesquarecube.breather";

static BOOL sLocked = NO;
static double sUsed = 0;              // seconds of continuous use
static NSDate *sLockedAt = nil;
static NSTimer *sTick = nil;
static const double kStep = 15;

static void BTick(void) {
    if (sLocked) return;
    PKSync(kDomain);
    if (!PKBool(kDomain, @"enabled", YES)) { sUsed = 0; return; }
    sUsed += kStep;
    double limit = MAX(5, PKInt(kDomain, @"minutes", 30)) * 60.0;
    if (sUsed >= limit) {
        int mins = (int)lround(sUsed / 60.0);
        sUsed = 0;
        if (PKBool(kDomain, @"sound", YES)) {
            int sid = (int)PKInt(kDomain, @"soundID", 1103);
            if (sid > 0) AudioServicesPlaySystemSound((SystemSoundID)sid);
        }
        PKShowPill([NSString stringWithFormat:@"You've been on your phone for %d minutes. Time for a short break.", mins],
                   [UIColor colorWithRed:0.35 green:0.78 blue:0.98 alpha:1], 6.0);
    }
}

__attribute__((constructor))
static void BInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            int tok;
            notify_register_dispatch("com.apple.springboard.lockstate", &tok, dispatch_get_main_queue(), ^(int t) {
                uint64_t state = 0;
                notify_get_state(t, &state);
                BOOL locked = (state != 0);
                if (locked && !sLocked) sLockedAt = [NSDate date];
                if (!locked && sLocked && sLockedAt && [[NSDate date] timeIntervalSinceDate:sLockedAt] >= 300) sUsed = 0;
                sLocked = locked;
            });
            sTick = [NSTimer scheduledTimerWithTimeInterval:kStep repeats:YES block:^(NSTimer *t) { BTick(); }];
        });
    }
}
