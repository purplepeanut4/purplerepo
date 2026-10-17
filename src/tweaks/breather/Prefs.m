// Breather Settings pane - by purplesquarecube
#import "PKPrefs.h"
#import <AudioToolbox/AudioToolbox.h>

static NSString *const kDomain = @"com.purplesquarecube.breather";

@interface BreatherRootListController : PSListController
@end

@implementation BreatherRootListController
- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    [s addObject:PKGroup(@"Breather", @"Counts the time you spend on your phone and nudges you to take a break. The count starts over after the phone has been locked for 5 minutes.")];
    [s addObject:PKSwitch(self, kDomain, nil, @"Enabled", @"enabled", YES)];
    [s addObject:PKGroup(@"Remind Me After", nil)];
    [s addObject:PKList(self, kDomain, nil, @"Time", @"minutes", @30,
        @[@10, @15, @20, @30, @45, @60, @90],
        @[@"10 minutes", @"15 minutes", @"20 minutes", @"30 minutes", @"45 minutes", @"1 hour", @"1.5 hours"])];
    [s addObject:PKGroup(@"Sound", nil)];
    [s addObject:PKSwitch(self, kDomain, nil, @"Play a Sound", @"sound", YES)];
    [s addObject:PKList(self, kDomain, nil, @"Sound", @"soundID", @1103,
        @[@1103, @1104, @1100, @1111, @1113], @[@"Tink", @"Tock", @"Lock", @"Confirm", @"Begin Recording"])];
    [s addObject:PKButton(self, @"Preview Sound", @selector(preview))];
    _specifiers = s;
    return _specifiers;
}
- (void)preview {
    CFPreferencesAppSynchronize((__bridge CFStringRef)kDomain);
    id v = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("soundID"), (__bridge CFStringRef)kDomain));
    AudioServicesPlaySystemSound(v ? (SystemSoundID)[v intValue] : 1103);
}
@end
