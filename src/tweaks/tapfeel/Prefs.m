// TapFeel Settings pane - by purplepeanut4
#import "PKPrefs.h"
#import <AudioToolbox/AudioToolbox.h>

static NSString *const kDomain = @"com.purplesquarecube.tapfeel";
static NSString *const kNotif  = @"com.purplesquarecube.tapfeel/prefsChanged";

@interface TapFeelRootListController : PSListController
@end

@implementation TapFeelRootListController
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    [s addObject:PKGroup(@"TapFeel", @"Plays when you tap an app icon on the Home Screen or Dock.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Enabled", @"enabled", YES)];

    [s addObject:PKGroup(@"Sound", @"System sounds follow your ringer switch, so they stay quiet in silent mode.")];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Play a Sound", @"sound", YES)];
    [s addObject:PKList(self, kDomain, kNotif, @"Sound", @"soundID", @1104,
        @[@1104, @1103, @1100, @1108, @1111, @1113],
        @[@"Tock", @"Tink", @"Lock", @"Camera Shutter", @"Confirm", @"Begin Recording"])];
    [s addObject:PKButton(self, @"Preview Sound", @selector(previewSound))];

    [s addObject:PKGroup(@"Bounce", nil)];
    [s addObject:PKSwitch(self, kDomain, kNotif, @"Bounce the Icon", @"bounce", YES)];
    [s addObject:PKSlider(self, kDomain, kNotif, @"Bounce Strength", @"strength", 0.18, 0.05, 0.4)];
    _specifiers = s;
    return _specifiers;
}

- (void)previewSound {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
    id v = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("soundID"), (__bridge CFStringRef)kDomain));
    AudioServicesPlaySystemSound(v ? (SystemSoundID)[v intValue] : 1104);
}
@end
