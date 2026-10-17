// FineVolume - by purplesquarecube
// Smaller steps for the volume buttons, so you can land on the exact level.
#import "PKCommon.h"

static NSString *const kDomain = @"com.purplesquarecube.finevolume";
static const char *kNotif = "com.purplesquarecube.finevolume/prefsChanged";
static struct { BOOL on; float factor; } V;

static void VLoad(void) {
    PKSync(kDomain);
    V.on = PKBool(kDomain, @"enabled", YES);
    V.factor = (float)MAX(0.1, MIN(1.0, PKDouble(kDomain, @"step", 0.5)));
}

static void (*orig_change)(id, SEL, float);
static void new_change(id self, SEL _cmd, float delta) {
    orig_change(self, _cmd, V.on ? delta * V.factor : delta);
}

__attribute__((constructor))
static void VInit(void) {
    @autoreleasepool {
        if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
        VLoad();
        PKHook("VolumeControl", NSSelectorFromString(@"_changeVolumeBy:"), (IMP)new_change, (IMP *)&orig_change);
        dispatch_async(dispatch_get_main_queue(), ^{ PKOnNotify(kNotif, ^{ VLoad(); }); });
    }
}
