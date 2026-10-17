// BatteryAlert Settings pane - by purplesquarecube
#import "PKPrefs.h"
#import <AudioToolbox/AudioToolbox.h>

static NSString *const kDomain = @"com.purplesquarecube.batteryalert";

@interface BatteryAlertRootListController : PSListController
@end

@implementation BatteryAlertRootListController
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    [s addObject:PKGroup(@"BatteryAlert", @"Get told when your battery hits the level you care about.")];
    [s addObject:PKSwitch(self, kDomain, nil, @"Enabled", @"enabled", YES)];

    [s addObject:PKGroup(@"While Charging", @"Many people stop at 80% to keep the battery healthy.")];
    [s addObject:PKSwitch(self, kDomain, nil, @"Alert at Charge Level", @"chargeAlert", YES)];
    [s addObject:PKList(self, kDomain, nil, @"Charge Level", @"target", @80,
        @[@50, @60, @70, @80, @85, @90, @95, @100],
        @[@"50%", @"60%", @"70%", @"80%", @"85%", @"90%", @"95%", @"100%"])];

    [s addObject:PKGroup(@"On Battery", nil)];
    [s addObject:PKSwitch(self, kDomain, nil, @"Alert When Low", @"lowAlert", YES)];
    [s addObject:PKList(self, kDomain, nil, @"Low Level", @"low", @15,
        @[@5, @10, @15, @20, @25, @30], @[@"5%", @"10%", @"15%", @"20%", @"25%", @"30%"])];

    [s addObject:PKGroup(@"Sound", @"System sounds follow your ringer switch.")];
    [s addObject:PKSwitch(self, kDomain, nil, @"Play a Sound", @"sound", YES)];
    [s addObject:PKList(self, kDomain, nil, @"Sound", @"soundID", @1111,
        @[@1111, @1103, @1104, @1100, @1108, @1113],
        @[@"Confirm", @"Tink", @"Tock", @"Lock", @"Camera Shutter", @"Begin Recording"])];
    [s addObject:PKButton(self, @"Preview Sound", @selector(preview))];
    _specifiers = s;
    return _specifiers;
}
- (void)preview {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
    id v = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("soundID"), (__bridge CFStringRef)kDomain));
    AudioServicesPlaySystemSound(v ? (SystemSoundID)[v intValue] : 1111);
}
@end
