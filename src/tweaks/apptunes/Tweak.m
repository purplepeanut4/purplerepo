// AppTunes - by purplesquarecube
// Plays a song of your choice while a chosen app is in the foreground.
// Runs inside SpringBoard so it is not limited by app sandboxes.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <notify.h>

static NSString *const kDomain    = @"com.purplesquarecube.apptunes";
static NSString *const kSongsDir  = @"/var/mobile/Library/AppTunes";
static const char *kPrefsNotif    = "com.purplesquarecube.apptunes/prefsChanged";

static AVAudioPlayer *gPlayer      = nil;
static NSString      *gPlayingKey  = nil;   // "bundle|file"
static BOOL           gFinished    = NO;    // non-looping song already played through
static BOOL           gLocked      = NO;
static NSString      *gHintBundle  = nil;   // fallback if the system call below is missing

#pragma mark - Preferences

static id ATPref(NSString *key) {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                       (__bridge CFStringRef)kDomain));
}
static BOOL ATBool(NSString *key, BOOL def) {
    id v = ATPref(key);
    return v ? [v boolValue] : def;
}
static float ATFloat(NSString *key, float def) {
    id v = ATPref(key);
    return v ? [v floatValue] : def;
}

#pragma mark - Player

@interface ATDelegate : NSObject <AVAudioPlayerDelegate>
@end
@implementation ATDelegate
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)p successfully:(BOOL)flag {
    gFinished = YES;
}
@end
static ATDelegate *gDelegate = nil;

static void ATStop(void) {
    if (gPlayer) { [gPlayer stop]; gPlayer = nil; }
    gPlayingKey = nil;
    gFinished = NO;
}

static NSString *ATFrontBundle(void) {
    UIApplication *ui = [UIApplication sharedApplication];
    SEL sel = NSSelectorFromString(@"_accessibilityFrontMostApplication");
    if (ui && [ui respondsToSelector:sel]) {
        id app = ((id (*)(id, SEL))objc_msgSend)(ui, sel);
        if (app && [app respondsToSelector:@selector(bundleIdentifier)]) {
            return ((id (*)(id, SEL))objc_msgSend)(app, @selector(bundleIdentifier));
        }
        return nil;   // home screen
    }
    return gHintBundle;
}

static void ATRefresh(void) {
    if (!ATBool(@"enabled", YES) || gLocked) { ATStop(); return; }

    NSString *bid = ATFrontBundle();
    if (!bid.length) { ATStop(); return; }

    NSString *song = ATPref([@"app." stringByAppendingString:bid]);
    if (![song isKindOfClass:[NSString class]] || !song.length) { ATStop(); return; }

    // keep the path safe
    song = [song lastPathComponent];
    NSString *path = [kSongsDir stringByAppendingPathComponent:song];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) { ATStop(); return; }

    BOOL loop = ATBool(@"loop", YES);
    float vol = ATFloat(@"volume", 0.8f);
    NSString *key = [NSString stringWithFormat:@"%@|%@", bid, song];

    if (gPlayer && [key isEqualToString:gPlayingKey]) {
        // same app + song: apply live settings, don't restart
        gPlayer.volume = vol;
        gPlayer.numberOfLoops = loop ? -1 : 0;
        if (loop && !gPlayer.isPlaying) { gFinished = NO; [gPlayer play]; }
        return;
    }
    if (!gPlayer && gFinished && [key isEqualToString:gPlayingKey]) return;

    ATStop();

    NSError *err = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionMixWithOthers
                   error:&err];
    [session setActive:YES error:&err];

    gPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&err];
    if (!gPlayer) { NSLog(@"[AppTunes] could not open %@: %@", path, err); return; }
    if (!gDelegate) gDelegate = [ATDelegate new];
    gPlayer.delegate = gDelegate;
    gPlayer.volume = vol;
    gPlayer.numberOfLoops = loop ? -1 : 0;
    [gPlayer prepareToPlay];
    [gPlayer play];
    gPlayingKey = key;
    gFinished = NO;
}

#pragma mark - Hook (SpringBoard front app changed)

static void (*orig_frontDisplayDidChange)(id, SEL, id);
static void new_frontDisplayDidChange(id self, SEL _cmd, id display) {
    orig_frontDisplayDidChange(self, _cmd, display);
    NSString *bid = nil;
    Class sbApp = NSClassFromString(@"SBApplication");
    if (display && sbApp && [display isKindOfClass:sbApp] &&
        [display respondsToSelector:@selector(bundleIdentifier)]) {
        bid = ((id (*)(id, SEL))objc_msgSend)(display, @selector(bundleIdentifier));
    }
    gHintBundle = bid;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ ATRefresh(); });
}

#pragma mark - Setup

__attribute__((constructor))
static void ATInit(void) {
    @autoreleasepool {
        NSString *me = [[NSBundle mainBundle] bundleIdentifier];
        if (![me isEqualToString:@"com.apple.springboard"]) return;

        Class sb = NSClassFromString(@"SpringBoard");
        SEL sel = NSSelectorFromString(@"frontDisplayDidChange:");
        Method m = sb ? class_getInstanceMethod(sb, sel) : NULL;
        if (m) {
            orig_frontDisplayDidChange = (void (*)(id, SEL, id))method_getImplementation(m);
            method_setImplementation(m, (IMP)new_frontDisplayDidChange);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            // settings changed in the Settings app
            int t1;
            notify_register_dispatch(kPrefsNotif, &t1, dispatch_get_main_queue(), ^(int tok) {
                ATRefresh();
            });

            // lock / unlock
            int t2;
            notify_register_dispatch("com.apple.springboard.lockstate", &t2,
                                     dispatch_get_main_queue(), ^(int tok) {
                uint64_t state = 0;
                notify_get_state(tok, &state);
                gLocked = (state != 0);
                ATRefresh();
            });

            // safety net in case the hook above doesn't fire on some builds
            [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *t) {
                if (ATBool(@"enabled", YES) || gPlayer) ATRefresh();
            }];
        });
    }
}
