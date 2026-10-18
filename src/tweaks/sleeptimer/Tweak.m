// SleepTimer - by purplepeanut4
// Pauses music or video after a set time, and can lock the device.
#import "PKCommon.h"

// MediaRemote (private): 0 play, 1 pause, 2 toggle, 3 stop
extern Boolean MRMediaRemoteSendCommand(int command, NSDictionary *userInfo);

static NSString *const kDomain = @"com.purplesquarecube.sleeptimer";
static const char *kStart = "com.purplesquarecube.sleeptimer/start";
static const char *kCancel = "com.purplesquarecube.sleeptimer/cancel";

static NSTimer *sTick = nil;

static void SSetEnd(NSNumber *t) {
    CFPreferencesSetAppValue(CFSTR("endsAt"), (__bridge CFPropertyListRef)t, (__bridge CFStringRef)kDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
}

static void SLock(void) {
    UIApplication *app = [UIApplication sharedApplication];
    SEL sel = NSSelectorFromString(@"_simulateLockButtonPress");
    if ([app respondsToSelector:sel]) ((void (*)(id, SEL))objc_msgSend)(app, sel);
}

static void SStop(void) {
    [sTick invalidate];
    sTick = nil;
    SSetEnd(nil);
}

static void SFire(void) {
    BOOL lock = PKBool(kDomain, @"lock", YES);
    SStop();
    MRMediaRemoteSendCommand(1, nil);                // pause whatever is playing
    if (lock) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
                             dispatch_get_main_queue(), ^{ SLock(); });
}

static void SCheck(void) {
    PKSync(kDomain);
    id end = PKPref(kDomain, @"endsAt");
    if (!end) { SStop(); return; }
    if ([[NSDate date] timeIntervalSince1970] >= [end doubleValue]) SFire();
}

static void SStart(void) {
    PKSync(kDomain);
    NSInteger minutes = MAX(1, PKInt(kDomain, @"minutes", 30));
    SStop();
    SSetEnd(@([[NSDate date] timeIntervalSince1970] + minutes * 60.0));
    // checking every few seconds (not one long timer) keeps it right even if the phone dozes in between
    sTick = [NSTimer scheduledTimerWithTimeInterval:5 repeats:YES block:^(NSTimer *t) { SCheck(); }];
}

__attribute__((constructor))
static void SInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            SSetEnd(nil);                            // a respring ends any running timer
            PKOnNotify(kStart, ^{ SStart(); });
            PKOnNotify(kCancel, ^{ SStop(); });
        });
    }
}
